import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

// All process/polling logic for the Windows VM widget, kept out of Panel.qml
// so the UI tree only ever reads reactive properties — same split the
// built-in Dropbox panel uses (see
// /usr/share/omarchy/shell/plugins/panels/dropbox/Service.qml).
//
// This never touches Docker or the VM's compose file directly for writes —
// only a read-only `docker inspect` (status) and the already-hardened,
// packaged `omarchy-windows-vm` command (start/stop). All of the privilege
// escalation (sudoless Docker vs. pkexec) already lives in that command;
// duplicating it here would just be a second copy to keep in sync and secure.
Item {
  id: root

  readonly property string container: "omarchy-windows"
  readonly property string composeFile: "/var/lib/omarchy/windows/docker-compose.yml"
  readonly property string windowsDir: "/var/lib/omarchy/windows"

  property string containerStatus: ""
  property bool windowsDirExists: false
  property bool refreshing: false
  property string lastError: ""
  property string actionStatus: ""
  property string cpuCores: "—"
  property string ramSize: "—"
  property string diskSize: "—"

  // Optimistic desired state so the icon/button react the instant you click,
  // rather than waiting out the ~8s poll interval. -1 means "just follow the
  // real state"; 1/0 mean "starting"/"stopping" until docker inspect agrees.
  property int _desired: -1
  property bool _windowsDirWasNotConfigured: true
  readonly property bool running: containerStatus === "running"
  readonly property bool active: _desired === -1 ? running : (_desired === 1)

  readonly property string vmState: {
    if (_desired === 1 && !running) return "starting"
    if (_desired === 0 && running) return "stopping"
    return Model.classifyState(containerStatus, windowsDirExists)
  }

  readonly property bool busy: statusProcess.running || windowsDirProcess.running || stopProcess.running || removeProcess.running
  // Only the "starting" transient blocks Start — the launch command itself
  // (below) can legitimately keep running for an entire RDP session, and
  // must not permanently disable the button once the VM is actually up.
  readonly property bool startDisabled: busy || vmState === "starting" || vmState === "stopping" || vmState === "running"
  readonly property bool stopDisabled: busy || vmState !== "running"

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
    if (!windowsDirProcess.running) windowsDirProcess.running = true
    if (!configProcess.running) configProcess.running = true
  }

  function add() {
    // The install wizard is interactive (uses gum for prompts) and must be run
    // from a terminal by the user. We just show the instruction; the user runs
    // the command manually, and our polling will detect when the install completes
    // (when /var/lib/omarchy/windows is created) and automatically start the VM.
  }

  function start() {
    if (startDisabled) return
    _desired = 1
    actionStatus = "Starting Windows VM…"
    // Launch start command in background without waiting for it to exit
    Quickshell.execDetached(["omarchy-windows-vm", "start"])
    settleTimer.restart()
  }

  function stop() {
    if (stopDisabled) return
    _desired = 0
    actionStatus = "Stopping Windows VM…"
    stopProcess.command = ["omarchy-windows-vm", "stop"]
    stopProcess.running = true
    settleTimer.restart()
  }

  function remove() {
    if (busy) return
    actionStatus = "Removing Windows VM…"
    removeProcess.command = ["omarchy-windows-vm", "remove", "--yes"]
    removeProcess.running = true
  }

  function primaryAction() {
    if (vmState === "not-configured") add()
    else if (active) stop()
    else start()
  }

  function toggleRunning() {
    primaryAction()
  }

  Connections {
    target: root
    function onWindowsDirExistsChanged() {
      // When the install wizard completes, /var/lib/omarchy/windows is created.
      // Detect this transition and automatically start the VM + open RDP.
      if (!root._windowsDirWasNotConfigured) return
      if (!root.windowsDirExists) return
      // Windows directory was just created — install completed!
      root._windowsDirWasNotConfigured = false
      Qt.callLater(function() { root.start() })
    }
  }

  Timer {
    id: refreshTimer
    interval: 8000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // The container can take a few seconds to flip state after start/stop; poll
  // faster for a bit right after an action so the icon doesn't lag the ~8s
  // periodic refresh. Stops early once reality catches up to _desired.
  Timer {
    id: settleTimer
    property int ticks: 0
    interval: 1500
    repeat: true
    running: false
    onTriggered: {
      settleTimer.ticks += 1
      root.refresh()
      var settled = root._desired === -1 || root.running === (root._desired === 1)
      if (settled || settleTimer.ticks >= 8) {
        settleTimer.ticks = 0
        settleTimer.running = false
        if (settled) {
          root._desired = -1
          root.actionStatus = ""
        }
      }
    }
  }

  Process {
    id: statusProcess
    running: false
    command: ["docker", "inspect", "--format", "{{.State.Status}}", root.container]
    stdout: StdioCollector { id: statusStdout; waitForEnd: true }
    stderr: StdioCollector { id: statusStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.containerStatus = String(statusStdout.text || "").trim()
        root.lastError = ""
      } else {
        // "no such object" is the container simply not having been created
        // yet, not an error worth surfacing. Docker's own casing of this
        // message has changed across versions ("Error: No such object: …"
        // vs. "error: no such object: …"), so match case-insensitively.
        root.containerStatus = ""
        var err = String(statusStderr.text || "")
        if (err !== "" && err.toLowerCase().indexOf("no such object") === -1) {
          root.lastError = "Could not read Windows VM status"
        }
      }
    }
  }

  Process {
    id: windowsDirProcess
    running: false
    command: ["test", "-d", root.windowsDir]
    onExited: function(exitCode) { root.windowsDirExists = exitCode === 0 }
  }

  Process {
    id: configProcess
    running: false
    command: ["grep", "-E", "RAM_SIZE|CPU_CORES|DISK_SIZE", "/var/lib/omarchy/windows/docker-compose.yml"]
    stdout: StdioCollector { id: configStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        var text = String(configStdout.text || "")
        var lines = text.trim().split('\n')
        root.cpuCores = "—"
        root.ramSize = "—"
        root.diskSize = "—"
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i]
          if (line.indexOf("CPU_CORES") !== -1) {
            var match = line.match(/"(\d+)"/)
            if (match) root.cpuCores = match[1]
          } else if (line.indexOf("RAM_SIZE") !== -1) {
            var match = line.match(/"([^"]+)"/)
            if (match) {
              var val = match[1]
              // Extract number and format as "# GB"
              var numMatch = val.match(/^(\d+)/)
              if (numMatch) root.ramSize = numMatch[1] + " GB"
              else root.ramSize = val
            }
          } else if (line.indexOf("DISK_SIZE") !== -1) {
            var match = line.match(/"([^"]+)"/)
            if (match) {
              var val = match[1]
              // Extract number and format as "# GB"
              var numMatch = val.match(/^(\d+)/)
              if (numMatch) root.diskSize = numMatch[1] + " GB"
              else root.diskSize = val
            }
          }
        }
      }
    }
  }

  Process {
    id: startProcess
    running: false
    command: []
    stdout: StdioCollector { id: startStdout; waitForEnd: true }
    stderr: StdioCollector { id: startStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = "Failed to start the Windows VM"
        root.actionStatus = root.lastError
        root._desired = -1
      }
      root.refresh()
    }
  }

  Process {
    id: stopProcess
    running: false
    command: []
    stderr: StdioCollector { id: stopStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = "Failed to stop the Windows VM"
        root.actionStatus = root.lastError
        root._desired = -1
      }
      root.refresh()
    }
  }

  Process {
    id: removeProcess
    running: false
    command: []
    stderr: StdioCollector { id: removeStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.actionStatus = ""
        root.lastError = ""
      } else {
        root.lastError = "Failed to remove the Windows VM"
        root.actionStatus = root.lastError
      }
      root.refresh()
    }
  }
}
