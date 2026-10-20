import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Services
import qs.Config
import qs.Widget
import qs.Modules.Bar.common
import org.kde.kirigami as Kirigami

// 顶栏网络入口。内容是「连接状态图标 + 每个网卡一行」，比固定 icon/text
// 复杂，所以走 BarButton 的 content 通道；胶囊外观和交互仍由 BarButton 统一。
BarButton {
    id: root

    checked: wifiPanel.visible
    spacing: Kirigami.Units.mediumSpacing

    // 已连接的网卡数量（0 时只显示「未连接」占位）
    readonly property int connectedCount: Array.from(Networking.devices).filter(d => d && d.connected).length

    onClicked: wifiPanel.visible = !wifiPanel.visible

    content: Component {
        RowLayout {
            spacing: Kirigami.Units.mediumSpacing

            Kirigami.Icon {
                visible: root.connectedCount === 0
                source: "network-wired-disconnected-symbolic"
                implicitWidth: Math.round(Kirigami.Units.gridUnit * 0.85)
                implicitHeight: implicitWidth
                color: Kirigami.Theme.negativeTextColor
                Layout.alignment: Qt.AlignVCenter
            }

            // 只在网络不健康时冒出来提示
            Kirigami.Icon {
                visible: Networking.connectivity !== NetworkConnectivity.Full
                implicitWidth: Math.round(Kirigami.Units.gridUnit * 0.8)
                implicitHeight: implicitWidth
                Layout.alignment: Qt.AlignVCenter

                source: {
                    switch (Networking.connectivity) {
                    case NetworkConnectivity.Portal:
                        return "network-error-symbolic";
                    case NetworkConnectivity.Limited:
                        return "network-limited";
                    case NetworkConnectivity.None:
                        return "network-offline-symbolic";
                    case NetworkConnectivity.Unknown:
                        return "network-no-route-symbolic";
                    }
                }

                color: (Networking.connectivity === NetworkConnectivity.Portal || Networking.connectivity === NetworkConnectivity.Limited) ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.negativeTextColor
            }

            Repeater {
                // 只列已连接的网卡（原来把断开的也画出来，占宽度还容易看错）
                model: Array.from(Networking.devices).filter(d => d && d.connected)

                delegate: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Layout.alignment: Qt.AlignVCenter

                    readonly property bool isOnline: modelData.connected && Networking.connectivity === NetworkConnectivity.Full
                    readonly property color statusColor: isOnline ? Kirigami.Theme.linkColor : Kirigami.Theme.negativeTextColor

                    Kirigami.Icon {
                        source: DeviceType.Wifi === modelData.type ? "network-wireless" : "network-wired"
                        implicitWidth: Kirigami.Units.gridUnit
                        implicitHeight: Kirigami.Units.gridUnit
                        color: parent.statusColor
                    }

                    Label {
                        text: {
                            if (!modelData || !modelData.networks)
                                return "未连接";
                            const connectedList = Array.from(modelData.networks.values || []).filter(net => net.connected);
                            connectedList.sort((a, b) => b.signalStrength - a.signalStrength);

                            let name = connectedList[0]?.name ?? "未连接";

                            // 如果有 Portal，在名字后面加个提醒
                            if (modelData.connected && Networking.connectivity === NetworkConnectivity.Portal)
                                return name + " (需登录)";
                            return name;
                        }
                        font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.8)
                        font.weight: Font.DemiBold
                        color: parent.statusColor
                    }
                }
            }
        }
    }

    NetworkWidget {
        id: wifiPanel
        anchorItem: root
        visible: false
    }

    // IPC 控制面板（qs ipc call net toggle / open / close）
    IpcHandler {
        target: "net"

        function toggle() {
            wifiPanel.visible = !wifiPanel.visible;
        }

        function open() {
            wifiPanel.visible = true;
        }

        function close() {
            wifiPanel.visible = false;
        }
    }
}