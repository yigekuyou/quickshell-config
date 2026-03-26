import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Services
import qs.Config
import org.kde.kirigami as Kirigami
// 1. 导入 Widget 目录
import qs.Widget

Kirigami.ShadowedRectangle {
    id: root

    // --- 样式配置 ---
    implicitWidth: layout.implicitWidth + Kirigami.Units.largeSpacing * 2
    implicitHeight: Sizes.barHeight

    // 使用 Kirigami 主题色配合半透明效果
    color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.5)
    radius: Sizes.cornerRadius
    shadow.color: Qt.rgba(0, 0, 0, 0.2)
    shadow.size: 10
    shadow.yOffset: 2
    border.width: 1
    border.color: Qt.alpha(Kirigami.Theme.dividerColor, 0.3)
// 实例化混音器小组件
    AudioWidget {
        id: audioPanel
        visible: false // 默认关闭
    }

    // --- 交互区域 ---
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        
        // 允许滚轮调节音量 (保持不变)
        onWheel: (wheel) => {
            const step = 0.05
            let newVol = Volume.sinkVolume
            
            if (wheel.angleDelta.y > 0) newVol += step
            else newVol -= step

            Volume.setSinkVolume(newVol)
        }

        // 3. 点击切换小组件开关
        onClicked: {
            // 原来是: Quickshell.execDetached(["pavucontrol"])
            // 现在改为:
            audioPanel.visible = !audioPanel.visible
        }
    }

    // --- 内容布局 (保持不变) ---
    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
		Layout.preferredWidth: Kirigami.Units.gridUnit
		Layout.preferredHeight: Kirigami.Units.gridUnit

		// 逻辑：根据 Volume 状态切换系统图标名称
		source: {
			if (Volume.isHeadphone) return "audio-headphones"
				if (Volume.sinkMuted || Volume.sinkVolume <= 0) return "audio-volume-muted"
					if (Volume.sinkVolume < 0.33) return "audio-volume-low"
						if (Volume.sinkVolume < 0.66) return "audio-volume-medium"
							return "audio-volume-high"
		}
		color: (Volume.sinkMuted || Volume.sinkVolume <= 0)
		? Kirigami.Theme.negativeTextColor
		: Kirigami.Theme.activeTextColor
	}
        Label {
		text: Math.round(Volume.sinkVolume * 100) + "%"
		font.bold: true
		font.pixelSize: Kirigami.Units.gridUnit * 0.8
		color: Kirigami.Theme.textColor
	}
    }
}
