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
        Text {
		text: "\uf06e" // FontAwesome 'eye' 图标
		font.family: "Font Awesome 6 Free Solid"
		font.pixelSize: 16
		color: Bluetooth.defaultAdapter.discoverable ? headerTheme.primary : headerTheme.subtext
		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor
			onClicked: {
				// 切换可被发现状态
				Bluetooth.defaultAdapter.discoverable = !Bluetooth.defaultAdapter.discoverable;
			}
		}
	}

	Item {
		implicitWidth: 10
	}
        Text {
            id: boolscan
            text: Bluetooth.defaultAdapter.discovering ? "" : ""
            font.family: "Font Awesome 6 Free Solid"
            font.pixelSize: 16
            color: headerTheme.subtext
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
			Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering;
		}
            }
            RotationAnimation on rotation {
                running: Bluetooth.defaultAdapter.discovering
                from: 0
                to: 360
                onRunningChanged: {
			if (!running) {
				boolscan.rotation = 0;
			}
		}
                loops: Animation.Infinite
                duration: 1000
            }
        }
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
	    leftPadding: 0
	    rightPadding: 0
	    topPadding: 0
	    bottomPadding: 0
	    anchors.margins: 0
	    Theme {
		    id: contentTheme
	    }
	    Kirigami.CardsListView {
		    anchors.fill: parent

		    Layout.fillWidth: true
		    Layout.margins: 0
		    model:bluetooth.devices
		    delegate: Kirigami.AbstractCard {
			    id: mainColumn

			    leftPadding: 0
			    rightPadding: 0
			    topPadding: 0
			    bottomPadding: 0
			    anchors.margins: 0
			    contentItem: RowLayout{
				    anchors.fill: parent

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
			}
		}
	    }
	    ListView {
		    Layout.fillWidth: true; Layout.fillHeight: true
		    model: bluetooth.devices
		    clip: true

		    delegate: Item {
			    width: parent.width
			    height: mainColumn.implicitHeight
			    required property var modelData
			    ColumnLayout {
				    spacing: 10
				    RowLayout {
					    Layout.fillWidth: true
					    // 左侧：图标与信息
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
}
