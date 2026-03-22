import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import qs.Services
import qs.config
import qs.Modules.DynamicIsland.ClockContent
import qs.Modules.DynamicIsland.MediaContent
import qs.Modules.DynamicIsland.NotificationContent
import qs.Modules.DynamicIsland.VolumeContent
import qs.Modules.DynamicIsland.LauncherContent
import qs.Modules.DynamicIsland.DashboardContent
import qs.Modules.DynamicIsland.LyricsContent
import org.kde.kirigami as Kirigami
import QtQuick.Effects
Kirigami.ShadowedRectangle {
	id: root
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

	// 简化后的逻辑判定
	property bool isDashboardMode: showDashboard
	property bool isWallpaperMode: !showDashboard
	property bool isLyricsMode: showLyrics && !showDashboard
	property bool isLauncherMode: !showDashboard && !isLyricsMode
	property bool isNotifMode:  NotificationManager.isNotifMode && !expanded && !showDashboard && !isLyricsMode

	// ================= 状态机定义 (MD3 核心) =================
	states: [
		State {
			name: "DASHBOARD"
			when: showDashboard
			PropertyChanges { target: root; width: unit * 45; height: unit * 24; radius: unit * 1.5 }
		},
		State {
			name: "NOTIF"
			when: isNotifMode
			PropertyChanges { target: root; width: unit * 22; height: unit * 5; radius: unit * 1.2 }
		},
		State {
			name: "EXPANDED"
			when: expanded
			PropertyChanges { target: root; width: unit * 24; height: unit * 10; radius: unit * 1.5 }
		},
		State {
			name: "LYRICS"
			when: showLyrics && !showDashboard
			PropertyChanges { target: root; width: unit * 28; height: unit * 2.5; radius: unit }
		},
		State {
			name: "COLLAPSED"
			when: true
			PropertyChanges { target: root; width: unit * 12; height: unit * 2; radius: unit * 0.8 }
		}
	]

	transitions: Transition {
		from: "*"; to: "*"
		NumberAnimation {
			properties: "width,height,radius"
			duration: Kirigami.Units.longDuration
			easing.type: Easing.OutCubic
		}
	}
	// ================= 内部内容包装器 =================
	component IslandContent : Item {
		property bool active: false
		anchors.fill: parent
		opacity: active ? 1 : 0
		scale: active ? 1 : 0.95
		visible: opacity > 0

		Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
		Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
	}
	MouseArea {
		anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !isNotifMode; acceptedButtons: Qt.LeftButton | Qt.MiddleButton
		onClicked: (mouse) => {
			if (mouse.button === Qt.MiddleButton) {
				if (currentPlayer) root.showLyrics = !root.showLyrics; if (root.showLyrics) root.expanded = false;
			} else {
				if (root.showDashboard) root.showDashboard = false; else if (root.showLyrics) root.showLyrics = false; else root.expanded = !root.expanded;
			}
		}
	}
	Item {
		id: contentContainer
		anchors.fill: parent
		clip: true

		IslandContent {
			active: root.state === "COLLAPSED"
			anchors.leftMargin: Kirigami.Units.largeSpacing
			anchors.rightMargin: Kirigami.Units.largeSpacing
			ClockContent { anchors.fill: parent; player: root.currentPlayer }
		}

		IslandContent {
			active: root.state === "NOTIF"
		NotificationContent { anchors.fill: parent; anchors.margins: Kirigami.Units.mediumSpacing }

		}

		IslandContent {
			active: root.state === "LYRICS"
			LyricsContent { anchors.fill: parent; player: root.currentPlayer; active: true }
		}

		IslandContent {
			active: root.state === "EXPANDED"
			MediaContent { anchors.fill: parent; anchors.margins: 20; player: root.currentPlayer }
		}
		IslandContent {
			active: root.state === "DASHBOARD"
			DashboardContent { anchors.fill: parent }
		}
	}

	// ================= 逻辑与交互 (保持原功能) =================
	IpcHandler {
		target: "island"
		function dashboard() { root.showDashboard = !root.showDashboard; return "DASHBOARD_TOGGLED"; }
		function wallpaper() { root.showWallpaper = !root.showWallpaper; return "WALLPAPER_TOGGLED"; }
		function launcher() { root.showLauncher = !root.showLauncher; return "LAUNCHER_TOGGLED"; }
	}

	property var currentPlayer: null
	Timer {
		id: stickyTimer
		interval: 500; repeat: true; running: Mpris.players.values.length > 0; triggeredOnStart: true
		onTriggered: {
			let players = Mpris.players.values;
			if (players.length === 0) { root.currentPlayer = null; return; }
			let playing = players.find(p => p.isPlaying);
			root.currentPlayer = playing ? playing : players[0];
		}
	}

}
