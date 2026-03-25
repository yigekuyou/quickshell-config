import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import org.kde.kirigami as Kirigami
Kirigami.ShadowedRectangle {
    id: root

    color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.5)
    radius: Kirigami.Units.gridUnit * 0.5

    border.width: 1
    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.1)
    // ============================================================
    // 1. 属性定义
    // ============================================================
    property bool expanded: false
    property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/scripts/cava.sh"

    property int collapsedWidth: 40
    property int autoWidth: (cavaText.contentWidth > 0 ? cavaText.contentWidth : 50) + 45
    
    width: expanded ? autoWidth : collapsedWidth
    height: Sizes.barHeight
    
    clip: true
    
    implicitWidth: width
    implicitHeight: height

    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
        
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }

        RowLayout {
anchors.fill: parent
            
            // ★★★ 核心修复：动态右边距 ★★★
            // 收起时：(40 - 图标宽) / 2 -> 算术级绝对居中
            // 展开时：8 -> 保持紧凑
            anchors.rightMargin: root.expanded ? Kirigami.Units.largeSpacing : (root.collapsedWidth - musicIcon.implicitWidth) / 2
            spacing: Kirigami.Units.smallSpacing
            layoutDirection: Qt.RightToLeft
            // 加上动画，让图标从居中位置滑到右边位置，非常丝滑
            Behavior on anchors.rightMargin { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
            

            // 1. 图标 (加了 ID 以便计算宽度)
            Kirigami.Icon {
		    id: musicIcon

		    source: "emblem-music-symbolic"

		    color: Kirigami.Theme.activeTextColor

		    // 3. 像素对齐：使用标准小图标尺寸 (通常为 16px 或 22px，随 DPI 缩放)
		    implicitWidth: Kirigami.Units.iconSizes.small
		    implicitHeight: Kirigami.Units.iconSizes.small

		    // 4. 布局对齐：确保在 RowLayout 中垂直居中
		    Layout.alignment: Qt.AlignVCenter
		    		    isMask: true
	    }

            // 2. 分割线
            Kirigami.Separator {
		    implicitWidth: 1
		    Layout.fillHeight: true

		    // 2. 像素调节：上下留出一点边距，让视觉更精致
		    Layout.topMargin: Kirigami.Units.smallSpacing
		    Layout.bottomMargin: Kirigami.Units.smallSpacing

		    // 3. 颜色：自动使用主题的分隔线颜色（带透明度，不突兀）
		    // 如果你想让它更亮或更暗，可以手动调节 opacity
		    opacity: 0.6
		    Behavior on opacity { NumberAnimation { duration: 200 } }
		    // 4. 逻辑控制：如果你的音乐组件未展开，隐藏分割线
		    visible: root.expanded
	    }


        }
                Kirigami.Heading {
			id:cavaText
			level: 5
			Layout.fillWidth: true

			visible: parent.visible
			opacity: 0.5
            }

    Process {
        id: cavaScript
        command: ["bash", root.scriptPath]
        running: root.expanded
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let cleanData = data.trim()
                if (cleanData !== "") {
                    cavaText.text = cleanData
                }
            }
        }
    }
}
