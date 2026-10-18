pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Config
import qs.Services
import qs.Widget.common
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

SlideWindow {
    id: bluetooth
    title: "蓝牙配置"
    icon: "preferences-system-bluetooth"

    readonly property var adapter: Bluetooth.defaultAdapter

    // 与 NetworkWidget 相同：列表项用 FormCard + AbstractFormDelegate 保持 KDE 外观，
    // 不使用 FormButtonDelegate（它内部的换行 Label 会在弹窗首次显示时触发布局死循环）。
    readonly property var devices: {
        if (!adapter || !adapter.devices)
            return [];
        const list = [...adapter.devices.values].filter(item => item.deviceName !== "");
        list.sort((a, b) => {
            if (a.paired === b.paired)
                return a.deviceName.localeCompare(b.deviceName);
            return a.paired ? -1 : 1;
        });
        return list;
    }

    headerTools: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        ToolButton {
            id: discoverableButton
            action: Kirigami.Action {
                icon.name: (adapter && adapter.discoverable) ? "visibility" : "hint"
                text: (adapter && adapter.discoverable) ? qsTr("可被发现") : qsTr("隐藏中")
                checked: adapter ? adapter.discoverable : false
                checkable: true
                enabled: adapter !== null
                onTriggered: {
                    if (adapter)
                        adapter.discoverable = !adapter.discoverable;
                }
            }
            display: AbstractButton.IconOnly
            ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
            ToolTip.visible: hovered
            ToolTip.text: action.text
            contentItem: Kirigami.Icon {
                source: discoverableButton.action.icon.name
                color: discoverableButton.checked ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
            }
        }

        ToolButton {
            id: boolscan
            action: Kirigami.Action {
                id: scanAction
                icon.name: (adapter && adapter.discovering) ? "view-refresh" : "edit-find"
                text: (adapter && adapter.discovering) ? qsTr("正在扫描...") : qsTr("开始扫描")
                enabled: adapter !== null
                onTriggered: {
                    if (adapter)
                        adapter.discovering = !adapter.discovering;
                }
            }
            RotationAnimation on rotation {
                running: adapter ? adapter.discovering : false
                from: 0
                to: 360
                loops: Animation.Infinite
                duration: 1000
                onRunningChanged: if (!running) boolscan.rotation = 0
            }
            flat: true
            display: AbstractButton.IconOnly
            ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
            ToolTip.visible: hovered
            ToolTip.text: scanAction.text
        }

        Kirigami.Separator {
            Layout.fillHeight: true
        }

        Switch {
            id: blueSwitch
            checked: adapter ? adapter.enabled : false
            enabled: adapter !== null
            onToggled: if (adapter) adapter.enabled = checked
            ToolTip.visible: hovered
            ToolTip.text: adapter === null ? qsTr("没有蓝牙适配器") : (checked ? qsTr("蓝牙 已开启") : qsTr("蓝牙 已关闭"))
        }
    }

    Repeater {
        model: bluetooth.devices

        FormCard.FormCard {
            id: deviceCard
            Layout.fillWidth: true
            property var deviceData: modelData

            FormCard.AbstractFormDelegate {
                id: deviceRow
                Layout.fillWidth: true

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: "bluetooth"
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: implicitWidth
                        color: (deviceCard.deviceData && deviceCard.deviceData.connected) ? Kirigami.Theme.linkColor : Kirigami.Theme.textColor
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            Layout.fillWidth: true
                            text: (deviceCard.deviceData && deviceCard.deviceData.deviceName) ? deviceCard.deviceData.deviceName : qsTr("未知设备")
                            elide: Text.ElideRight
                            font.bold: !!(deviceCard.deviceData && deviceCard.deviceData.connected)
                        }
                        Label {
                            Layout.fillWidth: true
                            text: (deviceCard.deviceData ? deviceCard.deviceData.address : "")
                                + (deviceCard.deviceData && deviceCard.deviceData.paired ? " · " + qsTr("已配对") : "")
                            elide: Text.ElideRight
                            font: Kirigami.Theme.smallFont
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }

                    Button {
                        display: AbstractButton.TextOnly
                        text: (deviceCard.deviceData && deviceCard.deviceData.connected) ? qsTr("断开")
                            : (deviceCard.deviceData && deviceCard.deviceData.paired ? qsTr("连接") : qsTr("配对"))
                        palette.buttonText: (deviceCard.deviceData && deviceCard.deviceData.connected)
                            ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
                        onClicked: {
                            if (!deviceCard.deviceData)
                                return;
                            if (deviceCard.deviceData.connected)
                                deviceCard.deviceData.disconnect();
                            else if (deviceCard.deviceData.paired)
                                deviceCard.deviceData.connect();
                            else
                                deviceCard.deviceData.pair();
                        }
                    }

                    ToolButton {
                        visible: !!(deviceCard.deviceData && deviceCard.deviceData.paired)
                        icon.name: "edit-delete"
                        display: AbstractButton.IconOnly
                        ToolTip.text: qsTr("移除设备")
                        ToolTip.visible: hovered
                        onClicked: if (deviceCard.deviceData) deviceCard.deviceData.forget()
                    }
                }
            }
        }
    }
}
