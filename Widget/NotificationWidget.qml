import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Config
import qs.Services
import qs.Widget.common
import qs.Services
import Quickshell.Services.Notifications
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

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
	    Layout.alignment: Qt.AlignCenter
	    visible: NotificationManager.mergedNotifications.length === 0
	    text: "没有新通知"
	    icon.name: "notifications-none"
    }

    Repeater {
        Layout.fillWidth: true
        // 【核心】引用全局单例
        model: NotificationManager.mergedNotifications
	    delegate: FormCard.FormCard{
		    FormCard.FormButtonDelegate {
		    Layout.fillWidth: true

		    // 修复越界：使用标准属性，不建议重写 contentItem
		    text: modelData.summary
		    description: modelData.body
		    // 图标处理
		    icon.name: modelData.image||modelData.appIcon || modelData.appName.toLowerCase() || "dialog-information"

		    // 右侧操作按钮：利用 trailingActionBar (FormCard 特有)
		    // 或者简单地在 delegate 内部处理
		    onClicked: actionMenu.popup(notifLayout, 0, notifLayout.height)
		    // 自定义右侧：添加删除按钮
		    trailing: RowLayout {
			    id: notifLayout
			    spacing: Kirigami.Units.mediumSpacing

			    // 2. 中间文字区域 (关键：必须 fillWidth 才能触发换行)
				    RowLayout {
					    // 删除按钮
					    ToolButton {
						    icon.name: "window-close"
						    flat: true
						    onClicked: modelData.dismiss()
					    }
				    Menu {
					    id: actionMenu
					    // 动态加载来自 notificationData 的 actions
					    parent: Overlay.overlay
					    Instantiator {
						    model: modelData.actions
						    onObjectAdded: (index, object) => actionMenu.insertItem(index, object)
						    onObjectRemoved: (index, object) => actionMenu.removeItem(object)
						    delegate: MenuItem {
							    text: modelData.text
							    icon.name: modelData.identifier // 如果有的话
							    onTriggered: {
								    modelData.invoke(modelData.id)
							    }
						    }
					    }
				    }
			    }
		    }
	    }
	}
}
}
