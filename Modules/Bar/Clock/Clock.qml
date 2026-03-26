import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import qs.Services
import qs.config
import org.kde.kirigami as Kirigami

// import qs.Components // 已移除
// import qs.Config     // 已移除

Kirigami.ShadowedRectangle {
    id: rectangle
    
    color: Kirigami.Theme.backgroundColor
    opacity: 0.8
    implicitHeight: Sizes.barHeight
implicitWidth: content.width + (Kirigami.Units.largeSpacing * 2)
    radius: Sizes.cornerRadius
    border.color: Kirigami.Theme.separatorColor
    border.width: 1

    // 最外层 RowLayout，让日期和时间左右排列
    RowLayout {
        id: content
        anchors.centerIn: parent // 居中显示
        spacing: Kirigami.Units.largeSpacing // 日期和时间之间的间距

        // --- 左侧：日期 (月 日) ---
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Layout.alignment: Qt.AlignVCenter // 垂直居中

            Kirigami.Heading {
                Layout.alignment: Qt.AlignBaseline // 基线对齐
                text: Time.month
                level: 4
                color: Kirigami.Theme.disabledTextColor
	    }
	    Kirigami.Heading {
		    level: 4
		    text: Time.day
		    color: Kirigami.Theme.textColor
		    Layout.alignment: Qt.AlignBaseline
	    }
        }

        // --- 中间：分割线 (竖线) ---
        Kirigami.Separator {
		Layout.preferredWidth: 1
		Layout.preferredHeight: Kirigami.Units.gridUnit
		Layout.alignment: Qt.AlignVCenter
	}

        // --- 右侧：时间 (HH:MM) ---
        RowLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            Kirigami.Heading {
		    level: 3 // Slightly larger for time (around 14-16pt)
		    text: Time.hours
		    color: Kirigami.Theme.disabledTextColor
		    Layout.alignment: Qt.AlignBaseline
	    }
            
            // 手动加个冒号
            Kirigami.Heading {
		    level: 3
		    text: ":"
		    color: Kirigami.Theme.textColor
		    Layout.alignment: Qt.AlignBaseline
	    }

	    Kirigami.Heading {
		    level: 3
		    text: Time.minutes
		    color: Kirigami.Theme.textColor
		    Layout.alignment: Qt.AlignBaseline
	    }
        }
    }
}
