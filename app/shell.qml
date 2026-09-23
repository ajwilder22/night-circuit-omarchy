import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: root
  property date now: new Date()
  property var stats: ({ cpu: 0, memory: 0, disk: 0, battery: null, uptime: "—" })
  property var music: ({ connected: false, state: "stopped", title: "Open cliamp to play",
    artist: "Music is ready", station: "", shuffle: false, repeat: "Off", eq: "Flat", effect: "Clean", index: 0, total: 0 })
  property bool editorOpen: false
  property bool musicHubOpen: false
  property string libraryProvider: "radio"
  property string libraryMode: "search"
  property var libraryItems: []
  property string libraryMessage: "Search radio stations or browse your queue."
  property var defaults: ({ scale: 0.65, side: "left", edge: 12, top: 34, gap: 10,
    cornerRadius: 20, opacity: 0.87, borderOpacity: 0.22,
    background: "#15191e", border: "#687278", text: "#f4f1eb",
    muted: "#a8aaa9", accent: "#d9ae73", secondary: "#78c6c8",
    tertiary: "#b6a8d7", track: "#3d4346", clock12: true,
    followThemeColors: true, followThemeShape: true })
  property var settings: Object.assign({}, defaults)
  property var themePalette: ({ background: "#171a1e", border: "#7a7a7a", text: "#ffffff",
    muted: "#a8aaa9", accent: "#8d8d8d", secondary: "#b0b0b0",
    tertiary: "#9b9b9b", track: "#34383d", cornerRadius: 16 })
  readonly property int widgetRadius: settings.followThemeShape ? themePalette.cornerRadius : settings.cornerRadius
  readonly property real effectiveScale: Math.min(settings.scale,
    Math.max(0.4, (Quickshell.screens[0].height - settings.top - 50) / stack.implicitHeight))
  readonly property color ink: themeColor("text")
  readonly property color muted: themeColor("muted")
  readonly property color accent: themeColor("accent")
  readonly property color cyan: themeColor("secondary")
  readonly property color card: withOpacity(themeColor("background"), settings.opacity)
  readonly property color border: withOpacity(themeColor("border"), settings.borderOpacity)
  readonly property string sans: "Noto Sans"
  readonly property string mono: "monospace"

  function pad(n) { return String(n).padStart(2, "0") }
  function withOpacity(hex, alpha) {
    var c = Qt.color(hex)
    return Qt.rgba(c.r, c.g, c.b, alpha)
  }
  function themeColor(key) { return settings.followThemeColors ? themePalette[key] : settings[key] }
  function contrastColor(hex) {
    var c = Qt.color(hex)
    return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) > 0.55 ? "#172c3d" : "#ffffff"
  }
  function applySettings(changes) {
    settings = Object.assign({}, settings, changes)
    saveSettings.restart()
  }
  function setSetting(key, value) {
    var change = {}
    change[key] = value
    if (key === "cornerRadius") change.followThemeShape = false
    if (["background", "border", "text", "muted", "accent", "secondary", "tertiary", "track"].indexOf(key) >= 0)
      change.followThemeColors = false
    applySettings(change)
  }
  function loadSettings(raw) {
    try {
      var values = JSON.parse(raw)
      if (values && typeof values === "object") settings = Object.assign({}, settings, values)
    } catch (error) { console.warn("Widget settings:", error) }
  }
  function isHex(value) { return /^#[0-9a-fA-F]{6}$/.test(value) }
  function formatValue(item) {
    var value = item.key === "cornerRadius" ? widgetRadius : settings[item.key]
    if (item.unit === "%") return Math.round(value * 100) + "%"
    return Math.round(value) + " px"
  }
  function monthName(d) { return Qt.formatDate(d, "MMMM yyyy") }
  function monthDay(index) {
    var first = new Date(now.getFullYear(), now.getMonth(), 1)
    var offset = (first.getDay() + 6) % 7
    return new Date(now.getFullYear(), now.getMonth(), index - offset + 1)
  }
  function launchApp(desktopId) {
    Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", desktopId + ".desktop"])
  }
  function openCliamp() { Quickshell.execDetached(["omarchy-launch-or-focus-tui", "cliamp"]) }
  function musicCommand(command) { Quickshell.execDetached(["cliamp", command]) }
  function musicVolume(delta) { Quickshell.execDetached(["cliamp", "remote", "call", "volume.adjust", "--params", JSON.stringify({ value: delta })]) }
  function effectCommand(name) { Quickshell.execDetached(["easyeffects", "-l", "Night Circuit - " + name]) }
  function libraryQuery(kind, value) {
    libraryMode = kind
    libraryItems = []
    libraryMessage = "Loading…"
    libraryProcess.running = false
    var script = Quickshell.env("HOME") + "/.config/quickshell/night-circuit-widgets/cliamp_library.py"
    if (kind === "search") libraryProcess.command = ["python3", script, "search", libraryProvider, value]
    else if (kind === "playlists") libraryProcess.command = ["python3", script, "playlists", libraryProvider]
    else libraryProcess.command = ["python3", script, "queue"]
    libraryProcess.running = true
  }
  function libraryAction(action, item) {
    var script = Quickshell.env("HOME") + "/.config/quickshell/night-circuit-widgets/cliamp_library.py"
    if (action === "play-index") Quickshell.execDetached(["python3", script, action, String(item.index || 0)])
    else if (action === "load-playlist") Quickshell.execDetached(["python3", script, action, String(item.provider || libraryProvider), String(item.id)])
    else Quickshell.execDetached(["python3", script, action, JSON.stringify(item)])
  }
  function iconFor(name) {
    var found = Quickshell.iconPath(name, true)
    return found.length > 0 ? found : Quickshell.iconPath("application-x-executable", true)
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }

  FileView {
    id: settingsFile
    path: Quickshell.env("HOME") + "/.config/quickshell/night-circuit-widgets/settings.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSettings(text())
    onFileChanged: reload()
  }
  FileView {
    id: themeFile
    path: Quickshell.env("HOME") + "/.config/quickshell/night-circuit-widgets/theme.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try { root.themePalette = Object.assign({}, root.themePalette, JSON.parse(text())) }
      catch (error) { console.warn("Widget theme:", error) }
    }
    onFileChanged: reload()
  }
  Timer {
    id: saveSettings
    interval: 350
    onTriggered: settingsFile.setText(JSON.stringify(root.settings, null, 2) + "\n")
  }

  IpcHandler {
    target: "desktop-widgets"
    function toggleSettings(): string {
      root.editorOpen = !root.editorOpen
      return root.editorOpen ? "open" : "closed"
    }
    function toggleMusicHub(): string {
      root.musicHubOpen = !root.musicHubOpen
      return root.musicHubOpen ? "open" : "closed"
    }
    function searchRadio(query: string): string {
      root.libraryProvider = "radio"
      root.musicHubOpen = true
      root.libraryQuery("search", query)
      return "searching"
    }
  }

  Process {
    id: telemetry
    running: true
    command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/night-circuit-widgets/telemetry.py"]
    stdout: SplitParser {
      onRead: function(line) {
        try { root.stats = JSON.parse(line) } catch (error) { console.warn("Telemetry:", error) }
      }
    }
    onExited: retry.start()
  }
  Timer { id: retry; interval: 3000; onTriggered: telemetry.running = true }

  Process {
    id: musicState
    running: true
    command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/night-circuit-widgets/cliamp_state.py"]
    stdout: SplitParser {
      onRead: function(line) {
        try { root.music = JSON.parse(line) } catch (error) { console.warn("cliamp state:", error) }
      }
    }
    onExited: musicRetry.start()
  }
  Timer { id: musicRetry; interval: 3000; onTriggered: musicState.running = true }
  Process {
    id: libraryProcess
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var result = JSON.parse(line)
          root.libraryItems = result.items || []
          root.libraryMessage = result.error || (root.libraryItems.length ? "" : "Nothing found")
        } catch (error) { root.libraryMessage = "Could not read cliamp library" }
      }
    }
  }

  PanelWindow {
    id: panel
    screen: Quickshell.screens[0]
    anchors { top: true; left: root.settings.side === "left"; right: root.settings.side === "right" }
    margins { top: root.settings.top; left: root.settings.edge; right: root.settings.edge }
    implicitWidth: Math.ceil(294 * root.effectiveScale)
    implicitHeight: Math.ceil(stack.implicitHeight * root.effectiveScale)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "night-circuit-widgets"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Column {
      id: stack
      width: 294
      height: implicitHeight
      transformOrigin: Item.TopLeft
      scale: root.effectiveScale
      spacing: root.settings.gap

      Rectangle {
        width: parent.width; height: 160; radius: root.widgetRadius
        color: root.card; border.color: root.border; border.width: 1
        Column {
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
          spacing: 5
          Text { text: "YOUR SPACE  /  " + Qt.formatDate(root.now, "ddd").toUpperCase(); color: root.accent; font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 2 }
          Text { text: Qt.formatTime(root.now, root.settings.clock12 ? "h:mm AP" : "HH:mm"); color: root.ink; font.family: root.sans; font.pixelSize: root.settings.clock12 ? 46 : 52; font.weight: Font.Light }
          Text { text: Qt.formatDate(root.now, "dddd, MMMM d"); color: root.muted; font.family: root.sans; font.pixelSize: 15 }
        }
        Rectangle { x: 20; y: 139; width: parent.width - 40; height: 1; color: root.border }
        Rectangle {
          anchors { right: parent.right; top: parent.top; rightMargin: 14; topMargin: 12 }
          width: 48; height: 30; radius: 10
          color: root.withOpacity(root.accent, 0.16)
          Text { anchors.centerIn: parent; text: "EDIT"; color: root.accent; font.family: root.mono; font.pixelSize: 10; font.weight: Font.Bold }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.editorOpen = true }
        }
      }

      Rectangle {
        width: parent.width; height: 252; radius: root.widgetRadius
        color: root.card; border.color: root.border; border.width: 1
        Column {
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
          spacing: 12
          Row {
            width: parent.width
            Text { text: root.monthName(root.now); width: parent.width - 52; color: root.ink; font.family: root.sans; font.pixelSize: 16; font.weight: Font.Medium }
            Text { text: root.pad(root.now.getDate()); color: root.accent; font.family: root.mono; font.pixelSize: 15 }
          }
          Grid {
            width: parent.width; columns: 7; rowSpacing: 2; columnSpacing: 0
            Repeater {
              model: ["M", "T", "W", "T", "F", "S", "S"]
              delegate: Text { required property string modelData; width: parent.width / 7; height: 20; text: modelData; horizontalAlignment: Text.AlignHCenter; color: root.muted; font.family: root.mono; font.pixelSize: 10 }
            }
            Repeater {
              model: 42
              delegate: Item {
                required property int index
                width: parent.width / 7; height: 26
                readonly property date day: root.monthDay(index)
                readonly property bool current: day.getMonth() === root.now.getMonth()
                readonly property bool today: day.toDateString() === root.now.toDateString()
                Rectangle { anchors.centerIn: parent; width: 25; height: 24; radius: Math.min(8, root.widgetRadius); color: parent.today ? root.accent : "transparent" }
                Text { anchors.centerIn: parent; text: parent.day.getDate(); color: parent.today ? root.contrastColor(root.accent) : (parent.current ? root.ink : root.muted); font.family: root.mono; font.pixelSize: 11; font.weight: parent.today ? Font.Bold : Font.Normal }
              }
            }
          }
        }
      }

      Rectangle {
        width: parent.width; height: 158; radius: root.widgetRadius
        color: root.card; border.color: root.border; border.width: 1
        Column {
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
          spacing: 9
          Text { text: "SYSTEM / LIVE"; color: root.accent; font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 1.5 }
          Repeater {
            model: [
              { name: "CPU", value: root.stats.cpu, tone: root.cyan },
              { name: "MEMORY", value: root.stats.memory, tone: root.accent },
              { name: "STORAGE", value: root.stats.disk, tone: root.themeColor("tertiary") }
            ]
            delegate: Row {
              required property var modelData
              spacing: 10
              Text { width: 62; text: modelData.name; color: root.muted; font.family: root.mono; font.pixelSize: 10 }
              Rectangle {
                width: 132; height: 6; radius: 3; color: root.themeColor("track"); anchors.verticalCenter: parent.verticalCenter
                Rectangle { width: parent.width * Math.max(0, Math.min(100, modelData.value)) / 100; height: parent.height; radius: 3; color: modelData.tone; Behavior on width { NumberAnimation { duration: 350 } } }
              }
              Text { width: 39; text: modelData.value + "%"; color: root.ink; font.family: root.mono; font.pixelSize: 10; horizontalAlignment: Text.AlignRight }
            }
          }
        }
      }

      Rectangle {
        width: parent.width; height: 80; radius: root.widgetRadius
        color: root.card; border.color: root.border; border.width: 1
        Row {
          anchors { fill: parent; margins: 17 }
          spacing: 12
          Column {
            width: 118; spacing: 4
            Text { text: "UPTIME"; color: root.muted; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1.4 }
            Text { text: root.stats.uptime; color: root.ink; font.family: root.sans; font.pixelSize: 18; font.weight: Font.Medium }
          }
          Rectangle { width: 1; height: 44; color: root.border }
          Column {
            spacing: 4
            Text { text: root.stats.battery ? "BATTERY" : "LOCAL TIME"; color: root.muted; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1.4 }
            Text { text: root.stats.battery ? root.stats.battery.percent + "%" : Qt.formatTime(root.now, "AP"); color: root.cyan; font.family: root.sans; font.pixelSize: 18; font.weight: Font.Medium }
          }
        }
      }

      Rectangle {
        width: parent.width; height: 207; radius: root.widgetRadius
        color: root.card; border.color: root.border; border.width: 1
        Column {
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
          spacing: 7
          Row {
            width: parent.width
            Text { text: "CLIAMP  /  NOW PLAYING"; width: parent.width - 47; color: root.accent; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1.4 }
            Text { text: root.music.state === "playing" ? "● LIVE" : "○ IDLE"; color: root.music.state === "playing" ? root.cyan : root.muted; font.family: root.mono; font.pixelSize: 9 }
          }
          Text { text: root.music.title; width: parent.width; elide: Text.ElideRight; color: root.ink; font.family: root.sans; font.pixelSize: 17; font.weight: Font.Medium }
          Text { text: root.music.artist; width: parent.width; elide: Text.ElideRight; color: root.muted; font.family: root.sans; font.pixelSize: 11 }
          Row {
            spacing: 7
            Repeater {
              model: [
                { label: "◀◀", action: "prev", width: 47 },
                { label: root.music.state === "playing" ? "Ⅱ" : "▶", action: "toggle", width: 55 },
                { label: "▶▶", action: "next", width: 47 }
              ]
              delegate: Rectangle {
                required property var modelData
                width: modelData.width; height: 33; radius: Math.min(9, root.widgetRadius)
                color: modelData.action === "toggle" ? root.accent : root.withOpacity(root.themeColor("track"), 0.85)
                Text { anchors.centerIn: parent; text: modelData.label; color: modelData.action === "toggle" ? root.contrastColor(root.accent) : root.ink; font.family: root.sans; font.pixelSize: 13; font.weight: Font.Bold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.musicCommand(modelData.action) }
              }
            }
            Rectangle { width: 1; height: 30; color: root.border }
            Text {
              text: "OPEN"; width: 37; height: 33; verticalAlignment: Text.AlignVCenter
              color: root.cyan; font.family: root.mono; font.pixelSize: 10; font.weight: Font.Bold
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openCliamp() }
            }
          }
          Row {
            spacing: 17
            Text {
              text: root.music.shuffle ? "SHUFFLE ON" : "SHUFFLE OFF"
              color: root.music.shuffle ? root.accent : root.muted
              font.family: root.mono; font.pixelSize: 9
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.musicCommand("shuffle") }
            }
            Text {
              text: "REPEAT " + String(root.music.repeat).toUpperCase()
              color: root.music.repeat === "Off" ? root.muted : root.accent
              font.family: root.mono; font.pixelSize: 9
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.musicCommand("repeat") }
            }
          }
          Text {
            text: "LIBRARY  /  SEARCH  /  QUEUE"; color: root.cyan
            font.family: root.mono; font.pixelSize: 10; font.weight: Font.Bold
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.musicHubOpen = true }
          }
          Row {
            spacing: 14
            Text { text: "VOLUME"; color: root.muted; font.family: root.mono; font.pixelSize: 10 }
            Text {
              text: "−"; color: root.accent; font.family: root.sans; font.pixelSize: 16; font.weight: Font.Bold
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.musicVolume(-2) }
            }
            Text {
              text: "+"; color: root.accent; font.family: root.sans; font.pixelSize: 16; font.weight: Font.Bold
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.musicVolume(2) }
            }
          }
        }
      }

      Rectangle {
        width: parent.width; height: 150; radius: root.widgetRadius
        color: root.card; border.color: root.border; border.width: 1
        Column {
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
          spacing: 9
          Row {
            width: parent.width
            Text { text: "SOUND  /  SPACE"; width: parent.width - 65; color: root.accent; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1.4 }
            Text {
              text: "MIXER"; color: root.cyan; font.family: root.mono; font.pixelSize: 10; font.weight: Font.Bold
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["uwsm-app", "--", "easyeffects"]) }
            }
          }
          Text { text: "Active: " + root.music.effect; color: root.muted; font.family: root.sans; font.pixelSize: 11 }
          Grid {
            columns: 3; rowSpacing: 6; columnSpacing: 6
            Repeater {
              model: ["Clean", "Studio", "Room", "Concert Hall", "Church", "Dreamscape"]
              delegate: Rectangle {
                required property string modelData
                width: 81; height: 28; radius: Math.min(8, root.widgetRadius)
                color: root.music.effect === modelData ? root.accent : root.withOpacity(root.themeColor("track"), 0.8)
                Text { anchors.centerIn: parent; text: modelData; color: root.music.effect === modelData ? root.contrastColor(root.accent) : root.ink; font.family: root.sans; font.pixelSize: 10; font.weight: root.music.effect === modelData ? Font.Bold : Font.Normal }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.effectCommand(modelData) }
              }
            }
          }
        }
      }
    }
  }

  PanelWindow {
    id: editor
    screen: Quickshell.screens[0]
    visible: root.editorOpen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "night-circuit-widgets-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: "#99080a0d"
      MouseArea { anchors.fill: parent; onClicked: root.editorOpen = false }
    }

    Item {
      anchors.fill: parent
      focus: root.editorOpen
      Keys.onEscapePressed: root.editorOpen = false

      Rectangle {
        id: editorCard
        anchors.centerIn: parent
        width: Math.min(820, parent.width - 48)
        height: Math.min(730, parent.height - 72)
        radius: root.widgetRadius
        color: "#1a1f24"
        border.color: "#596268"
        border.width: 1

        MouseArea { anchors.fill: parent; onClicked: {} }

        Item {
          id: editorHeader
          anchors { top: parent.top; left: parent.left; right: parent.right }
          height: 78
          Text { anchors { left: parent.left; leftMargin: 28; verticalCenter: parent.verticalCenter } text: "CUSTOMIZE WIDGETS"; color: "#f4f1eb"; font.family: root.sans; font.pixelSize: 22; font.weight: Font.DemiBold }
          Text { anchors { right: closeButton.left; rightMargin: 18; verticalCenter: parent.verticalCenter } text: "Changes save automatically"; color: "#a8aaa9"; font.family: root.sans; font.pixelSize: 12 }
          Rectangle {
            id: closeButton
            anchors { right: parent.right; rightMargin: 23; verticalCenter: parent.verticalCenter }
            width: 32; height: 32; radius: 10; color: "#333c41"
            Text { anchors.centerIn: parent; text: "×"; color: "#f4f1eb"; font.pixelSize: 20 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.editorOpen = false }
          }
        }
        Rectangle { anchors { top: editorHeader.bottom; left: parent.left; right: parent.right } height: 1; color: "#384045" }

        Flickable {
          id: settingsScroll
          anchors { top: editorHeader.bottom; bottom: editorFooter.top; left: parent.left; right: parent.right; margins: 24 }
          clip: true
          contentWidth: width
          contentHeight: settingsColumns.implicitHeight + 20
          boundsBehavior: Flickable.StopAtBounds

          Row {
            id: settingsColumns
            width: parent.width
            spacing: 28

            Column {
              width: (settingsColumns.width - settingsColumns.spacing) / 2
              spacing: 10
              Text { text: "LAYOUT & SHAPE"; color: root.accent; font.family: root.mono; font.pixelSize: 12; font.letterSpacing: 1.5 }

              Row {
                spacing: 8
                Repeater {
                  model: [true, false]
                  delegate: Rectangle {
                    required property bool modelData
                    width: 112; height: 32; radius: 9
                    color: root.settings.followThemeShape === modelData ? root.accent : "#30383d"
                    Text { anchors.centerIn: parent; text: modelData ? "Theme shape" : "Custom shape"; color: root.settings.followThemeShape === modelData ? root.contrastColor(root.accent) : "#e3e5e5"; font.family: root.sans; font.pixelSize: 11 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setSetting("followThemeShape", modelData) }
                  }
                }
              }

              Row {
                spacing: 8
                Repeater {
                  model: ["left", "right"]
                  delegate: Rectangle {
                    required property string modelData
                    width: 94; height: 36; radius: 10
                    color: root.settings.side === modelData ? root.accent : "#30383d"
                    Text { anchors.centerIn: parent; text: modelData === "left" ? "Left side" : "Right side"; color: root.settings.side === modelData ? "#14181b" : "#e3e5e5"; font.family: root.sans; font.pixelSize: 12; font.weight: Font.Medium }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setSetting("side", modelData) }
                  }
                }
              }

              Repeater {
                model: [
                  { key: "scale", name: "Size", from: 0.4, to: 1.4, step: 0.01, unit: "%" },
                  { key: "cornerRadius", name: "Corner roundness", from: 0, to: 48, step: 1 },
                  { key: "gap", name: "Space between cards", from: 0, to: 32, step: 1 },
                  { key: "edge", name: "Distance from edge", from: 0, to: 100, step: 1 },
                  { key: "top", name: "Distance from top", from: 0, to: 220, step: 1 },
                  { key: "opacity", name: "Card opacity", from: 0.2, to: 1, step: 0.01, unit: "%" },
                  { key: "borderOpacity", name: "Border opacity", from: 0, to: 1, step: 0.01, unit: "%" }
                ]
                delegate: Column {
                  required property var modelData
                  width: parent.width; spacing: 2
                  Row {
                    width: parent.width
                    Text { width: parent.width - 70; text: modelData.name; color: "#e3e5e5"; font.family: root.sans; font.pixelSize: 12 }
                    Text { width: 70; text: root.formatValue(modelData); color: root.accent; font.family: root.mono; font.pixelSize: 12; horizontalAlignment: Text.AlignRight }
                  }
                  QQC.Slider {
                    width: parent.width - 4; height: 28
                    from: modelData.from; to: modelData.to; stepSize: modelData.step
                    value: modelData.key === "cornerRadius" ? root.widgetRadius : root.settings[modelData.key]
                    onMoved: root.setSetting(modelData.key, value)
                    background: Rectangle {
                      x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - 3
                      width: parent.availableWidth; height: 6; radius: 3; color: "#434d52"
                      Rectangle { width: parent.width * parent.parent.visualPosition; height: parent.height; radius: 3; color: root.accent }
                    }
                    handle: Rectangle {
                      x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                      y: parent.topPadding + parent.availableHeight / 2 - height / 2
                      width: 16; height: 16; radius: 8; color: "#f4f1eb"; border.color: root.accent
                    }
                  }
                }
              }
            }

            Column {
              width: (settingsColumns.width - settingsColumns.spacing) / 2
              spacing: 9
              Text { text: "COLORS & CLOCK"; color: root.accent; font.family: root.mono; font.pixelSize: 12; font.letterSpacing: 1.5 }
              Row {
                spacing: 8
                Repeater {
                  model: [true, false]
                  delegate: Rectangle {
                    required property bool modelData
                    width: 112; height: 32; radius: 9
                    color: root.settings.followThemeColors === modelData ? root.accent : "#30383d"
                    Text { anchors.centerIn: parent; text: modelData ? "Theme colors" : "Custom colors"; color: root.settings.followThemeColors === modelData ? root.contrastColor(root.accent) : "#e3e5e5"; font.family: root.sans; font.pixelSize: 11 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setSetting("followThemeColors", modelData) }
                  }
                }
              }
              Row {
                spacing: 8
                Repeater {
                  model: [true, false]
                  delegate: Rectangle {
                    required property bool modelData
                    width: 108; height: 36; radius: 10
                    color: root.settings.clock12 === modelData ? root.accent : "#30383d"
                    Text { anchors.centerIn: parent; text: modelData ? "12-hour" : "24-hour"; color: root.settings.clock12 === modelData ? "#14181b" : "#e3e5e5"; font.family: root.sans; font.pixelSize: 12; font.weight: Font.Medium }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setSetting("clock12", modelData) }
                  }
                }
              }
              Text { text: "Pick a palette or enter any six-digit hex color."; color: "#a8aaa9"; font.family: root.sans; font.pixelSize: 11 }
              Row {
                spacing: 9
                Repeater {
                  model: [
                    { accent: "#d9ae73", secondary: "#78c6c8", tertiary: "#b6a8d7" },
                    { accent: "#87c9ff", secondary: "#b49aff", tertiary: "#ff9fbc" },
                    { accent: "#ed9c9c", secondary: "#f1cf8d", tertiary: "#a2d4ac" },
                    { accent: "#a2dfa9", secondary: "#8bd5ca", tertiary: "#f5c177" }
                  ]
                  delegate: Rectangle {
                    required property var modelData
                    width: 58; height: 31; radius: 9; color: "#30383d"
                    Row {
                      anchors.centerIn: parent; spacing: 3
                      Repeater {
                        model: [modelData.accent, modelData.secondary, modelData.tertiary]
                        delegate: Rectangle { required property string modelData; width: 13; height: 13; radius: 7; color: modelData }
                      }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.applySettings(Object.assign({}, modelData, { followThemeColors: false })) }
                  }
                }
              }
              Repeater {
                model: [
                  { key: "accent", name: "Main accent" },
                  { key: "secondary", name: "Second accent" },
                  { key: "tertiary", name: "Third accent" },
                  { key: "background", name: "Card background" },
                  { key: "border", name: "Card border" },
                  { key: "text", name: "Main text" },
                  { key: "muted", name: "Muted text" },
                  { key: "track", name: "Gauge track" }
                ]
                delegate: Row {
                  id: colorRow
                  required property var modelData
                  width: parent.width; height: 42; spacing: 10
                  Rectangle { width: 23; height: 23; radius: 7; color: root.themeColor(colorRow.modelData.key); border.color: "#788187"; anchors.verticalCenter: parent.verticalCenter }
                  Text { width: 120; text: colorRow.modelData.name; color: "#e3e5e5"; font.family: root.sans; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                  QQC.TextField {
                    id: hexField
                    width: 114; height: 31
                    text: root.themeColor(colorRow.modelData.key)
                    color: "#f4f1eb"; font.family: root.mono; font.pixelSize: 12
                    selectByMouse: true
                    background: Rectangle { radius: 8; color: "#30383d"; border.color: hexField.activeFocus ? root.accent : "#4f5a60" }
                    onEditingFinished: {
                      if (root.isHex(text)) root.setSetting(colorRow.modelData.key, text)
                      else text = root.themeColor(colorRow.modelData.key)
                    }
                    Connections {
                      target: root
                      function onSettingsChanged() { if (!hexField.activeFocus) hexField.text = root.themeColor(colorRow.modelData.key) }
                      function onThemePaletteChanged() { if (!hexField.activeFocus) hexField.text = root.themeColor(colorRow.modelData.key) }
                    }
                  }
                }
              }
            }
          }
        }

        Item {
          id: editorFooter
          anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
          height: 62
          Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: 1; color: "#384045" }
          Rectangle {
            anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
            width: 130; height: 34; radius: 10; color: "#30383d"
            Text { anchors.centerIn: parent; text: "Reset defaults"; color: "#e3e5e5"; font.family: root.sans; font.pixelSize: 12 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.applySettings(root.defaults) }
          }
          Text { anchors { right: parent.right; rightMargin: 25; verticalCenter: parent.verticalCenter } text: "Press Esc or click outside to close"; color: "#a8aaa9"; font.family: root.sans; font.pixelSize: 11 }
        }
      }
    }
  }

  PanelWindow {
    id: musicHub
    screen: Quickshell.screens[0]
    visible: root.musicHubOpen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "night-circuit-music-hub"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: "#A0050913"
      MouseArea { anchors.fill: parent; onClicked: root.musicHubOpen = false }
    }
    Item {
      anchors.fill: parent
      focus: root.musicHubOpen
      Keys.onEscapePressed: root.musicHubOpen = false

      Rectangle {
        anchors.centerIn: parent
        width: Math.min(760, parent.width - 40)
        height: Math.min(560, parent.height - 70)
        radius: root.widgetRadius
        color: root.themeColor("background")
        border.color: root.accent
        border.width: 1
        MouseArea { anchors.fill: parent; onClicked: {} }

        Text {
          anchors { left: parent.left; top: parent.top; margins: 25 }
          text: "MUSIC STUDIO"; color: root.accent; font.family: root.mono
          font.pixelSize: 15; font.weight: Font.Bold; font.letterSpacing: 2
        }
        Text {
          anchors { right: parent.right; top: parent.top; margins: 25 }
          text: "CLOSE  ×"; color: root.muted; font.family: root.mono; font.pixelSize: 12
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.musicHubOpen = false }
        }
        Rectangle {
          anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 62; leftMargin: 25; rightMargin: 25 }
          height: 1; color: root.border
        }

        Row {
          anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 25; topMargin: 83 }
          spacing: 22
          Column {
            width: 288; spacing: 16
            Text { text: "NOW PLAYING"; color: root.cyan; font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 1.5 }
            Text { text: root.music.title; width: parent.width; wrapMode: Text.WordWrap; color: root.ink; font.family: root.sans; font.pixelSize: 24; font.weight: Font.Medium }
            Text { text: root.music.artist; width: parent.width; wrapMode: Text.WordWrap; color: root.muted; font.family: root.sans; font.pixelSize: 14 }
            Row {
              spacing: 10
              Repeater {
                model: [
                  { label: "PREV", action: "prev" },
                  { label: root.music.state === "playing" ? "PAUSE" : "PLAY", action: "toggle" },
                  { label: "NEXT", action: "next" }
                ]
                delegate: Rectangle {
                  required property var modelData
                  width: 84; height: 36; radius: Math.min(9, root.widgetRadius)
                  color: modelData.action === "toggle" ? root.accent : root.themeColor("track")
                  Text { anchors.centerIn: parent; text: modelData.label; color: modelData.action === "toggle" ? root.contrastColor(root.accent) : root.ink; font.family: root.mono; font.pixelSize: 11; font.weight: Font.Bold }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.musicCommand(modelData.action) }
                }
              }
            }
            Text { text: "QUEUE  " + root.music.index + " / " + root.music.total + "     EQ  " + root.music.eq; color: root.muted; font.family: root.mono; font.pixelSize: 10 }
            Rectangle { width: parent.width; height: 1; color: root.border }
            Text { text: "SOUND SPACES"; color: root.cyan; font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 1.5 }
            Grid {
              columns: 2; rowSpacing: 7; columnSpacing: 7
              Repeater {
                model: ["Clean", "Studio", "Room", "Concert Hall", "Church", "Dreamscape"]
                delegate: Rectangle {
                  required property string modelData
                  width: 139; height: 35; radius: Math.min(9, root.widgetRadius)
                  color: root.music.effect === modelData ? root.accent : root.themeColor("track")
                  Text { anchors.centerIn: parent; text: modelData; color: root.music.effect === modelData ? root.contrastColor(root.accent) : root.ink; font.family: root.sans; font.pixelSize: 12 }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.effectCommand(modelData) }
                }
              }
            }
            Text {
              text: "OPEN CLIAMP  ↗"; color: root.accent; font.family: root.mono; font.pixelSize: 11; font.weight: Font.Bold
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openCliamp() }
            }
          }
          Rectangle { width: 1; height: parent.height; color: root.border }
          Column {
            width: 354; spacing: 11
            Text { text: "LIBRARY  /  SEARCH"; color: root.cyan; font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 1.5 }
            Row {
              spacing: 8
              Repeater {
                model: ["radio", "local"]
                delegate: Rectangle {
                  required property string modelData
                  width: 72; height: 27; radius: 7
                  color: root.libraryProvider === modelData ? root.accent : root.themeColor("track")
                  Text { anchors.centerIn: parent; text: modelData.toUpperCase(); color: root.libraryProvider === modelData ? root.contrastColor(root.accent) : root.ink; font.family: root.mono; font.pixelSize: 10 }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.libraryProvider = modelData }
                }
              }
            }
            Row {
              spacing: 7
              QQC.TextField {
                id: musicSearch
                width: 273; height: 34
                placeholderText: "Search stations or local music"
                color: root.ink; placeholderTextColor: root.muted
                font.family: root.sans; font.pixelSize: 12
                background: Rectangle { radius: 8; color: root.themeColor("track"); border.color: root.border }
                onAccepted: root.libraryQuery("search", text)
              }
              Rectangle {
                width: 73; height: 34; radius: 8; color: root.accent
                Text { anchors.centerIn: parent; text: "FIND"; color: root.contrastColor(root.accent); font.family: root.mono; font.pixelSize: 10; font.weight: Font.Bold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.libraryQuery("search", musicSearch.text) }
              }
            }
            Row {
              spacing: 17
              Repeater {
                model: [ { label: "QUEUE", kind: "queue" }, { label: "PLAYLISTS", kind: "playlists" } ]
                delegate: Text {
                  required property var modelData
                  text: modelData.label; color: root.libraryMode === modelData.kind ? root.accent : root.muted
                  font.family: root.mono; font.pixelSize: 11; font.weight: Font.Bold
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.libraryQuery(modelData.kind, "") }
                }
              }
            }
            Rectangle { width: parent.width; height: 1; color: root.border }
            Flickable {
              width: parent.width; height: 332; contentHeight: results.implicitHeight; clip: true
              Column {
                id: results
                width: parent.width; spacing: 5
                Text { visible: root.libraryItems.length === 0; text: root.libraryMessage; color: root.muted; font.family: root.sans; font.pixelSize: 12; wrapMode: Text.WordWrap; width: parent.width }
                Repeater {
                  model: root.libraryItems
                  delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: results.width; height: 43; radius: 8
                    color: root.withOpacity(root.themeColor("track"), 0.65)
                    Text {
                      anchors { left: parent.left; leftMargin: 11; verticalCenter: parent.verticalCenter }
                      width: parent.width - 66; text: modelData.name || modelData.title || "Track"
                      elide: Text.ElideRight; color: root.ink; font.family: root.sans; font.pixelSize: 12
                    }
                    MouseArea {
                      anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: addButton.left }
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (root.libraryMode === "queue") root.libraryAction("play-index", { index: index })
                        else if (root.libraryMode === "playlists") root.libraryAction("load-playlist", modelData)
                        else root.libraryAction("play", modelData)
                      }
                    }
                    Text {
                      id: addButton
                      anchors { right: parent.right; rightMargin: 13; verticalCenter: parent.verticalCenter }
                      visible: root.libraryMode === "search"
                      text: "+"; color: root.accent; font.family: root.sans; font.pixelSize: 19; font.weight: Font.Bold
                      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.libraryAction("add", modelData) }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  PanelWindow {
    id: desktopShortcuts
    screen: Quickshell.screens[0]
    anchors { top: true; right: true }
    margins { top: 45; right: 32 }
    implicitWidth: 319
    implicitHeight: 329
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "night-circuit-desktop-shortcuts"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Text {
      anchors { top: parent.top; right: parent.right }
      text: "DESKTOP  /  APPS"
      color: root.accent
      font.family: root.mono
      font.pixelSize: 11
      font.letterSpacing: 2
      font.weight: Font.Bold
    }

    Grid {
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
      height: 301
      columns: 3
      rowSpacing: 8
      columnSpacing: 8
      Repeater {
        model: [
          { name: "Browser", icon: "chromium", id: "chromium" },
          { name: "Files", icon: "org.gnome.Nautilus", id: "org.gnome.Nautilus" },
          { name: "Terminal", icon: "foot", id: "foot" },
          { name: "ChatGPT", icon: "chatgpt", id: "chatgpt" },
          { name: "Steam", icon: "steam", id: "steam" },
          { name: "Discord", icon: "omarchy-discord", id: "Discord" },
          { name: "Obsidian", icon: "obsidian", id: "obsidian" },
          { name: "OBS Studio", icon: "com.obsproject.Studio", id: "com.obsproject.Studio" },
          { name: "Zoom", icon: "Zoom", id: "Zoom" }
        ]
        delegate: Rectangle {
          required property var modelData
          width: 101; height: 95; radius: Math.max(10, root.widgetRadius * 0.55)
          color: root.withOpacity(root.themeColor("background"), 0.9)
          border.color: root.border
          border.width: 1
          Rectangle {
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            width: 35; height: 2; radius: 1; color: root.accent
          }
          Column {
            anchors.centerIn: parent
            spacing: 5
            Image {
              width: 42; height: 42
              anchors.horizontalCenter: parent.horizontalCenter
              source: root.iconFor(modelData.icon)
              fillMode: Image.PreserveAspectFit
              smooth: true
            }
            Text {
              text: modelData.name
              width: 90
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              color: root.ink
              font.family: root.sans
              font.pixelSize: 12
            }
          }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.launchApp(modelData.id) }
        }
      }
    }
  }
}
