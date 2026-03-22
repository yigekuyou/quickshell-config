import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.config
import qs.Services
import qs.Widget.common
import qs.Services
import Quickshell.Services.Notifications
import org.kde.kirigami as Kirigami
SlideWindow {
    id: root
    title: "通知中心"
    icon: "notifications"
    windowHeight: 560
    // --- 顶部工具栏 ---
    headerTools: Button {
	flat: true
	ToolTip.visible: hovered
	ToolTip.text: "清除所有通知"
	    onClicked: NotificationManager.dismissAll()
        // 引用全局 Store
	    contentItem: Kirigami.Icon {
		    source: "edit-clear-all"
		    color: parent.pressed ? Kirigami.Theme.highlightColor : Kirigami.Theme.negativeTextColor
	    }
}

    // --- 界面内容 ---
    Kirigami.PlaceholderMessage {
	    anchors.centerIn: parent
	    visible: NotificationManager.temporaryNotifications.count === 0
	    text: "没有新通知"
	    icon.name: "notifications-none"
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Kirigami.Units.smallSpacing
        // 【核心】引用全局单例
        model: NotificationManager.mergedNotifications

        delegate: ItemDelegate {
            Theme { id: itemTheme }
            id: iconContainer
            width: ListView.view.width
	    topPadding: Kirigami.Units.mediumSpacing
	    bottomPadding: Kirigami.Units.mediumSpacing
	    leftPadding: Kirigami.Units.largeSpacing
	    rightPadding: Kirigami.Units.largeSpacing
	    onClicked: {
			    modelData.actions.invoke();
	    }
contentItem: RowLayout {
                spacing: Kirigami.Units.largeSpacing
                // 图标
                Kirigami.Icon {
			Layout.alignment: Qt.AlignTop
			Layout.preferredWidth: Kirigami.Units.iconSizes.medium
			Layout.preferredHeight: Kirigami.Units.iconSizes.medium
			// 自动处理 Image 路径或图标名
			source: modelData.image || modelData.appIcon || modelData.appName.toLowerCase()
		}
                // 内容
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    RowLayout {
			    Label {
				    text: modelData.appName
				    font.bold: true
				    font.pointSize: Kirigami.Theme.smallFont.pointSize
				    color: Kirigami.Theme.highlightColor
				    Layout.fillWidth: true
				    elide: Text.ElideRight
			    }

			    Label {
				    text: modelData.time || ""
				    font: Kirigami.Theme.smallFont
				    color: Kirigami.Theme.disabledTextColor
			    }
		    }
		    // 摘要
		    Label {
			    text: modelData.summary
			    font.weight: Font.Bold
			    elide: Text.ElideRight
			    Layout.fillWidth: true
		    }
		    // 正文
		    Label {
			    text: modelData.body
			    wrapMode: Text.Wrap
			    maximumLineCount: 3
			    elide: Text.ElideRight
			    Layout.fillWidth: true
			    opacity: 0.7
			    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
		    }
		    // --- 动态 Action 按钮
                }

                // 删除按钮
                Button {
			Layout.alignment: Qt.AlignTop
			flat: true
			icon.name: "window-close"
			onClicked: NotificationManager.dismiss(modelData, true)
			// 只有在悬停或触摸设备上显现
			ToolTip.visible: hovered
			ToolTip.text: "清除通知"
			Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
		}
            }
        }
    }
}
