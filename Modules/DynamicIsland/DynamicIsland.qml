import QtQuick
import QtQuick.Effects
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

Rectangle {
	id: root
	anchors.horizontalCenter: parent.horizontalCenter
	color: "#cc" + Colorscheme.background.toString().substring(1)
	// ================= MD3 视觉优化 =================
	layer.enabled: true
	layer.effect: MultiEffect {
		antialiasing: true
		shadowEnabled: true
		shadowColor: "#40000000"
		shadowBlur: 0.8
	}

	// ================= 状态控制变量 =================
	property bool showDashboard: false
	property bool expanded: false
	property bool showLyrics: currentPlayer && currentPlayer.isPlaying

	// 简化后的逻辑判定
	property bool isDashboardMode: showDashboard
	property bool isWallpaperMode: !showDashboard
	property bool isLyricsMode: showLyrics && !showDashboard && !showWallpaper
	property bool isLauncherMode: !showDashboard && !isLyricsMode
	property bool isVolumeMode: showVolume && !expanded && !showDashboard && !isLyricsMode
	property bool isNotifMode:  NotificationManager.isNotifMode && !expanded && !showDashboard && !isLyricsMode

	// ================= 状态机定义 (MD3 核心) =================
	states: [
		State {
			name: "DASHBOARD"
			when: showDashboard
			PropertyChanges { target: root; width: 810; height: 420; radius: 28 }
		},
		State {
			name: "WALLPAPER"
			when: showWallpaper
			PropertyChanges { target: root; width: 810; height: 180; radius: 28 }
		},
		State {
			name: "LAUNCHER"
			when: showLauncher
			PropertyChanges { target: root; width: 400; height: 420; radius: 28 }
		},
		State {
			name: "NOTIF"
			when: isNotifMode
			PropertyChanges { target: root; width: 380; height: 90; radius: 24 }
		},
		State {
			name: "EXPANDED"
			when: expanded
			PropertyChanges { target: root; width: 420; height: 180; radius: 28 }
		},
		State {
			name: "LYRICS"
			when: isLyricsMode
			PropertyChanges { target: root; width: 480; height: 42; radius: 20 }
		},
		State {
			name: "COLLAPSED"
			when: true
			PropertyChanges { target: root; width: 220; height: 32; radius: 16 }
		}
	]

	// ================= MD3 过渡动画 (修复闪烁) =================
	transitions: Transition {
		from: "*"; to: "*"
		ParallelAnimation {
			// 使用标准的 OutCubic 替代 OutBack，解决边界裁剪闪烁
			NumberAnimation {
				properties: "width,height,radius"
				duration: 400
				easing.type: Easing.OutCubic
			}

			// 动画执行期间临时关闭 clip，确保回弹或变形过程边缘平滑 [cite: 21]
			PropertyAction { target: root; property: "clip"; value: false }
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
				if (root.showDashboard) root.showDashboard = false; else
					root.showLyrics = !root.showLyrics; if (root.showLyrics) root.expanded = false;
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
			ClockContent { anchors.fill: parent; player: root.currentPlayer }
		}

		IslandContent {
			active: root.state === "NOTIF"
			NotificationContent { anchors.fill: parent; anchors.margins: 10 }
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
