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

SlideWindow {
    id: root
    title: "网络配置"
    icon: "\uf1eb"
    onIsOpenChanged: {
        WidgetState.networkOpen = isOpen;
    }
    function getWifiDevice() {
	    return [...Networking.devices.values].find(d => d.type === DeviceType.Wifi);
    }
    headerTools: RowLayout {
        Theme {
            id: headerTheme
        }

        // 刷新按钮
        Text {
            id: boolscan
            property var wifiDev: root.getWifiDevice()
	    opacity: (wifiDev && wifiDev.scannerEnabled) ? 0.5 : 1.0

            text: "\uf021"
            font.family: "Font Awesome 6 Free Solid"
            font.pixelSize: 16
            color: headerTheme.subtext
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
			let dev = root.getWifiDevice();
			if (dev) dev.scannerEnabled = true;;
                }
            }
            RotationAnimation on rotation {
                running: scanWifi.running
                from: 0
                to: 360
                loops: Animation.Infinite
                duration: 1000
            }
        }

        Item {
            implicitWidth: 10
        }
        Rectangle {
            id: wifiSwitch
            Layout.fillWidth: false // 通常开关不 fillWidth，除非你想要一个长条开关
            implicitWidth: 40
            implicitHeight: 22
            radius: 11

            // --- 核心逻辑 ---
            // 1. 只有硬件开关开启时，这个 UI 才是可用的
            enabled: Networking.wifiHardwareEnabled

            // 2. 状态颜色：如果硬件禁用，显示灰色；如果开启，根据软件开关状态显示颜色
            color: !enabled ? "#A0A0A0" : (Networking.wifiEnabled ? headerTheme.primary : headerTheme.outline)
            // 3. 视觉反馈：变灰/半透明
            opacity: enabled ? 1.0 : 0.5
            // 开关滑块
            Rectangle {
                x: (Networking.wifiEnabled && Networking.wifiHardwareEnabled) ? 20 : 2
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
                    // 只有在硬件允许的情况下才切换软件开关
                    Networking.wifiEnabled = !Networking.wifiEnabled;
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5
        ListView {
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
