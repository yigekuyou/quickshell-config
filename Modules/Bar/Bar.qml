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
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami

Variants {
    model: Quickshell.screens
    PanelWindow {
        id: barWindow
        WlrLayershell.namespace:"barWindow"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        required property var modelData
        screen: modelData
        anchors {
            left: true
            top: true
            right: true
        }
        color: "transparent"
        implicitHeight: Math.max(Sizes.barHeight+Kirigami.Units.smallSpacing )
	LazyLoader {
		activeAsync:true
        PopupWindow {
		anchor.window: barWindow
		anchor.edges: Edges.Top
		anchor.gravity: Edges.Bottom
		anchor.rect.x: Math.round(modelData.width / 2)
		anchor.rect.y: Math.round(0)

		visible: true
		mask: null
		implicitWidth: island.width + 10
		implicitHeight: Math.max(Sizes.barHeight, island.height )
		color: "transparent"
			DynamicIsland {
				id: island
				anchors.horizontalCenter: parent.horizontalCenter
				anchors.top: parent.top
			}
	}
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
                VolumeBar {}
                NotificationButton {
                    Layout.alignment: Qt.AlignVCenter
                }

            }
        }
    }
}
