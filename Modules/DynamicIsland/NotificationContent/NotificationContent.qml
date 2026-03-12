import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell
import qs.config
import qs.Services
import Quickshell.Services.Notifications

Item {
    id: root

    ListView {
        id: delegateItem
        anchors.fill: parent
        model: NotificationManager.sortedTemopraryNotifications
        spacing: 10
        clip: true
        interactive: false

        delegate: Rectangle {
            width: ListView.view.width
            height: 60
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (modelData.actions.identifier == "default") {
                        modelData.actions.invoke();
                    }
                }
            }
            RowLayout {
                anchors.fill: parent
                spacing: 12

                // --- 图标/头像区域 ---
                Rectangle {
                    id: iconContainer
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 10
                    color: Colorscheme.background
                    function getIcon(appIcon, image, appName) {
                        if (image && image !== "") {
                            return image;
                        }
                        if (appIcon && appIcon !== "") {
                            if (Quickshell.iconPath(appIcon, true)) {
                                return Quickshell.iconPath(appIcon);
                            }
                        }
                        if (appName && appName !== "") {
                            let name = appName.toLowerCase();
                            if (Quickshell.iconPath(name, true)) {
                                return Quickshell.iconPath(name);
                            }
                        }
                        return ""; // 全都没找到则返回空
                    }
                    readonly property string iconSource: getIcon(modelData.appIcon, modelData.image, modelData.appName.toLowerCase())
                    clip: true // 这一步很关键，切圆角
                    IconImage {
			    id:icond
                        anchors.fill: parent
                        visible: iconContainer.iconSource
                        source: iconContainer.iconSource
                        implicitSize: 24
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: -5

                        Text {
                            id: fallbackIcon
                            anchors.centerIn: parent
                            text: "💬"
                            visible: !icond.visible  // 默认不可见
                            font.pixelSize: 20
                        }
                    }
                }

                // --- 文字区域 (保持不变) ---
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    Text {
                        visible: modelData.summary !== ""
                        text: modelData.summary
                        color: "white"
                        font.bold: true
                        font.pixelSize: 14
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: modelData.body !== ""
                        text: modelData.body
                        color: "#aaa"
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        maximumLineCount: 2
                    }
                }

                // 关闭按钮
                Text {
                    text: "×"
                    color: "#444"
                    font.pixelSize: 18
                    Layout.alignment: Qt.AlignRight | Qt.AlignTop
                }
            }
        }
    }
}
