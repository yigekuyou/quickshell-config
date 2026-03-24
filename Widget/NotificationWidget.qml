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
	    delegate: FormCard.FormButtonDelegate {
		    Layout.fillWidth: true

		    // 修复越界：使用标准属性，不建议重写 contentItem
		    text: modelData.summary
		    description: modelData.body
		    implicitHeight: notifLayout.implicitHeight + topPadding + bottomPadding
		    // 图标处理
		    icon.name: modelData.appIcon || modelData.appName.toLowerCase() || "dialog-information"

		    // 右侧操作按钮：利用 trailingActionBar (FormCard 特有)
		    // 或者简单地在 delegate 内部处理
		    onClicked: modelData.actions.invoke()

		    // 自定义右侧：添加删除按钮
		    contentItem: RowLayout {
			    id: notifLayout
			    spacing: Kirigami.Units.mediumSpacing
			    Kirigami.Icon {
				    Layout.alignment: Qt.AlignTop // 顶部对齐，防止长文本时图标居中不好看
				    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
				    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
				    source: modelData.image || modelData.appIcon || "notifications"
			    }

			    // 2. 中间文字区域 (关键：必须 fillWidth 才能触发换行)
			    ColumnLayout {
				    Layout.fillWidth: true
				    spacing: Kirigami.Units.smallSpacing

				    RowLayout {
					    Kirigami.Heading {
						    Layout.fillWidth: true
						    text: modelData.appName
						    level: 4
						    color: Kirigami.Theme.highlightColor
						    elide: Text.ElideRight
					    }
					    Label {
						    text: modelData.time || "现在"
						    color: Kirigami.Theme.disabledTextColor
						    font.pointSize: Kirigami.Theme.smallFont.pointSize
					    }
					    // 删除按钮
					    ToolButton {
						    icon.name: "window-close"
						    flat: true
						    onClicked: NotificationManager.dismiss(modelData, true)
					    }
				    }

				    // 标题 (Summary) - 允许换 2 行
				    Kirigami.Heading {
					    Layout.fillWidth: true
					    text: modelData.summary
					    level: 4
					    wrapMode: Text.WordWrap       // 开启换行
					    maximumLineCount: 2          // 最多显示2行
					    elide: Text.ElideRight       // 超过后打省略号
				    }

				    // 正文 (Body) - 允许换多行 (n行)
				    Label {
					    Layout.fillWidth: true
					    text: modelData.body
					    opacity: 0.7
					    font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1

					    // --- 核心修复属性 ---
					    wrapMode: Text.WordWrap       // 开启物理换行
					    maximumLineCount: 5          // 这里设置你想要的 n 行上限
					    elide: Text.ElideRight       // 超过 n 行后显示 ...
					    // ------------------
				    }
			    }

		    }
	    }
	}
}
