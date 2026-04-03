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
        BackgroundEffect.blurRegion: Region {
		item: parent.contentItem
	}
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
		BackgroundEffect.blurRegion: Region {
			item: contentItem
		}
		anchor.margins.top:Math.round(Sizes.barHeight/3+Kirigami.Units.smallSpacing)

		visible: true
		mask: null
		color: "transparent"
		implicitWidth: island.width + Kirigami.Units.smallSpacing
		implicitHeight: Math.max(Sizes.barHeight, island.height )
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
                bottom:parent.bottom
            }
            height: barWindow.barHeight

            // --- 左侧组件 ---
            RowLayout {
		    anchors.left: parent.left
		    anchors.top:parent.top
		    anchors.verticalCenter: parent.verticalCenter
		    anchors.leftMargin: Kirigami.Units.largeSpacing
		    spacing: Kirigami.Units.smallSpacing
                Cava {}
            }
            // --- 中间：灵动岛 ---
            RowLayout {
		    anchors.horizontalCenter: parent.horizontalCenter
		    anchors.top:parent.top
		    spacing: Kirigami.Units.mediumSpacing
		    Workspaces {}

	    }
            RowLayout {
                // 钉在右边
		    anchors.top:parent.top
		    anchors.right: parent.right
		    anchors.verticalCenter: parent.verticalCenter
		    anchors.rightMargin: Kirigami.Units.largeSpacing
		    spacing: Kirigami.Units.smallSpacing
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
