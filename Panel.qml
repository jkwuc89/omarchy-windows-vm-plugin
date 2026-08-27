import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "jkwuc89.windows-vm"
  ipcTarget: "jkwuc89.windows-vm"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string stateLabel: Model.stateLabel(winvm.vmState)
  readonly property string detailText: winvm.actionStatus !== "" ? winvm.actionStatus
    : (winvm.lastError !== "" ? winvm.lastError : "")
  readonly property color iconColor: winvm.active ? foreground : dim
  readonly property color barIconColor: winvm.active ? barForeground : Qt.darker(barForeground, 1.55)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) winvm.refresh()

  Service {
    id: winvm
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function add(): string { winvm.add(); return "ok" }
    function start(): string { winvm.start(); return "ok" }
    function stop(): string { winvm.stop(); return "ok" }
    function remove(): string { winvm.remove(); return "ok" }
    function status(): string { return root.stateLabel }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    tooltipText: "Windows VM: " + root.stateLabel
    foreground: root.barIconColor
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) winvm.toggleRunning()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onActivateRequested: winvm.toggleRunning()

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        PanelHero {
          id: hero
          width: parent.width
          title: "Windows VM"
          meta: root.stateLabel
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: winvm.active ? 1.0 : 0.55
          iconComponent: Component {
            Text {
              text: ""
              color: root.iconColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }

          trailingControl: Component {
            Button {
              visible: winvm.vmState !== "not-configured" && winvm.vmState !== "starting" && winvm.vmState !== "stopping"
              text: winvm.active ? "Stop" : "Start"
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !winvm.busy && (winvm.active ? !winvm.stopDisabled : !winvm.startDisabled)
              onClicked: winvm.toggleRunning()
            }
          }
        }

        Column {
          visible: winvm.windowsDirExists
          width: parent.width
          spacing: Style.space(2)

          Row {
            width: parent.width
            Text {
              text: "CPU Cores"
              color: root.dim
              font.family: "monospace"
              font.pixelSize: Style.font.bodySmall
              width: Style.space(100)
            }
            Text {
              text: winvm.cpuCores
              color: root.foreground
              font.family: "monospace"
              font.pixelSize: Style.font.bodySmall
            }
          }

          Row {
            width: parent.width
            Text {
              text: "Memory"
              color: root.dim
              font.family: "monospace"
              font.pixelSize: Style.font.bodySmall
              width: Style.space(100)
            }
            Text {
              text: winvm.ramSize
              color: root.foreground
              font.family: "monospace"
              font.pixelSize: Style.font.bodySmall
            }
          }

          Row {
            width: parent.width
            Text {
              text: "Disk Size"
              color: root.dim
              font.family: "monospace"
              font.pixelSize: Style.font.bodySmall
              width: Style.space(100)
            }
            Text {
              text: winvm.diskSize
              color: root.foreground
              font.family: "monospace"
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

      }
    }
  }
}
