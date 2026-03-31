import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import qs.Services
import qs.Config
import qs.Modules.DynamicIsland.ClockContent
import qs.Modules.DynamicIsland.MediaContent
import qs.Modules.DynamicIsland.VolumeContent
import qs.Modules.DynamicIsland.LauncherContent
import qs.Modules.DynamicIsland.DashboardContent
import qs.Modules.DynamicIsland.LyricsContent
import qs.Modules.PolkitAuth
import org.kde.kirigami as Kirigami
import QtQuick.Effects
Kirigami.ShadowedRectangle {
    id: root
    focus: true
    anchors.horizontalCenter: parent.horizontalCenter
    transformOrigin: Item.Center
    color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.7)
    radius: unit
    // 边框处理（MD3 典型特征）
    border.width: 1
    border.color: Qt.alpha(Kirigami.Theme.dividerColor, 0.5) // 更细腻的边框
    readonly property real unit: Kirigami.Units.gridUnit
    layer.enabled: true
    // ================= 状态控制变量 =================
    property bool showDashboard: false
    property bool expanded: false
    property bool showLyrics: currentPlayer && currentPlayer.isPlaying
    property var currentPlayer: Lyrics.player

    // 简化后的逻辑判定
    property bool isDashboardMode: showDashboard
    property bool isWallpaperMode: !showDashboard
    property bool isLyricsMode: showLyrics && !showDashboard
    property bool isLauncherMode: !showDashboard && !isLyricsMode
    property bool isAuthMode: (PolkitService.agent.flow)? 1:0
    // ================= 状态机定义 (MD3 核心) =================
    states: [
	State {
	    name: "AUTH"
	    when: isAuthMode
	    PropertyChanges {
		    target: root
		    width: unit * 30
		    height: unit * 15
		    radius: unit * 1.5
	    }
	    },
        State {
            name: "DASHBOARD"
            when: showDashboard
            PropertyChanges {
                target: root
                width: unit * 45
                height: unit * 24
                radius: unit * 1.5
            }
        },
        State {
            name: "EXPANDED"
            when: expanded
            PropertyChanges {
                target: root
                width: unit * 24
                height: unit * 10
                radius: unit * 1.5
            }
        },
        State {
            name: "LYRICS"
            when: showLyrics && !showDashboard
            PropertyChanges {
                target: root
                width: unit * 28
                height: unit * 2.5
                radius: unit
            }
        },
        State {
            name: "COLLAPSED"
            when: true
            PropertyChanges {
                target: root
                width: unit * 12
                height: unit * 2
                radius: unit * 0.8
            }
        }
    ]

    transitions: Transition {
        from: "*"
        to: "*"
        NumberAnimation {
            properties: "width,height,radius"
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutCubic
        }
    }
    // ================= 内部内容包装器 =================
    component IslandContent: Item {
	    focus: true
        property bool active: false
        anchors.fill: parent
        opacity: active ? 1 : 0
        scale: active ? 1 : 0.95
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Kirigami.Units.veryLongDuration
                easing.type: Easing.OutCubic
            }
        }
    }
    TapHandler {
	    acceptedButtons: Qt.MiddleButton
	    onTapped: {
		    if (currentPlayer) root.showLyrics = !root.showLyrics;
		    if (root.showLyrics) root.expanded = false;
	    }
    }
    TapHandler {
	    acceptedButtons: Qt.LeftButton
	    onTapped: {
		    if (root.showDashboard) root.showDashboard = false;
		    else if (root.showLyrics) root.showLyrics = false;
		    else root.expanded = !root.expanded;
	    }
    }
    Item {
        id: contentContainer
        anchors.fill: parent
        clip: true
        focus: true
        IslandContent {
            active: root.state === "COLLAPSED"
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            ClockContent {
                anchors.fill: parent
            }
        }

        IslandContent {
            active: root.state === "LYRICS"
            LyricsContent {
                anchors.fill: parent
            }
        }
        IslandContent {
		active: root.state === "AUTH"
		PolkitAuthPopupManager{
			focus: true
		anchors.fill: parent
			anchors.margins: 20
		}
	}
        IslandContent {
            active: root.state === "EXPANDED"
            MediaContent {
                anchors.fill: parent
                anchors.margins: 20
            }
        }
        IslandContent {
            active: root.state === "DASHBOARD"
            DashboardContent {
                anchors.fill: parent
            }
        }
    }

    // ================= 逻辑与交互 (保持原功能) =================
    IpcHandler {
        target: "island"
        function dashboard() {
            root.showDashboard = !root.showDashboard;
            return "DASHBOARD_TOGGLED";
        }
        function wallpaper() {
            root.showWallpaper = !root.showWallpaper;
            return "WALLPAPER_TOGGLED";
        }
        function launcher() {
            root.showLauncher = !root.showLauncher;
            return "LAUNCHER_TOGGLED";
        }
    }
}
