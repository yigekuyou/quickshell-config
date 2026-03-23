import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import org.kde.kirigami as Kirigami
import QtQuick.Controls
import qs.config
import qs.Services
Variants {
	model: Quickshell.screens
	PanelWindow {
		id: panelWindow
		WlrLayershell.namespace:"panelWindow"
		WlrLayershell.layer: WlrLayer.Top
		WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
		exclusionMode: ExclusionMode.Ignore
		required property var modelData
		screen: modelData
		anchors {
			bottom: true
		}
		color: "transparent"
		implicitWidth: layout.implicitWidth + 32
		implicitHeight: Kirigami.Units.iconSizes.medium*1.3
		Kirigami.ShadowedRectangle {
			anchors {
				fill: parent
			}
			radius: Kirigami.Units.gridUnit / 2
			color: Kirigami.Theme.backgroundColor
			shadow.color: Qt.rgba(0, 0, 0, 0.2)
			shadow.size: Kirigami.Units.smallSpacing
			shadow.yOffset: 2


			RowLayout {
				id:layout
				anchors.fill: parent
				anchors.leftMargin: Kirigami.Units.largeSpacing
				anchors.rightMargin: Kirigami.Units.largeSpacing
				spacing: Kirigami.Units.smallSpacing
				Repeater {
					model: TaskbarApps.apps

					delegate: Kirigami.AbstractCard {
						id: appDelegate
						implicitWidth: Kirigami.Units.gridUnit * 2
						Layout.fillHeight: true

						// 移除卡片默认边距和背景，手动控制
						showClickFeedback: true
						highlighted: hovered
						ToolTip.delay: Kirigami.Units.toolTipDelay
						background: Rectangle {
							color: appDelegate.hovered ? Kirigami.Theme.hoverColor : "transparent"
							// 运行中状态指示器
						}

						contentItem: Kirigami.Icon {
							source: modelData.appId
							implicitWidth: Kirigami.Units.iconSizes.medium
							implicitHeight: Kirigami.Units.iconSizes.medium
							opacity: modelData.toplevels.length > 0 ? 1.0 : 0.6 // 未运行时图标半透明
							scale: appDelegate.pressed ? 0.9 : (appDelegate.hovered ? 1.1 : 1.0)
							Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }
						}

						// 交互逻辑
						ToolTip.visible: appDelegate.hovered
						ToolTip.text: modelData.appId

						onClicked: {
							if (modelData.toplevels.length > 0) {
								// 取得当前窗口实例
								let top = modelData.toplevels[0];

								if (top.active) {
									// 如果已经是当前窗口，则最小化
									top.minimized = true;
								} else {
									// 否则，激活它
									top.activate();
									// 如果是最小化状态，取消最小化
									if (top.minimized) top.minimized = false;
								}
						}
					}
				}
				}
				// 撑开右侧空间
				Item { Layout.fillWidth: true }
			}
		}
	}
}
