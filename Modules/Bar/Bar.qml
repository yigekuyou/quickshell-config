import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Modules.Bar.Workspaces
import qs.Modules.Bar.Clock
import qs.Modules.Bar.Tray
import qs.Modules.Bar.Cava
import qs.Modules.Bar.Network
import qs.Modules.Bar.Bluetooth
import qs.Modules.Bar.Volume
import qs.Modules.Bar.PowerButton
import qs.Modules.Bar.PowerProfile
import qs.Modules.Bar.SysMonitor
import qs.Modules.Bar.NotificationButton
import qs.Modules.Bar.DayNightSwitch
import qs.Modules.DynamicIsland
import qs.config

Variants {
    model: Quickshell.screens
    PanelWindow {
        id: barWindow
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: (island.showDashboard)
	? WlrKeyboardFocus.Exclusive
	: WlrKeyboardFocus.None
        required property var modelData
        screen: modelData
        anchors {
            left: true
            top: true
            right: true
        }
        color: "transparent"
        implicitHeight: Sizes.barHeight
        PopupWindow {
		anchor.window: barWindow
		anchor.edges: Edges.Top
		anchor.gravity: Edges.Bottom
		anchor.rect.x: Math.round(parentWindow.width / 2)
		anchor.rect.y: Math.round(parentWindow.height - parentWindow.extraTopMargin)
		visible: true
		implicitWidth: island.width + 10
		implicitHeight: Math.max(Sizes.barHeight, island.height + 15)
		color: "transparent"
		Item {
			transformOrigin: Item.Center
			anchors { top: parent.top; left: parent.left; right: parent.right }
			DynamicIsland {
				id: island
				anchors.horizontalCenter: parent.horizontalCenter
				anchors.top: parent.top
				anchors.topMargin: 5

			}}

	}
        Item {
            id: barContent

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: barWindow.barHeight

            // --- 左侧组件 ---
            RowLayout {
                anchors {
                    left: parent.left
                    leftMargin: 10
                }
                spacing: 10
                Workspaces {}
                Cava {}
            }

            // --- 中间：灵动岛 ---

            RowLayout {
                // 钉在右边
                anchors {
                    right: parent.right
                    rightMargin: 10
                }
                spacing: 10

                SysMonitor {
                    Layout.alignment: Qt.AlignVCenter
                }
                Tray {}
                PowerProfile {
                    Layout.alignment: Qt.AlignVCenter
                }
                Bluetooth{}
                Network {}
                Volume {}
                NotificationButton {
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}
