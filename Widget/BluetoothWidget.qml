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
        Item {
		implicitWidth: 10
	}
        Rectangle {
            id: blueSwitch
            Layout.fillWidth: false // 通常开关不 fillWidth，除非你想要一个长条开关
            implicitWidth: 40
            implicitHeight: 22
            radius: 11

            // --- 核心逻辑 ---
            color:  (Bluetooth.defaultAdapter.enabled ? headerTheme.primary : headerTheme.outline)
            // 3. 视觉反馈：变灰/半透明
            opacity: enabled ? 1.0 : 0.5
            // 开关滑块
            Rectangle {
                x: ((devices)&&Bluetooth.defaultAdapter.enabled) ? 20 : 2
                y: 2
                width: 18
                height: 18
                radius: 9
                color: "white"
                Behavior on x {
                    NumberAnimation {
                        duration: 200
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                }
            }
        }
    }
    ColumnLayout {
	    anchors.margins: 5
	    Theme {
		    id: contentTheme
	    }
	    Text {
		    text: "蓝牙列表"
		    color: contentTheme.subtext
		    font.pixelSize: 12
		    font.bold: true
		    Layout.topMargin: 4
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
				    id: mainColumn
				    anchors.fill: parent
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
							    color: contentTheme.subtext
							    text: modelData.deviceName;
							    font.bold: true;
							    elide: Text.ElideRight
						    }
						    Label {
							    color: contentTheme.subtext
							    text: modelData.address;
							    font.pixelSize: 11;
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
