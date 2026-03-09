import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Services
import qs.config
import Quickshell.Networking
import qs.Widget

// 或者如果它就在旁边，直接用 import "." 即可

Rectangle {
    id: root
    // --- 胶囊样式 ---
    radius: Sizes.cornerRadius
    implicitWidth: layout.width + 24
    implicitHeight: Sizes.barHeight
    color: "#80" + Colorscheme.background.toString().substring(1)

    // --- 【2】 实例化网络面板 ---
    NetworkWidget {
        id: wifiPanel
        // 默认是关闭的
        isOpen: false

        // 如果你想让面板的配色跟随全局 Colorscheme，可以在这里覆盖内部属性
        // (前提是 NetworkWidget 内部没有把这些属性写死，而是开放了别名或者属性)
        // 目前你的 NetworkWidget 是自包含配色的，直接用即可。
    }

    // --- 交互区域 ---
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        // --- 【3】 修改点击逻辑 ---
        onClicked: {
            // 切换面板的开关状态
            wifiPanel.isOpen = !wifiPanel.isOpen;
        }
    }
    ColumnLayout {
        id: layout
        anchors.fill: parent

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            spacing: 5

            Repeater {
                model: Networking.devices
                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 4
                    color: modelData.connected ? "#80" + Colorscheme.background.toString().substring(1)  : "#ff5555"

                    Row {
                        spacing: 10
                        layoutDirection: Qt.LeftToRight
                        anchors.centerIn: parent
                        Text {
                            text: (DeviceType.Wifi === modelData.type) ? "" : ""
                            font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.connected ? Colorscheme.on_tertiary_container : "#ff5555"
                        }
                        Text {
                            text: {
                                if (modelData.type === DeviceType.Wifi) {
                                    let sortedNetworks = [...modelData.networks.values].filter(d => d.connected === true).sort((a, b) => {
                                        return b.signalStrength - a.signalStrength;
                                    }) || {};
                                    let topNetwork = sortedNetworks.length > 0 ? sortedNetworks[0] : null;
                                    return topNetwork.name;
                                }
                            }
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData.connected ? Colorscheme.on_tertiary_container : "#ff5555"
                        }
                    }
                }
            }
        }
    }
}
