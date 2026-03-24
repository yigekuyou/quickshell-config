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
		// 使用 Kirigami 的图标命名规范，或者保留 FontAwesome
		// 建议使用标准图标名 "view-visible" 或 "is-visible"
		icon.name: Bluetooth.defaultAdapter.discoverable ? "view-visible" : "view-hidden"
		icon.color: Bluetooth.defaultAdapter.discoverable ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor

		flat: true

		// 视觉反馈
		highlighted: Bluetooth.defaultAdapter.discoverable

		onClicked: {
			Bluetooth.defaultAdapter.discoverable = !Bluetooth.defaultAdapter.discoverable;
		}

		ToolTip.visible: hovered
		ToolTip.text: Bluetooth.defaultAdapter.discoverable ? qsTr("当前可被发现") : qsTr("设置可被发现")
	}
	ToolButton {
		id: boolscan
		icon.name: Bluetooth.defaultAdapter.discovering ? "view-refresh" : "edit-find"
		icon.width: Kirigami.Units.iconSizes.small
		icon.height: Kirigami.Units.iconSizes.small

		flat: true // 使其看起来像 header 上的工具按钮

		// 旋转动画：Kirigami 环境下依然建议保留动画逻辑
		RotationAnimation on rotation {
			running: Bluetooth.defaultAdapter.discovering
			from: 0
			to: 360
			loops: Animation.Infinite
			duration: 1000
			onRunningChanged: if (!running) boolscan.rotation = 0
		}

		onClicked: {
			Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering
		}

		ToolTip.visible: hovered
		ToolTip.text: Bluetooth.defaultAdapter.discovering ? qsTr("正在扫描...") : qsTr("开始扫描")
	}
	Kirigami.Separator { Layout.fillHeight: true }

        Switch {
		id: blueSwitch

		// 状态逻辑
		enabled: true
		checked: Bluetooth.defaultAdapter.enabled

		// Kirigami 样式会自动处理颜色（primary color）和禁用状态的灰色
		// 不需要手动写 Rectangle 的 radius 和 color

		onToggled: {
			Bluetooth.defaultAdapter.enabled = checked
		}

		ToolTip.visible: hovered
		ToolTip.text: !enabled ? qsTr("硬件已禁用") : (checked ? qsTr("蓝牙 已开启") : qsTr("蓝牙 已关闭"))
	}
    }
    Kirigami.ScrollablePage  {
	    Layout.fillHeight: true
	    implicitHeight: contentHeight
	    leftPadding: 0
	    rightPadding: 0
	    topPadding: 0
	    bottomPadding: 0
	    anchors.margins: 0
	    Repeater {
		    id: mainColumn
		    Layout.fillWidth: true
		    model:bluetooth.devices
		    delegate: Kirigami.AbstractCard {
			    leftPadding: 0
			    rightPadding: 0
			    topPadding: 0
			    bottomPadding: 0
			    anchors.margins: 0
			    contentItem: RowLayout{
				    IconImage {
					    source: Quickshell.iconPath(modelData.icon, "bluetooth")
					    implicitSize: 24
				    }

				    ColumnLayout {
					    Label {
						    text: modelData.deviceName;
						    elide: Text.ElideRight
					    }
					    Label {
						    text: modelData.address;
					    }
				    }

				    Item { Layout.fillWidth: true } // 弹簧

				    Label {

					    text: modelData.paired ? "已配对" : ""
					    color: contentTheme.subtext
					    font.pixelSize: 11
					    visible: modelData.paired
				    }

				    // 操作按钮：统一使用 Network 的 Rectangle 风格按钮
				    Rectangle {
					    width: 60; height: 26; radius: 4
					    // 根据连接状态切换颜色，逻辑参考 NetworkWidget [cite: 77]
					    color: modelData.connected ?
					    Qt.rgba(contentTheme.error.r, contentTheme.error.g, contentTheme.error.b, 0.15) :
					    Qt.rgba(contentTheme.primary.r, contentTheme.primary.g, contentTheme.primary.b, 0.15)

					    Text {
						    anchors.centerIn: parent
						    text: modelData.connected ? "断开" : (modelData.paired ? "连接" : "配对")
						    color: modelData.connected ? contentTheme.error : contentTheme.primary
						    font.pixelSize: 11; font.bold: true
					    }

					    MouseArea {
						    anchors.fill: parent
						    cursorShape: Qt.PointingHandCursor
						    onClicked: {
							    if (modelData.connected) modelData.disconnect();
							    else if (modelData.paired) modelData.connect();
							    else modelData.pair();
						    }
					    }
				    }

				    // 移除 PopupWindow，改为简单的“移除”按钮（仅在已配对时显示）
				    Rectangle {
					    visible: modelData.paired
					    width: 40; height: 26; radius: 4
					    color: Qt.rgba(contentTheme.error.r, contentTheme.error.g, contentTheme.error.b, 0.1)
					    Text {
						    anchors.centerIn: parent
						    text: "移除"; color: contentTheme.error; font.pixelSize: 11
					    }
					    MouseArea {
						    anchors.fill: parent
						    onClicked: modelData.forget()
					    }
				    }

			    }
			}
		}
	    }


    }
