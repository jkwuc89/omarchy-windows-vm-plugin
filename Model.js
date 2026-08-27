// Pure helpers for the Windows VM widget, kept out of the QML tree so the
// state-classification logic can be read (and eyeballed for correctness)
// independent of bindings, same convention as the built-in panels'
// Model.js files (see /usr/share/omarchy/shell/plugins/panels/power/Model.js).

// containerStatus is the raw `docker inspect --format={{.State.Status}}`
// result: "" (container never created / docker unreachable), "running",
// "exited", "created", "paused", "restarting", "removing", "dead".
// composeExists tells us whether `omarchy-windows-vm install` has ever run.
function classifyState(containerStatus, composeExists) {
  if (!composeExists) return "not-configured"
  if (containerStatus === "running") return "running"
  return "stopped"
}

function stateLabel(state) {
  if (state === "running") return "Running"
  if (state === "starting") return "Starting"
  if (state === "stopping") return "Stopping"
  if (state === "not-configured") return "Not set up"
  return "Stopped"
}

// Text shown in the popup's detail line under the hero row.
function detailText(state) {
  if (state === "running") return "Web console: 127.0.0.1:8006 · RDP: 127.0.0.1:3389"
  if (state === "not-configured") return "Open a terminal and run: omarchy-windows-vm install"
  return "Not running"
}

if (typeof module !== "undefined") {
  module.exports = {
    classifyState: classifyState,
    stateLabel: stateLabel,
    detailText: detailText
  }
}
