import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Config
import qs.Widget.common
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

SlideWindow {
    id: root
    title: "网络配置"
    icon: "network-wireless"
    property string currentTab: "wifi"

    property var wifiDev: {
        const devs = Networking.devices.values || [];
        return [...devs].find(d => d.type === DeviceType.Wifi) ?? null;
    }
    property var wiredDev: {
        const devs = Networking.devices.values || [];
        return [...devs].find(d => d.type === DeviceType.Wired) ?? null;
    }

    // 排序后的列表。列表项使用 FormCard + AbstractFormDelegate（保持 KDE 外观），
    // 不要直接用 FormButtonDelegate：它内部的 Label 使用 width: parent.width +
    // wrapMode: Text.Wrap，弹窗首次显示、窗口尺寸从 0 变成实际值时会形成
    // “宽度 -> 换行 -> 隐式高度 -> 布局 -> 宽度”的循环，主线程会被钉在 100%。
    readonly property var wifiNetworks: {
        if (!wifiDev || !wifiDev.networks)
            return [];
        const list = [...wifiDev.networks.values];
        list.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
        return list;
    }

    readonly property var wiredNetworks: {
        if (!wiredDev || !wiredDev.networks)
            return [];
        const list = [...wiredDev.networks.values];
        list.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return (b.device?.linkSpeed ?? 0) - (a.device?.linkSpeed ?? 0);
        });
        return list;
    }

    function securityName(network) {
        if (!network || network.security === undefined)
            return "";
        return WifiSecurityType.toString(network.security);
    }

    headerTools: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        ToolButton {
            id: boolscan
            action: Kirigami.Action {
                icon.name: (wifiDev && wifiDev.scannerEnabled) ? "view-refresh" : "edit-find"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                checkable: true
                onTriggered: {
                    if (wifiDev)
                        wifiDev.scannerEnabled = !wifiDev.scannerEnabled;
                }
            }
            RotationAnimation on rotation {
                running: wifiDev ? wifiDev.scannerEnabled : false
                from: 0
                to: 360
                loops: Animation.Infinite
                duration: 1000
                onRunningChanged: if (!running)
                    boolscan.rotation = 0
            }
            ToolTip.visible: hovered
            ToolTip.text: (wifiDev && wifiDev.scannerEnabled) ? qsTr("正在扫描...") : qsTr("开始扫描")
        }

        Kirigami.Separator {
            Layout.fillHeight: true
        }

        Switch {
            id: wifiSwitch
            enabled: Networking.wifiHardwareEnabled
            checked: Networking.wifiEnabled && Networking.wifiHardwareEnabled
            onToggled: Networking.wifiEnabled = checked
            ToolTip.visible: hovered
            ToolTip.text: !enabled ? qsTr("硬件已禁用") : (checked ? qsTr("WiFi 已开启") : qsTr("WiFi 已关闭"))
        }
    }

    Kirigami.NavigationTabBar {
        Layout.fillWidth: true

        actions: [
            Kirigami.Action {
                text: "Wi-Fi"
                icon.name: "network-wireless"
                checked: root.currentTab === "wifi"
                onTriggered: root.currentTab = "wifi"
            },
            Kirigami.Action {
                text: "以太网"
                icon.name: "network-wired"
                checked: root.currentTab === "wired"
                onTriggered: root.currentTab = "wired"
            }
        ]
    }

    // ==================== Wi-Fi 列表（KDE FormCard 风格） ====================
    Repeater {
        model: root.wifiNetworks

        FormCard.FormCard {
            id: wifiCard
            Layout.fillWidth: true
            // Repeater 注入的 modelData；不要在被嵌套的 AbstractFormDelegate 上
            // 声明 required property modelData（只有 delegate 根对象才会被赋值）。
            property var netData: modelData

            FormCard.AbstractFormDelegate {
                id: wifiRow
                Layout.fillWidth: true
                visible: root.currentTab === "wifi"

                readonly property bool needsPsk: {
                    const s = wifiCard.netData ? wifiCard.netData.security : undefined;
                    return s === WifiSecurityType.WpaPsk || s === WifiSecurityType.Wpa2Psk || s === WifiSecurityType.Sae;
                }
                property bool passwordVisible: false

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: (wifiCard.netData && wifiCard.netData.connected) ? "network-wireless-connected" : "network-wireless"
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: implicitWidth
                        color: (wifiCard.netData && wifiCard.netData.connected) ? Kirigami.Theme.linkColor : Kirigami.Theme.textColor
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Label {
                            Layout.fillWidth: true
                            text: (wifiCard.netData && wifiCard.netData.name) ? wifiCard.netData.name : qsTr("未知网络")
                            elide: Text.ElideRight
                            font.bold: !!(wifiCard.netData && wifiCard.netData.connected)
                        }
                        Label {
                            Layout.fillWidth: true
                            text: root.securityName(wifiCard.netData) + " · "
                                + Math.round((wifiCard.netData ? wifiCard.netData.signalStrength : 0) * 100) + "%"
                            elide: Text.ElideRight
                            font: Kirigami.Theme.smallFont
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }

                    BusyIndicator {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Layout.preferredWidth
                        running: wifiCard.netData ? wifiCard.netData.stateChanging : false
                        visible: running
                    }

                    ToolButton {
                        icon.name: (wifiCard.netData && wifiCard.netData.connected) ? "network-disconnect" : "network-connect"
                        onClicked: {
                            if (!wifiCard.netData)
                                return;
                            if (wifiCard.netData.connected)
                                wifiCard.netData.disconnect();
                            else
                                wifiCard.netData.connect();
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: (wifiCard.netData && wifiCard.netData.connected) ? qsTr("断开连接") : qsTr("连接")
                    }

                    ToolButton {
                        visible: wifiCard.netData ? (wifiCard.netData.known && wifiRow.needsPsk) : false
                        icon.name: "database-change-key"
                        onClicked: wifiRow.passwordVisible = !wifiRow.passwordVisible
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("修改密码")
                    }

                    ToolButton {
                        visible: wifiCard.netData ? wifiCard.netData.known : false
                        icon.name: "edit-delete"
                        onClicked: if (wifiCard.netData) wifiCard.netData.forget()
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("忘记网络")
                    }
                }
            }

            FormCard.FormTextFieldDelegate {
                id: passwordField
                visible: wifiRow.passwordVisible && root.currentTab === "wifi"
                label: qsTr("%1 的密码").arg(wifiCard.netData ? wifiCard.netData.name : "")
                statusMessage: qsTr("连接到 %1").arg(wifiCard.netData ? wifiCard.netData.name : "")
                placeholderText: qsTr("请输入密码")
                echoMode: TextInput.Password
                onAccepted: {
                    if (wifiCard.netData && text.length > 0) {
                        wifiCard.netData.connectWithPsk(text);
                        text = "";
                        statusMessage = "";
                        wifiRow.passwordVisible = false;
                    }
                }
            }

            Connections {
                target: wifiCard.netData
                function onConnectionFailed(reason) {
                    if (reason === ConnectionFailReason.NoSecrets) {
                        wifiRow.passwordVisible = true;
                        passwordField.status = Kirigami.MessageType.Error;
                        passwordField.statusMessage = qsTr("需要密码");
                        passwordField.forceActiveFocus();
                    }
                }
            }
        }
    }

    // ==================== 以太网列表（KDE FormCard 风格） ====================
    Repeater {
        model: root.wiredNetworks

        FormCard.FormCard {
            id: wiredCard
            Layout.fillWidth: true
            property var netData: modelData

            FormCard.AbstractFormDelegate {
                id: wiredRow
                Layout.fillWidth: true
                visible: root.currentTab === "wired"

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: "network-wired"
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: implicitWidth
                        color: (wiredCard.netData && wiredCard.netData.connected) ? Kirigami.Theme.linkColor : Kirigami.Theme.textColor
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            Layout.fillWidth: true
                            text: (wiredCard.netData && wiredCard.netData.name) ? wiredCard.netData.name : qsTr("未知设备")
                            elide: Text.ElideRight
                            font.bold: true
                        }
                        Label {
                            Layout.fillWidth: true
                            text: (wiredCard.netData && wiredCard.netData.device ? wiredCard.netData.device.linkSpeed : 0) + " " + qsTr("Mbps")
                            elide: Text.ElideRight
                            font: Kirigami.Theme.smallFont
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }
                    BusyIndicator {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Layout.preferredWidth
                        running: wiredCard.netData ? wiredCard.netData.stateChanging : false
                        visible: running
                    }
                    ToolButton {
                        icon.name: (wiredCard.netData && wiredCard.netData.connected) ? "network-disconnect" : "network-connect"
                        onClicked: {
                            if (!wiredCard.netData)
                                return;
                            if (wiredCard.netData.connected)
                                wiredCard.netData.disconnect();
                            else
                                wiredCard.netData.connect();
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: (wiredCard.netData && wiredCard.netData.connected) ? qsTr("断开连接") : qsTr("连接")
                    }
                }
            }
        }
    }

    Kirigami.PlaceholderMessage {
        visible: !Networking.wifiEnabled && root.currentTab === "wifi"
        icon.name: "network-wireless-off"
        text: "Wi-Fi 已关闭"
        explanation: "请在上方开关处开启 Wi-Fi 和扫描可用网络。"
    }
}
