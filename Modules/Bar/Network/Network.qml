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
    HoverHandler {
	    cursorShape: Qt.PointingHandCursor
    }
        TapHandler {
	    acceptedButtons: Qt.LeftButton
	    onTapped: {
		    wifiPanel.visible = !wifiPanel.visible;
	    }
    }

        RowLayout {
		id: layout
            anchors.centerIn: parent
            spacing: Kirigami.Units.mediumSpacing
            Kirigami.Icon {
		    id: connectivityIcon
		    visible:(Networking.connectivity !==NetworkConnectivity.Full)
		    implicitWidth: Kirigami.Units.gridUnit * 0.8
		    implicitHeight: Kirigami.Units.gridUnit * 0.8

		    // 根据 Networking.connectivity 切换图标和颜色
		    source: {
			    switch(Networking.connectivity) {
				    case NetworkConnectivity.Portal:  return "network-error-symbolic"; // 需认证
				    case NetworkConnectivity.Limited: return "network-limited";
				    case NetworkConnectivity.None:    return "network-offline-symbolic";
				    case NetworkConnectivity.Unknown: return "network-no-route-symbolic";
			    }
		    }

		    color: {
			    if (Networking.connectivity === NetworkConnectivity.Portal || Networking.connectivity === NetworkConnectivity.Limited)
				    return Kirigami.Theme.neutralTextColor;
			    return Kirigami.Theme.negativeTextColor;
		    }
	    }
            Repeater {
                model: Networking.devices
                delegate: RowLayout {
			spacing: Kirigami.Units.smallSpacing
			id: innerRow
			readonly property bool isOnline: modelData.connected && Networking.connectivity === NetworkConnectivity.Full
			readonly property color statusColor: isOnline
			? Kirigami.Theme.linkColor
			: Kirigami.Theme.negativeTextColor			? Kirigami.Theme.linkColor
			: Kirigami.Theme.negativeTextColor

                        Kirigami.Icon {
                            source: (DeviceType.Wifi === modelData.type) ?"network-wireless" : "network-wired"
			    implicitWidth: Kirigami.Units.gridUnit
			    implicitHeight: Kirigami.Units.gridUnit
			    color: statusColor
			}
                        Label {
				text: {
					if (modelData.type !== DeviceType.Wifi) return "Ethernet";
					const connectedList = Array.from(modelData.networks.values || [])
					.filter(net => net.connected);
					connectedList.sort((a, b) => b.signalStrength - a.signalStrength);

					let name = connectedList[0]?.name ?? "未连接";

					// 如果有 Portal，在名字后面加个提醒
					if (modelData.connected && Networking.connectivity === NetworkConnectivity.Portal) {
						return name + " (需登录)";
					}
					return name;
				}
                            font.bold: true
                            font.pixelSize: Kirigami.Units.gridUnit * 0.8
                            color: statusColor
			}
                    }
                }
        }
    }
