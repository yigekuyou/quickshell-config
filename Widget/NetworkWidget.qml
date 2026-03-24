import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Services
import Quickshell.Io
import qs.config
import qs.Widget.common
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Networking
import org.kde.kirigami as Kirigami

SlideWindow {
    id: root
    title: "网络配置"
    icon: "network-wireless"
    property var wifiDev: getWifiDevice()
    function getWifiDevice() {
	    return [...Networking.devices.values].find(d => d.type === DeviceType.Wifi);
    }
    headerTools: RowLayout {
        Theme {
            id: headerTheme
        }

        ToolButton {
		id: boolscan
		// Kirigami 推荐使用 icon.name 而非直接使用字体图标字符
		// "view-refresh" 是标准图标名，会自动匹配 Font Awesome 或 Breeze 图标库
		icon.name: wifiDev.scannerEnabled ? "view-refresh" : "edit-find"
		icon.width: Kirigami.Units.iconSizes.small
		icon.height: Kirigami.Units.iconSizes.small

		flat: true // 使其看起来像 header 上的工具按钮

		// 旋转动画：Kirigami 环境下依然建议保留动画逻辑
		RotationAnimation on rotation {
			running: wifiDev.scannerEnabled
			from: 0
			to: 360
			loops: Animation.Infinite
			duration: 1000
			onRunningChanged: if (!running) boolscan.rotation = 0
		}

		onClicked: {
			if (wifiDev) wifiDev.scannerEnabled = !wifiDev.scannerEnabled
		}

		ToolTip.visible: hovered
		ToolTip.text: wifiDev.scannerEnabled ? qsTr("正在扫描...") : qsTr("开始扫描")
	}

	Kirigami.Separator { Layout.fillHeight: true }

	// WiFi 开关部分
	Switch {
		id: wifiSwitch

		// 状态逻辑
		enabled: Networking.wifiHardwareEnabled
		checked: Networking.wifiEnabled && Networking.wifiHardwareEnabled

		// Kirigami 样式会自动处理颜色（primary color）和禁用状态的灰色
		// 不需要手动写 Rectangle 的 radius 和 color

		onToggled: {
			Networking.wifiEnabled = checked
		}

		ToolTip.visible: hovered
		ToolTip.text: !enabled ? qsTr("硬件已禁用") : (checked ? qsTr("WiFi 已开启") : qsTr("WiFi 已关闭"))
	}
    }

    Kirigami.ScrollablePage  {
        anchors.margins: 5
        Kirigami.CardsListView {
            clip: true
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: Networking.devices
            delegate: Item {
                width: parent.width
                height: mainColumn.implicitHeight // 确保 delegate 有高度
                ColumnLayout {
                    id: mainColumn
                    property string currentTab: "wifi"
                    anchors.fill: parent
                    spacing: 10
                    Rectangle {
                        Theme {
                            id: tabTheme
                        }
                        Layout.fillWidth: true
                        height: 36
                        color: tabTheme.surface
                        radius: 8
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 0
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: mainColumn.currentTab === "wifi" ? tabTheme.primary : "transparent"
                                radius: 6
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "Wi-Fi"
                                    font.bold: true
                                    color: mainColumn.currentTab === "wifi" ? tabTheme.text : tabTheme.subtext
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: mainColumn.currentTab = "wifi"
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: mainColumn.currentTab === "ethernet" ? tabTheme.primary : "transparent"
                                radius: 6
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "以太网"
                                    font.bold: true
                                    color: mainColumn.currentTab === "ethernet" ? tabTheme.text : tabTheme.subtext
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: mainColumn.currentTab = "ethernet"
                                }
                            }
                        }
                    }

                    // 2. 内容切换区
                    StackLayout {
                        currentIndex: mainColumn.currentTab === "wifi" ? 0 : 1

                        ColumnLayout {
                            spacing: 6
                            Theme {
                                id: contentTheme
                            }
                            Text {
                                text: "网络列表"
                                color: contentTheme.subtext
                                font.pixelSize: 12
                                font.bold: true
                                Layout.topMargin: 4
                            }
                            ColumnLayout {
                                Repeater {
                                    Layout.fillWidth: true
                                    model: {
                                        if (modelData.type !== DeviceType.Wifi)
                                            return [];
                                        return [...modelData.networks.values].sort((a, b) => {
                                            if (a.connected !== b.connected) {
                                                return b.connected - a.connected;
                                            }
                                            return b.signalStrength - a.signalStrength;
                                        });
                                    }

                                    StackLayout {
                                        Layout.fillWidth: true

                                        RowLayout {
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                RowLayout {
                                                    Label {
                                                        text: modelData.name
                                                        font.bold: true
                                                    }
                                                    Label {
                                                        text: modelData.known ? "Known" : ""
                                                        color: palette.placeholderText
                                                    }
                                                }
                                                RowLayout {
                                                    Label {
                                                        text: `${WifiSecurityType.toString(modelData.security)}`
                                                        color: palette.placeholderText
                                                    }
                                                    Label {
                                                        text: ` ${Math.round(modelData.signalStrength * 100)}%`
                                                        color: palette.placeholderText
                                                    }
                                                }
                                                Label {
                                                    visible: Networking.backend == NetworkBackendType.NetworkManager && (modelData.nmReason != NMConnectionStateReason.Unknown && modelData.nmReason != NMConnectionStateReason.None)
                                                    text: `Connection change reason: ${NMConnectionStateReason.toString(modelData.nmReason)}`
                                                }
                                            }
                                            Item {
                                                Layout.fillWidth: true
                                            }

                                            Rectangle {
                                                visible: !modelData.connected
                                                width: 46
                                                height: 26
                                                radius: 4
                                                color: Qt.rgba(itemTheme.primary.r, itemTheme.primary.g, itemTheme.primary.b, 0.15)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "连接"
                                                    color: itemTheme.primary
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: modelData.connect()
                                                }
                                            }
                                            Rectangle {
                                                visible: modelData.connected
                                                width: 50
                                                height: 26
                                                radius: 4
                                                color: Qt.rgba(itemTheme.error.r, itemTheme.error.g, itemTheme.error.b, 0.15)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "断开"
                                                    color: itemTheme.error
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        onClicked: modelData.disconnect();
                                                    }
                                                }
					    }Rectangle {
						    visible: modelData.forget
						    width: 50
						    height: 26
						    radius: 4
						    color: Qt.rgba(itemTheme.error.r, itemTheme.error.g, itemTheme.error.b, 0.15)

						    Text {
							    anchors.centerIn: parent
							    text: "忘记"
							    color: itemTheme.error
							    font.pixelSize: 11
							    font.bold: true
						    }
						    MouseArea {
							    anchors.fill: parent
							    cursorShape: Qt.PointingHandCursor
							    onClicked: {
								    modelData.forget();
							    }
						    }
					    }
                                        }
                                    }
                                }
                            }
                        }
                        Item {
                            Theme {
                                id: ethTheme
                            }
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 10
                                Text {
                                    text: "\uf796"
                                    font.family: "Font Awesome 6 Free Solid"
                                    font.pixelSize: 40
                                    color: ethTheme.outline
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: "以太网设置暂不可用"
                                    color: ethTheme.subtext
                                }
                            }
                        }
                    }

                }
            }
        }
    }
}
