import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.config
import qs.Services
import qs.Widget.common
import qs.Services
import Quickshell.Services.Notifications

SlideWindow {
    id: root
    title: "通知中心"
    icon: "\uf0f3" 
    windowHeight: 560
    
    extraTopMargin: (WidgetState.networkOpen ? 430 : 0) + (WidgetState.audioOpen ? 370 : 0)
    onIsOpenChanged: WidgetState.notifOpen = isOpen
    // --- 顶部工具栏 ---
    headerTools: Text {
        Theme { id: theme }
        
        text: "\uf1f8" 
        font.family: "Font Awesome 6 Free Solid"
        font.pixelSize: 18
        
        // 引用全局 Store
        color: NotificationManager.temporaryNotifications.count > 0 ? theme.error : theme.subtext
        opacity: NotificationManager.temporaryNotifications.count > 0 ? 1 : 0.5
        
        MouseArea { 
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: NotificationManager.dismissAll()
        }
    }

    // --- 界面内容 ---
    Text {
        Theme { id: bgTheme }

        // 【已修复】：去掉 anchors，改用 Layout 填充并让文本居中对齐
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        visible: NotificationManager.temporaryNotifications.count === 0
        text: "没有新通知"
        color: bgTheme.subtext
        font.pixelSize: 14
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 8

        // 【核心】引用全局单例
        model: NotificationManager.mergedNotifications

        delegate: Rectangle {
            Theme { id: itemTheme }
            id: iconContainer
            width: ListView.view.width
            height: Math.max(60, contentLayout.height + 20)
            radius: 8
            color: "transparent"
	    function getIcon(appIcon, image, appName) {
		    if (image && image !== "") {
			    return image;
		    }
		    if (appIcon && appIcon !== "") {
			    // 检查 Quickshell 是否能找到该图标路径
			    if (Quickshell.iconPath(appIcon, true)) {
				    return Quickshell.iconPath(appIcon);
			    }
		    }			    if (appName && appName !== "") {
			    let name = appName.toLowerCase();
			    if (Quickshell.iconPath(name, true)) {
				    return Quickshell.iconPath(name);
			    }
		    }
		    return ""; // 全都没找到则返回空
	    }
	    readonly property string iconSource: getIcon(modelData.appIcon, modelData.image, modelData.appName.toLowerCase())
            border.width: 1
            border.color: ma.containsMouse ? itemTheme.primary : "transparent"
            Behavior on border.color { ColorAnimation { duration: 150 } }

            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true
		    onClicked: {
			    if (modelData.actions.identifier == "default") {
			    modelData.actions.invoke();
		    }
	    }
	}

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12


                // 图标
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    width: 40; height: 40
                    radius: 8
                    color: Qt.rgba(itemTheme.text.r, itemTheme.text.g, itemTheme.text.b, 0.1)

                    Image {
                        id: img
                        anchors.fill: parent
                        anchors.margins: 4
                        source: iconContainer.iconSource
                        fillMode: Image.PreserveAspectFit
                        visible: iconContainer.iconSource !== "" && status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: iconContainer.iconSource === "" || img.status === Image.Error
                        text: "\uf0e5"
                        font.family: "Font Awesome 6 Free Solid"
                        font.pixelSize: 20
                        color: itemTheme.subtext
                    }
                }

                // 内容
                ColumnLayout {
                    id: contentLayout
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: model.appName
                            font.bold: true
                            font.pixelSize: 11
                            color: itemTheme.primary
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: model.time ?model.time :0
                            font.pixelSize: 10
                            color: itemTheme.subtext
                        }
                    }

                    Text {
                        text: model.summary
                        font.bold: true
                        font.pixelSize: 13
                        color: itemTheme.text
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: model.body
                        font.pixelSize: 12
                        color: itemTheme.subtext
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // 删除按钮
                Text {
                    visible: ma.containsMouse
                    text: "\uf00d"
                    font.family: "Font Awesome 6 Free Solid"
                    color: itemTheme.subtext
                    Layout.alignment: Qt.AlignTop

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        // 调用全局删除
                        onClicked: NotificationManager.dismiss(modelData, true)
                    }
                }
            }
        }
    }
}
