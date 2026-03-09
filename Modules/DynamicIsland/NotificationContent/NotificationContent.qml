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
        anchors.fill: parent
        model: NotificationManager.temporaryNotifications
    id: delegateItem
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
			if (modelData.length > 0 && delegateItem.modelData.actions[0].identifier == "default") { // qmllint disable unresolved-type
				modelData[0].invoke(); // qmllint disable unresolved-type

				const index = ToplevelManager.toplevels.values.findIndex(item => item.appId == modelData.appName);

				if (index != -1) {
					PanelStateService.notificationsPanelVisible = false;
					ToplevelManager.toplevels.values[index].activate();
				}
			}                }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 12

                // --- 图标/头像区域 ---
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40
                    radius: 10
                    color: Colorscheme.background
                    clip: true // 这一步很关键，切圆角
			    IconImage {
				    visible: getIcon(modelData.appIcon, modelData.image, modelData.appName.toLocaleLowerCase()) !== ""
				    source: getIcon(modelData.appIcon, modelData.image, modelData.appName.toLocaleLowerCase())
				    implicitSize: 24
				    anchors.right: parent.right
				    anchors.bottom: parent.bottom
				    anchors.rightMargin: -5

				    function getIcon(appIcon, image, appName) {
					    if (image != "") {
						    if (appIcon != "" && Quickshell.iconPath(appIcon, true)) {
							    return Quickshell.iconPath(appIcon);
						    } else if (Quickshell.iconPath(appName, true)) {
							    return Quickshell.iconPath(appName);
							    console.log(appName)
						    }
					    }
					    return "";
				    }
				    Text {
					    id: fallbackIcon
					    anchors.centerIn: parent
					    text: "💬"
					    visible: parent.cleanPath === "" // 默认不可见
					    font.pixelSize: 20
				    }}
		    }

                // --- 文字区域 (保持不变) ---
                ColumnLayout {
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 2
                    Text {
			    visible:modelData.summary !==""
                        text:  modelData.summary; color: "white"; font.bold: true; font.pixelSize: 14
                        Layout.fillWidth: true; elide: Text.ElideRight
                    }
                    Text {
			    visible:modelData.body !==""
                        text:  modelData.body; color: "#aaa"; font.pixelSize: 12
                        Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 2
                    }
                }
                
                // 关闭按钮
                Text {
                    text: "×"; color: "#444"; font.pixelSize: 18
                    Layout.alignment: Qt.AlignRight | Qt.AlignTop
                }
            }
        }
    }
}
