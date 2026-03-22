import QtQuick
// 【重要】引入 Sizes.qml 所在的目录
// 假设 ClockContent.qml 在 qs/Modules/DynamicIsland/Clock/，你需要向上跳 3 级
import qs.config 
import Quickshell
import qs.Services
import org.kde.kirigami as Kirigami
import QtQuick.Layouts
import QtQuick.Controls
Item {
	id: root
	implicitWidth: mainLayout.implicitWidth
	implicitHeight: mainLayout.implicitHeight

	RowLayout {
		id: mainLayout
		anchors.fill: parent
		spacing: Kirigami.Units.smallSpacing

		// 时间部分：使用大字号或加粗
		Kirigami.Heading {
			level: 1 // 对应较大的标题感
			// 直接绑定单例，无需 Timer 手动赋值
			text: Time.hours + ":" + Time.minutes

			font.family: Sizes.fontFamily
			font.weight: Font.DemiBold
			color: Kirigami.Theme.textColor
		}
		// 如果需要 AM/PM 标识
		Label {
			text: Time.amPm
			font: Kirigami.Theme.smallFont
			Layout.alignment: Qt.AlignBottom
			Layout.bottomMargin: 4
			visible: true // 根据需要开启
		}

		// 垂直分隔线 (Kirigami 风格)
		Kirigami.Separator {
			Layout.fillHeight: true
			Layout.preferredWidth: 1
			opacity: 0.5
		}
		Label {
			text: Time.day
			font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
			font.weight: Font.Bold
			Layout.alignment: Qt.AlignLeft
		}

		// 垂直分隔线 (Kirigami 风格)
		Kirigami.Separator {
			Layout.fillHeight: true
			Layout.preferredWidth: 1
			opacity: 0.5
		}

		// 日期与月份：垂直堆叠，显得更精致
		ColumnLayout {
			spacing: 0
			Label {
				text: Time.month
				font.pointSize: Kirigami.Theme.smallFont.pointSize
				opacity: 0.7
				Layout.alignment: Qt.AlignLeft
			}
			Label {
				text: Time.year
				font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
				font.weight: Font.Bold
				Layout.alignment: Qt.AlignLeft
			}
		}
		// 垂直分隔线 (Kirigami 风格)
		Kirigami.Separator {
			Layout.fillHeight: true
			Layout.preferredWidth: 1
			opacity: 0.5
		}
		ColumnLayout {
			spacing: 0
			Label {
				text: Time.week
				font.pointSize: Kirigami.Theme.smallFont.pointSize
				opacity: 0.7
				Layout.alignment: Qt.AlignLeft
			}
		}
	}

	// 交互优化：悬停显示完整格式
	ToolTip.visible: mouseArea.hovered
	ToolTip.text: Qt.formatDateTime(new Date(), Qt.DefaultLocaleLongDate)

}
