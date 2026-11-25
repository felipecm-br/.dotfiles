import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "fecavmi.workspaces"

  // Every monitor has workspaces 1-10 of its own, which Hyprland numbers in a
  // block of ten per monitor: 1-10, 11-20, and so on (see
  // default/hypr/monitor-workspaces.lua). Each bar shows workspace 0 ("zero"),
  // its own monitor's block (labeled 1-10), and any visiting guest workspaces.
  readonly property int slots: 10

  readonly property var monitor: {
    var window = root.QsWindow.window
    var screen = window ? window.screen : null
    return screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  }
  readonly property string monitorName: root.monitor ? root.monitor.name : ""

  // Connector -> block, from the file Hyprland keeps them in.
  property var blocks: ({})

  function readBlocks(text) {
    var next = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var fields = lines[i].split("\t")
      if (fields.length >= 3 && fields[1] !== "") {
        var parsed = parseInt(fields[0], 10)
        if (!isNaN(parsed)) next[fields[1]] = parsed
      }
    }
    root.blocks = next
  }

  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitors/workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readBlocks(text())
    onLoadFailed: root.readBlocks("")
  }

  function blockOf(id) {
    return Math.floor((id - 1) / root.slots)
  }

  function slotOf(id) {
    return (id - 1) % root.slots + 1
  }

  function isZeroWorkspace(w) {
    return w !== null && (w.name === "zero" || w.name === "0")
  }

  function isGuest(id) {
    return id > 0 && root.blockOf(id) !== root.block
  }

  function displayLabel(id) {
    if (id === 0) return "0"
    return String(root.slotOf(id))
  }

  function activeWorkspaceId() {
    return root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1
  }

  // Until Hyprland has written the file, infer the block from the active or
  // existing numeric workspaces on this monitor.
  readonly property int block: {
    var assigned = root.blocks[root.monitorName]
    if (assigned !== undefined) return assigned
    var active = root.activeWorkspaceId()
    if (active > 0) return root.blockOf(active)
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var w = values[i]
      if (w && w.id > 0 && w.monitor && w.monitor.name === root.monitorName) {
        return root.blockOf(w.id)
      }
    }
    return 0
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var w = values[i]
      if (!w) continue
      if (id === 0) {
        if (root.isZeroWorkspace(w)) return w
      } else if (w.id === id) {
        return w
      }
    }

    return null
  }

  // Workspace 0 ("zero"), the first five of the monitor's own block, and any
  // of the rest of the block (6-10) that exist. After them come visiting guest
  // workspaces from an unplugged monitor that had no room to merge.
  function workspaceIds() {
    var base = root.block * root.slots
    var ids = [0, base + 1, base + 2, base + 3, base + 4, base + 5]
    var guests = []
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var w = values[i]
      if (!w || root.isZeroWorkspace(w)) continue
      if (w.name && String(w.name).indexOf("special:") === 0) continue
      var id = w.id
      if (id <= 0) continue
      if (root.blockOf(id) === root.block) {
        if (ids.indexOf(id) === -1) ids.push(id)
      } else if (w.monitor && w.monitor.name === root.monitorName) {
        if (guests.indexOf(id) === -1) guests.push(id)
      }
    }

    ids.sort(function(left, right) { return left - right })
    guests.sort(function(left, right) { return left - right })
    return ids.concat(guests)
  }

  readonly property var visibleWorkspaceIds: root.workspaceIds()

  function dispatch(expression) {
    if (root.bar) root.bar.run("hyprctl dispatch " + Util.shellQuote(expression))
  }

  function focusWorkspace(id) {
    if (id === 0) {
      root.dispatch("hl.dsp.focus({ workspace = \"name:zero\" })")
    } else if (root.blockOf(id) === root.block) {
      if (root.monitorName) {
        root.dispatch("o.workspaces.focus(" + root.slotOf(id) + ", \"" + root.monitorName + "\")")
      } else {
        root.dispatch("o.workspaces.focus(" + root.slotOf(id) + ")")
      }
    } else {
      root.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      // Quickshell credits every workspace switch to the focused monitor, as
      // the event doesn't say which one switched, and misses the workspace a
      // monitor falls back to when its own is moved away. Moving workspaces
      // between monitors switches the others, so ask Hyprland for the truth.
      // A workspace that changes number is only learned by asking too. Every
      // bar shares what Hyprland answers, so one asks after a plain switch.
      var switched = name === "workspacev2" && root.monitor !== null && root.monitor.focused
      if (switched || name === "moveworkspacev2" || name === "changeworkspaceid") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
        if (name === "moveworkspacev2" || name === "changeworkspaceid") {
          Hyprland.refreshToplevels()
        }
      }
    }
  }

  readonly property var defaultNerdFontGlyphs: ({
    "com.mitchellh.ghostty": "",
    "ghostty": "",
    "kitty": "",
    "foot": "",
    "alacritty": "",
    "agent": "󱚤",
    "google-chrome": "",
    "chrome": "",
    "firefox": "",
    "zen": "",
    "zen-browser": "",
    "antigravity-ide": "󰲇",
    "antigravity": "󰲇",
    "vscode": "",
    "code": "",
    "nvim": "",
    "obsidian": "󰈙",
    "discord": "",
    "vesktop": "",
    "signal": "󰭹",
    "signal-desktop": "󰭹",
    "telegram": "",
    "thunderbird": "",
    "spotify": "",
    "steam": "",
    "vlc": "󰕼",
    "mpv": "",
    "system-file-manager": "",
    "nautilus": "",
    "thunar": "",
    "yazi": "",
    "youtube": "󰗃",
    "google-photos": "󰋩",
    "github": "󰊤",
    "whatsapp": "󰖣",
    "chatgpt": "󰚩",
    "grok": "󰚩",
    "google messages": "󰭹",
    "linkedin": "󰌻",
    "bitwarden": "󰯄"
  })

  function getGlyphOrFallback(data) {
    if (!data) return ""
    var s = String(data)
    if (s.indexOf("app:") === 0) {
      var appName = s.substring(4).toLowerCase()
      if (root.defaultNerdFontGlyphs[appName]) return root.defaultNerdFontGlyphs[appName]
      return ""
    }
    if (s.indexOf("svg:") === 0 || s.indexOf("/") === 0) return ""
    return s
  }

  function getIconSpec(val) {
    if (!val) return { icon: "", brightness: 0.0, contrast: 0.6 }
    if (typeof val === "object" && val.icon) {
      return {
        icon: val.icon,
        brightness: (typeof val.brightness === "number") ? val.brightness : 0.0,
        contrast: (typeof val.contrast === "number") ? val.contrast : 0.6
      }
    }
    return { icon: String(val), brightness: 0.0, contrast: 0.6 }
  }

  function resolveIconSource(icon) {
    if (!icon) return ""
    var s = String(icon)
    if (s.indexOf("app:") === 0) {
      var appName = s.substring(4)

      // Direct Papirus SVG mapping exclusively for dedicated vector apps
      if (appName === "ghostty" || appName === "com.mitchellh.ghostty") {
        return "/usr/share/icons/Papirus/32x32/apps/com.mitchellh.ghostty.svg"
      }
      if (appName === "kitty") {
        return "/usr/share/icons/Papirus/32x32/apps/kitty.svg"
      }
      if (appName === "antigravity" || appName === "antigravity-ide") {
        return "/usr/share/icons/Papirus/32x32/apps/antigravity.svg"
      }
      if (appName === "bitwarden" || appName === "com.bitwarden.desktop") {
        return "/usr/share/icons/Papirus/32x32/apps/com.bitwarden.desktop.svg"
      }

      return ""
    }
    if (s.indexOf("svg:") === 0) {
      return s.substring(4)
    }
    if (s.indexOf("/") === 0 || s.indexOf("file://") === 0) {
      return s
    }
    return ""
  }

  readonly property var titleRules: [
    { patterns: ["youtube"],                                 icon: "󰗃" },
    { patterns: ["google photos"],                          icon: "󰋩" },
    { patterns: [
        "github", "github.io", "github.com",
        "/ repositories", "/ stars", "/ followers", "/ following", "/ projects", "/ packages",
        "pull request", "pull requests", "issues ·", "issue #", "commits ·", "commit ·",
        "releases ·", "release ·", "actions ·"
      ],                                                     icon: "󰊤" },
    { patterns: ["linkedin"],                               icon: "󰌻" },
    { patterns: ["chatgpt", "grok"],                        icon: "󰚩" },
    { patterns: ["whatsapp"],                               icon: "󰖣" },
    { patterns: ["google messages"],                        icon: "󰭹" },
    { patterns: ["is sharing your screen"],                 icon: "󰹑" }
  ]

  readonly property var classRules: [
    // Terminals (Theme-Aware SVGs for Ghostty and Kitty)
    { patterns: ["ghostty"],                                icon: "app:com.mitchellh.ghostty" },
    { patterns: ["kitty"],                                  icon: "app:kitty", brightness: 0.80, contrast: 1.0 },
    { patterns: ["foot", "alacritty"],                      icon: "" },
    { patterns: ["agent"],                                  icon: "󱚤" },

    // Browsers (Nerd Font Glyphs)
    { patterns: ["google-chrome", "chrome", "chromium", "brave"], icon: "" },
    { patterns: ["firefox", "librewolf", "zen"],            icon: "" },

    // Editors & IDEs (Antigravity with custom brightness & contrast)
    { patterns: ["antigravity"],                            icon: "app:antigravity", brightness: 0.80, contrast: 1.0 },
    { patterns: ["code", "vscode"],                         icon: "" },
    { patterns: ["nvim", "neovim"],                         icon: "" },
    { patterns: ["typora", "obsidian", "writer"],           icon: "󰈙" },

    // Communication
    { patterns: ["vesktop", "discord"],                     icon: "" },
    { patterns: ["signal"],                                 icon: "󰭹" },
    { patterns: ["telegram"],                               icon: "" },
    { patterns: ["thunderbird"],                            icon: "" },

    // Media
    { patterns: ["spotify"],                                icon: "" },
    { patterns: ["steam"],                                  icon: "" },
    { patterns: ["vlc"],                                    icon: "󰕼" },
    { patterns: ["mpv"],                                    icon: "" },

    // Files
    { patterns: ["nautilus", "dolphin", "thunar", "yazi"],  icon: "" },

    // Omarchy Tools & System
    { patterns: ["impala"],                                 icon: "󰤨" },
    { patterns: ["bluetui"],                                icon: "󰂰" },
    { patterns: ["wiremix"],                                icon: "󰕾" },
    { patterns: ["btop"],                                   icon: "󰍛" },
    { patterns: ["lazydocker"],                             icon: "󰡨" },
    { patterns: ["lazygit"],                                icon: "󰊢" },

    // Password Managers & Vaults
    { patterns: ["bitwarden", "com.bitwarden.desktop"],     icon: "app:com.bitwarden.desktop" }
  ]

  readonly property var titleFallbackRules: [
    { patterns: ["chrome", "google"],                       icon: "" },
    { patterns: ["ghostty"],                                icon: "app:com.mitchellh.ghostty" },
    { patterns: ["kitty"],                                  icon: "app:kitty", brightness: 0.80, contrast: 1.0 },
    { patterns: ["bash", "zsh"],                            icon: "" },
    { patterns: ["antigravity"],                            icon: "app:antigravity", brightness: 0.80, contrast: 1.0 },
    { patterns: ["code"],                                   icon: "" },
    { patterns: ["spotify"],                                icon: "" },
    { patterns: ["discord"],                                icon: "" },
    { patterns: ["bitwarden"],                              icon: "app:com.bitwarden.desktop" }
  ]

  function matchRule(rules, target) {
    if (!target) return null
    for (var i = 0; i < rules.length; i++) {
      var rule = rules[i]
      for (var j = 0; j < rule.patterns.length; j++) {
        if (target.indexOf(rule.patterns[j]) !== -1) {
          return {
            icon: rule.icon,
            brightness: (typeof rule.brightness === "number") ? rule.brightness : 0.0,
            contrast: (typeof rule.contrast === "number") ? rule.contrast : 1.0
          }
        }
      }
    }
    return null
  }

  function iconForToplevel(toplevel) {
    if (!toplevel) return { icon: "", brightness: 0.0, contrast: 1.0 }

    var cls = ""
    var title = ""

    // 1. Try wayland (Wayland toplevel instance for this exact window)
    var wlHandle = toplevel.wayland || toplevel.waylandHandle
    if (wlHandle) {
      if (wlHandle.appId) cls = String(wlHandle.appId)
      if (wlHandle.title) title = String(wlHandle.title)
    }

    // 2. Try direct properties on toplevel
    if (!cls) {
      if (toplevel.appId) cls = String(toplevel.appId)
      else if (toplevel.waylandClass) cls = String(toplevel.waylandClass)
      else if (toplevel.initialClass) cls = String(toplevel.initialClass)
      else if (toplevel.cls) cls = String(toplevel.cls)
      else if (toplevel.klass) cls = String(toplevel.klass)
      else if (toplevel["class"]) cls = String(toplevel["class"])
    }

    if (!title && toplevel.title) {
      title = String(toplevel.title)
    }

    // 3. Try lastIpcObject (Hyprland IPC JSON properties)
    if (toplevel.lastIpcObject) {
      if (!cls) {
        if (toplevel.lastIpcObject["class"]) cls = String(toplevel.lastIpcObject["class"])
        else if (toplevel.lastIpcObject.initialClass) cls = String(toplevel.lastIpcObject.initialClass)
      }
      if (!title) {
        if (toplevel.lastIpcObject.title) title = String(toplevel.lastIpcObject.title)
        else if (toplevel.lastIpcObject.initialTitle) title = String(toplevel.lastIpcObject.initialTitle)
      }
    }

    if (!title && toplevel.initialTitle) {
      title = String(toplevel.initialTitle)
    }

    // 4. Only if this EXACT toplevel instance is the active Wayland window, use active title
    if (wlHandle && ToplevelManager.activeToplevel && wlHandle === ToplevelManager.activeToplevel) {
      if (ToplevelManager.activeToplevel.title) {
        title = String(ToplevelManager.activeToplevel.title)
      }
    }

    var clsLower = cls.toLowerCase()
    var titleLower = title.toLowerCase()

    var isBrowser = (clsLower.indexOf("chrome") !== -1 ||
                     clsLower.indexOf("chromium") !== -1 ||
                     clsLower.indexOf("brave") !== -1 ||
                     clsLower.indexOf("firefox") !== -1 ||
                     clsLower.indexOf("zen") !== -1 ||
                     clsLower.indexOf("librewolf") !== -1 ||
                     clsLower.indexOf("browser") !== -1)

    // Tier 1: Semantic Title Patterns (Webapps & Special States - evaluated for browsers)
    var ruleMatch = null
    if (isBrowser) {
      ruleMatch = matchRule(root.titleRules, titleLower)
      if (ruleMatch) return ruleMatch
    }

    // Tier 2: Application Class Mapping (appId / class)
    ruleMatch = matchRule(root.classRules, clsLower)
    if (ruleMatch) return ruleMatch

    // Tier 3: Title Heuristics Fallback
    ruleMatch = matchRule(root.titleFallbackRules, titleLower)
    if (ruleMatch) return ruleMatch

    // Tier 4: Generic window icon fallback
    return { icon: "", brightness: 0.0, contrast: 1.0 }
  }

  function getWorkspaceIcons(workspace, id, focused) {
    if (!workspace || !workspace.toplevels || !workspace.toplevels.values || workspace.toplevels.values.length === 0) {
      return [{ icon: focused ? "\uDB85\uDCFB" : root.displayLabel(id), brightness: 0.0, contrast: 1.0 }]
    }

    var toplevels = workspace.toplevels.values
    var icons = []
    for (var i = 0; i < toplevels.length; i++) {
      var iconSpec = root.iconForToplevel(toplevels[i])
      if (iconSpec) icons.push(iconSpec)
    }
    return icons.length > 0 ? icons : [{ icon: focused ? "\uDB85\uDCFB" : root.displayLabel(id), brightness: 0.0, contrast: 1.0 }]
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.visibleWorkspaceIds.length
    columnSpacing: root.vertical ? 0 : Style.space(3)
    rowSpacing: root.vertical ? Style.space(3) : 0

    Repeater {
      model: root.visibleWorkspaceIds

      Item {
        id: pillItem
        required property int modelData
        required property int index

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels && workspace.toplevels.values && workspace.toplevels.values.length > 0
        readonly property var activeWorkspace: root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace : Hyprland.focusedWorkspace
        readonly property bool focused: {
          if (!activeWorkspace) return false
          if (modelData === 0) return root.isZeroWorkspace(activeWorkspace)
          return activeWorkspace.id === modelData
        }
        readonly property bool firstGuest: root.isGuest(modelData) && index > 0 && !root.isGuest(root.visibleWorkspaceIds[index - 1])

        // A gap sets visiting workspaces apart from the monitor's own.
        Layout.leftMargin: firstGuest && !root.vertical ? Style.space(6) : 0
        Layout.topMargin: firstGuest && root.vertical ? Style.space(6) : 0

        // Reactive signature that triggers instant icon re-computation on tab/title changes for THIS workspace only
        readonly property string toplevelSignature: {
          var sig = ""
          if (workspace && workspace.toplevels && workspace.toplevels.values) {
            var vals = workspace.toplevels.values
            for (var i = 0; i < vals.length; i++) {
              var t = vals[i]
              if (t.wayland && t.wayland.title) sig += t.wayland.title + ";"
              if (t.waylandHandle && t.waylandHandle.title) sig += t.waylandHandle.title + ";"
              if (t.title) sig += t.title + ";"
              if (t.lastIpcObject && t.lastIpcObject.title) sig += t.lastIpcObject.title + ";"
            }
          }
          if (focused && (!root.monitor || root.monitor.focused) && ToplevelManager.activeToplevel) {
            sig += (ToplevelManager.activeToplevel.title || "") + ";"
          }
          return sig
        }

        readonly property var iconList: {
          var _dep = toplevelSignature
          return root.getWorkspaceIcons(workspace, modelData, focused)
        }
        readonly property color itemColor: {
          if (focused) return Commons.Color.accent
          if (mouseArea.containsMouse) return Commons.Color.foreground
          if (occupied) return Qt.lighter(Commons.Color.muted, 1.65)
          return Util.alpha(Commons.Color.muted, 0.45)
        }

        implicitWidth: pillRect.implicitWidth
        implicitHeight: root.barSize

        Rectangle {
          id: pillRect
          anchors.verticalCenter: parent.verticalCenter
          height: root.barSize - 8
          radius: height / 2

          implicitWidth: Math.max(height, iconsRow.implicitWidth + 14)

          color: {
            if (focused) return Util.alpha(Commons.Color.accent, 0.22)
            if (mouseArea.containsMouse) return Util.alpha(Commons.Color.foreground, 0.12)
            if (occupied) return Util.alpha(Commons.Color.foreground, 0.06)
            return "transparent"
          }

          border.color: {
            if (focused) return Commons.Color.accent
            if (mouseArea.containsMouse) return Util.alpha(Commons.Color.foreground, 0.3)
            if (occupied) return Util.alpha(Commons.Color.foreground, 0.15)
            return "transparent"
          }
          border.width: focused ? 1.5 : (occupied ? 1 : 0)

          Behavior on color { ColorAnimation { duration: 140 } }
          Behavior on border.color { ColorAnimation { duration: 140 } }

          Row {
            id: iconsRow
            anchors.centerIn: parent
            spacing: Style.space(2)

            Repeater {
              model: pillItem.iconList

              Item {
                required property var modelData
                readonly property var spec: root.getIconSpec(modelData)
                readonly property string resolvedSvg: root.resolveIconSource(spec.icon)
                readonly property bool hasSvg: resolvedSvg.length > 0
                readonly property real iconSize: Math.max(13, Style.font.body)

                width: hasSvg ? iconSize : glyphText.implicitWidth
                height: hasSvg ? iconSize : glyphText.implicitHeight
                anchors.verticalCenter: parent.verticalCenter

                // 1. Default Nerd Font / Numeric Glyph
                Text {
                  id: glyphText
                  visible: !hasSvg
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: hasSvg ? "" : root.getGlyphOrFallback(spec.icon)
                  color: pillItem.itemColor
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pixelSize: Style.font.body
                  renderType: Text.NativeRendering
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter

                  Behavior on color { ColorAnimation { duration: 140 } }
                }

                // 2. Theme-Aware Vector Icon (Papirus SVG / PNG via MultiEffect)
                Image {
                  id: svgImage
                  visible: false
                  anchors.fill: parent
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: Math.round(width * Screen.devicePixelRatio)
                  sourceSize.height: Math.round(height * Screen.devicePixelRatio)
                  source: hasSvg ? resolvedSvg : ""
                  layer.enabled: hasSvg
                  smooth: true
                }

                MultiEffect {
                  visible: hasSvg
                  anchors.fill: svgImage
                  source: svgImage
                  brightness: spec.brightness
                  contrast: spec.contrast
                  colorization: 1.0
                  colorizationColor: pillItem.itemColor

                  Behavior on colorizationColor { ColorAnimation { duration: 140 } }
                }
              }
            }
          }
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: function() { root.focusWorkspace(pillItem.modelData) }
        }
      }
    }
  }
}
