import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Services
import qs.Config
import Quickshell.Networking
import qs.Widget
import org.kde.kirigami as Kirigami
// 或者如果它就在旁边，直接用 import "." 即可

Kirigami.ShadowedRectangle {
    id: root
    implicitHeight: Sizes.barHeight
    implicitWidth: layout.implicitWidth + Kirigami.Units.largeSpacing * 2

    // 使用 Kirigami 主题色，带透明度
    color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.5)
    radius: Sizes.cornerRadius
    shadow.color: Qt.rgba(0, 0, 0, 0.2)
    shadow.size: 10
    shadow.yOffset: 2
    border.width: 1
    border.color: Qt.alpha(Kirigami.Theme.dividerColor, 0.3)
    // --- 【2】 实例化网络面板 ---
    NetworkWidget {
        id: wifiPanel
        // 默认是关闭的
        visible: false

        // 如果你想让面板的配色跟随全局 Colorscheme，可以在这里覆盖内部属性
        // (前提是 NetworkWidget 内部没有把这些属性写死，而是开放了别名或者属性)
        // 目前你的 NetworkWidget 是自包含配色的，直接用即可。
    }

    // --- 交互区域 ---
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        // --- 【3】 修改点击逻辑 ---
        onClicked: {
            // 切换面板的开关状态
            wifiPanel.visible = !wifiPanel.visible;
        }
    }
        RowLayout {
		id: layout
            anchors.centerIn: parent
            spacing: Kirigami.Units.mediumSpacing

            Repeater {
                model: Networking.devices
                delegate: RowLayout {
			spacing: Kirigami.Units.smallSpacing
			id: innerRow
			readonly property color statusColor: modelData.connected
			? Kirigami.Theme.linkColor
			: Kirigami.Theme.negativeTextColor

                        Kirigami.Icon {
                            source: (DeviceType.Wifi === modelData.type) ?"network-wireless" : "network-wired"
			    implicitWidth: Kirigami.Units.gridUnit
			    implicitHeight: Kirigami.Units.gridUnit
			    color: statusColor                        }
                        Label {
				text: {
					if (modelData.type !== DeviceType.Wifi) return "Ethernet";
					const connectedList = Array.from(modelData.networks.values || [])
					.filter(net => net.connected);
					connectedList.sort((a, b) => b.signalStrength - a.signalStrength);
					return connectedList[0]?.name ?? "未连接";
				}
                            font.bold: true
                            font.pixelSize: Kirigami.Units.gridUnit * 0.8
                            color: statusColor
			}
                    }
                }
        }
    }
