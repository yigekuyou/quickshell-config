pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Widgets
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.config
import qs.Services
import qs.Widget.common
import org.kde.kirigami as Kirigami
import QtQuick.Controls
import org.kde.kirigamiaddons.formcard as FormCard
SlideWindow { //qmllint disable uncreatable-type
    id: bluetooth
    title: "蓝牙配置"
    icon: "preferences-system-bluetooth"
    property list<BluetoothDevice> devices: filterDevices(Bluetooth.defaultAdapter.devices.values) // qmllint disable unresolved-type

    function filterDevices(devices) {
        devices = devices.filter(item => item.deviceName !== "");

        devices = devices.sort((a, b) => {
            if (a.paired === b.paired) {
                return a.deviceName.localeCompare(b.deviceName);
            }
            return a.bool ? -1 : 1;
        });

        return devices;
    }
    headerTools: RowLayout {
        Theme {
            id: headerTheme
        }

        // 刷新按钮
        ToolButton {
		id: discoverableButton
		action: Kirigami.Action {
			// 使用更符合 KDE 规范的图标名
			icon.name: Bluetooth.defaultAdapter.discoverable ? "visibility" : "hint"
			text: Bluetooth.defaultAdapter.discoverable ? qsTr("可被发现") : qsTr("隐藏中")

			// 视觉高亮逻辑
			checked: Bluetooth.defaultAdapter.discoverable
			checkable: true

			onTriggered: {
				Bluetooth.defaultAdapter.discoverable = !Bluetooth.defaultAdapter.discoverable;
			}
		}

		// 2. 样式优化
		// 使用 Kirigami 的显隐逻辑，确保在不同主题下颜色正确
		display: AbstractButton.IconOnly

		// 3. ToolTip 增强
		ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
		ToolTip.visible: hovered
		ToolTip.text: action.text

		// 4. 背景与颜色微调
		contentItem: Kirigami.Icon {
			source: discoverableButton.action.icon.name
			// 这种写法比手动判断更符合 Kirigami 的变色机制
			color: discoverableButton.checked ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
		}
	}
	ToolButton {
		id: boolscan

		// 1. 使用 Action 封装逻辑，方便多处复用（如菜单栏或右键菜单）
		action: Kirigami.Action {
			id: scanAction
			icon.name: Bluetooth.defaultAdapter.discovering ? "view-refresh" : "edit-find"
			text: Bluetooth.defaultAdapter.discovering ? qsTr("正在扫描...") : qsTr("开始扫描")

			onTriggered: {
				Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering;
			}
		}
		RotationAnimation on rotation {
			running: Bluetooth.defaultAdapter.discovering
			from: 0
			to: 360
			loops: Animation.Infinite
			duration: 1000
			onRunningChanged: if (!running) boolscan.rotation = 0
		}
		// 3. 交互细节
		flat: true
		display: AbstractButton.IconOnly // 在 Header 中通常只显示图标

		ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
		ToolTip.visible: hovered
		ToolTip.text: scanAction.text
	}
        Kirigami.Separator {
            Layout.fillHeight: true
        }

        Switch {
            id: blueSwitch

            // 状态逻辑
            enabled: true
            checked: Bluetooth.defaultAdapter.enabled

            // Kirigami 样式会自动处理颜色（primary color）和禁用状态的灰色
            // 不需要手动写 Rectangle 的 radius 和 color

            onToggled: {
                Bluetooth.defaultAdapter.enabled = checked;
            }

            ToolTip.visible: hovered
            ToolTip.text: !enabled ? qsTr("硬件已禁用") : (checked ? qsTr("蓝牙 已开启") : qsTr("蓝牙 已关闭"))
        }
    }
    Repeater {
        id: mainColumn
        Layout.fillWidth: true
        Layout.margins: 0
        model: bluetooth.devices
        delegate: FormCard.FormButtonDelegate {
            required property var modelData
            // 1. 设置主标题和副标题
            text: modelData.deviceName || "未知设备"
	    description: modelData.address

	    // 2. 左侧图标
	    icon.name: modelData.icon || "bluetooth"
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            anchors.margins: 0
            contentItem: RowLayout {
                // 1. 图标部分
                Kirigami.Icon {
                    source: modelData.icon|| "bluetooth"
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                }

                // 2. 文本信息部分
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true

                    Kirigami.Heading {
                        text: modelData.deviceName || "未知设备"
                        level: 4
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Label {
                        text: modelData.address
                        font.pixelSize: Kirigami.Units.smallFont.pixelSize
                        opacity: 0.7
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // 3. 状态标签
                Label {
                    text: "已配对"
                    visible: modelData.paired
                    font.pixelSize: Kirigami.Units.smallFont.pixelSize
                    color: Kirigami.Theme.disabledTextColor
                }

                // 4. 操作按钮组
                RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    // 连接/断开按钮
                    Button {
                        display: AbstractButton.TextOnly
                        text: modelData.connected ? "断开" : (modelData.paired ? "连接" : "配对")

                        // 使用 Kirigami 标准的强调色
                        palette.buttonText: modelData.connected ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor

                        onClicked: {
                            if (modelData.connected)
                                modelData.disconnect();
                            else if (modelData.paired)
                                modelData.connect();
                            else
                                modelData.pair();
                        }
                    }

                    // 移除按钮 (仅在已配对时显示)
                    ToolButton {
                        visible: modelData.paired
                        icon.name: "edit-delete" // 使用标准图标
                        display: AbstractButton.IconOnly
                        ToolTip.text: "移除设备"
                        ToolTip.visible: hovered

                        onClicked: modelData.forget()

                        // 红色警示色
                        Kirigami.Theme.colorSet: Kirigami.Theme.View
                        Kirigami.Theme.inherit: false
                    }
                }
            }
        }
    }
}
