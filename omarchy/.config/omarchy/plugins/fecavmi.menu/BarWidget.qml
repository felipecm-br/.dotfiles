import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "fecavmi.menu"

  // Bar icons are normalized to Style.bar.iconSize (12px); the Omarchy logo
  // is drawn here at a larger painted size instead.
  readonly property real logoSize: 58

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    fontFamily: "omarchy"
    labelVisible: false
    fixedWidth: button.vertical ? -1 : root.logoSize + 24
    fixedHeight: button.vertical ? root.logoSize + 24 : -1
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
    }

    OpticalGlyph {
      anchors.centerIn: parent
      width: root.logoSize
      height: root.logoSize
      text: button.text
      fontFamily: button.fontFamily
      fontSize: 16
      paintedSize: root.logoSize
      color: button.foreground
      scale: button.pressScale
    }
  }
}
