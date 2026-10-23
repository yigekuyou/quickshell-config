import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Modules.Bar.SettingsButton
import qs.Modules.Bar.Workspaces
import qs.Modules.Bar.AppMenu
import qs.Modules.Bar.Clock
import qs.Modules.Bar.Tray
import qs.Modules.Bar.Cava
import qs.Modules.Bar.ClipboardManager
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
		item: barWindow.contentItem
	}
        required property var modelData
        screen: modelData
        anchors {
            left: true
            top: true
            right: true
        }
        color: "transparent"
        implicitHeight: Sizes.barHeight + Kirigami.Units.smallSpacing
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
		// 岛顶边直接贴齐锚矩形顶边（= barWindow 顶边 = 屏幕最顶层），
		// 不再往下留间距
		anchor.margins.top: 0

		// 全屏（游戏/视频/演示）时不显示灵动岛，别挡画面
		visible: !FullscreenState.covers(modelData)
		// 只让“岛”本身可点击：弹窗其余透明区域把点击透传给下面的栏内容
		// （否则居中的弹窗会盖住 Workspaces，点不动）
		mask: Region {
			item: island
		}
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

            // --- 左侧组件 ---
            RowLayout {
		    anchors.left: parent.left
		    anchors.verticalCenter: parent.verticalCenter
		    anchors.leftMargin: Math.round(Kirigami.Units.smallSpacing * 2)
		    spacing: Sizes.secGap("left")
		    SettingsButton {}
    		    Workspaces {}
                Cava {}
                AppMenuBar {}
                ClipboardStatus {}
            }
            // --- 中间：灵动岛 ---
            RowLayout {
		    anchors.horizontalCenter: parent.horizontalCenter
		    anchors.verticalCenter: parent.verticalCenter
		    spacing: Sizes.secGap("center")

	    }
            RowLayout {
                // 钉在右边
		    anchors.right: parent.right
		    anchors.verticalCenter: parent.verticalCenter
		    anchors.rightMargin: Kirigami.Units.largeSpacing
		    spacing: Sizes.secGap("right")
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
                PowerButton {
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}
