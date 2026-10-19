import Quickshell
import Quickshell.Wayland
import org.kde.kirigami as Kirigami
import qs.Modules.Launcher
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Services

Variants {
	model: Quickshell.screens
	PanelWindow {
		id: panelWindow
		WlrLayershell.namespace: "panelWindow"
		WlrLayershell.layer: WlrLayer.Top
		WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
		exclusionMode: ExclusionMode.Ignore
		required property var modelData
		property bool isExpanded: true
		property int triggerHeight: 1
		screen: modelData
		BackgroundEffect.blurRegion: Region {
			item: panelWindow.contentItem
		}
		Timer {
			id: hideTimer
			interval: 5000 // 鼠标离开五秒后收起
			// 启动器打开时保持展开，否则鼠标一离开面板就缩成一条线
			running: panelWindow.isExpanded && !launcher.isOpen
			onTriggered: panelWindow.isExpanded = false
		}
		anchors {
			bottom: true
		}
		margins {
			bottom: isExpanded ? Kirigami.Units.smallSpacing : 0
		}
		color: "transparent"
		implicitWidth: layout.implicitWidth + Kirigami.Units.largeSpacing * 2
		implicitHeight: isExpanded ? Math.max(Sizes.barHeight, layout.implicitHeight + Kirigami.Units.smallSpacing * 2) : triggerHeight
		Behavior on implicitHeight {
			SequentialAnimation {
				PauseAnimation {
					duration: isExpanded ? 0 : 10
				}
				NumberAnimation {
					duration: 250
					easing.type: Easing.OutCubic
				}
			}
		}

		LauncherManager {
			id: launcher

			// 全局快捷键 quickshell:launcher-toggle（Services/Shortcuts.qml 注册）。
			// 每块屏都有一个 LauncherManager，只让主屏那个响应，
			// 不然一次快捷键会在每块屏各开一个启动器窗口
			Connections {
				target: Shortcuts
				enabled: panelWindow.screen === Quickshell.screens[0]

				function onLauncherToggleRequested() {
					launcher.toggle();
				}
			}
		}
		MouseArea {
			anchors.fill: parent
			hoverEnabled: true

			// 核心逻辑：进入展开，离开触发定时器
			onEntered: {
				hideTimer.stop();
				panelWindow.isExpanded = true;
			}
			onExited: hideTimer.start()
		}
		Kirigami.ShadowedRectangle {
			anchors.fill: parent
			color: Kirigami.Theme.backgroundColor
			radius: Kirigami.Units.smallSpacing
			border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
			border.width: isExpanded ? 1 : 0
			shadow.size: isExpanded ? Kirigami.Units.smallSpacing : 0
			shadow.color: Qt.rgba(0, 0, 0, 0.3)
			shadow.yOffset: 2
			RowLayout {
				id: layout
				anchors.centerIn: parent
				spacing: Kirigami.Units.smallSpacing
				// 启动器按钮：悬停/打开时有一层高亮底色
				Item {
					id: menuButton
					Layout.alignment: Qt.AlignVCenter
					// 和右侧托盘按钮同高，面板才会保持一条紧凑的圆角条
					implicitWidth: Kirigami.Units.gridUnit * 1.35
					implicitHeight: Kirigami.Units.gridUnit * 1.35

					Rectangle {
						anchors.fill: parent
						radius: Kirigami.Units.smallSpacing
						color: menuHover.hovered || launcher.isOpen ? Qt.alpha(Kirigami.Theme.highlightColor, 0.28) : "transparent"

						Behavior on color {
							ColorAnimation {
								duration: Kirigami.Units.shortDuration
							}
						}
					}

					Kirigami.Icon {
						anchors.centerIn: parent
						width: Kirigami.Units.gridUnit * 0.95
						height: width
						source: "start-here"
						opacity: menuHover.hovered || launcher.isOpen ? 1.0 : 0.85
					}

					HoverHandler {
						id: menuHover
						cursorShape: Qt.PointingHandCursor
					}

					TapHandler {
						acceptedButtons: Qt.LeftButton
						onTapped: {
							hideTimer.stop();
							launcher.toggle();
						}
					}

				}

				Kirigami.Separator {
					Layout.alignment: Qt.AlignVCenter
					Layout.fillHeight: true
					Layout.topMargin: Kirigami.Units.smallSpacing
					Layout.bottomMargin: Kirigami.Units.smallSpacing
					visible: TaskbarApps.apps.length > 0
					opacity: 0.5
				}

				Panelapp {
					Layout.alignment: Qt.AlignVCenter
				}
			}
		}
	}
}
