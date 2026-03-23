import QtQuick
import QtQuick.Layouts
import qs.Widget.common
import org.kde.kirigami as Kirigami
import QtQuick.Controls
RowLayout{
	Layout.fillWidth: true
	id: root
	spacing: Kirigami.Units.smallSpacing
	property var node
	property bool isHeadphone: false
	property var theme: Theme {}
		Kirigami.Icon {
			anchors.left: parent.left
			anchors.leftMargin: Kirigami.Units.mediumSpacing
			anchors.verticalCenter: parent.verticalCenter
			source: (node && node.audio.muted) ? "audio-volume-muted" : (root.isHeadphone ? "audio-headphones" : "audio-speakers")
			implicitWidth: Kirigami.Units.iconSizes.small
			implicitHeight: Kirigami.Units.iconSizes.small
			color: "white" // 进度条上的图标通常固定白色以保证对比度
		}
			// 进度填充
			Rectangle {
				Layout.fillWidth: true
				implicitHeight: 6
				color: Qt.rgba(1, 1, 1, 0.1) // 半透明深色背景
				radius: height / 2


			Rectangle {
				id: progressFill
				height: parent.height
				width: node ? parent.width * (mouseArea.pressed ?
				Math.min(Math.max(0, mouseArea.mouseX / parent.width), 1.0) :
				node.audio.volume) : 0
				color: Kirigami.Theme.highlightColor
				radius: height / 2

				// 渐变美化（可选）
				opacity: node && node.audio.muted ? 0.5 : 1.0
				Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
			}
			Rectangle {
				x: progressFill.width - width / 2
				anchors.verticalCenter: parent.verticalCenter
				width: 12; height: 12
				radius: 6
				color: "white"
				visible: mouseArea.containsMouse || mouseArea.pressed

				// 给小圆点加个简单的阴影或缩放效果
				scale: mouseArea.pressed ? 1.2 : 1.0
				Behavior on scale { NumberAnimation { duration: 100 } }
			}

			MouseArea {
				id: mouseArea
				hoverEnabled: true
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor
				onPressed:{
					let pos = Math.min(Math.max(0, mouse.x / parent.width), 1.0);
					node.audio.volume = pos
				}
				onReleased: {
					let pos = Math.min(Math.max(0, mouse.x / parent.width), 1.0);
					node.audio.volume = pos
				}
				onPositionChanged: (mouse) => {
					if (pressed) {
						let pos = Math.min(Math.max(0, mouse.x / parent.width), 1.0);
						node.audio.volume = pos
					}
				}
			}

		}
	Button {
		Layout.preferredWidth: Kirigami.Units.gridUnit * 2 // 使用网格单位替代固定像素
		Layout.preferredHeight: Kirigami.Units.gridUnit * 2
		flat: true
		hoverEnabled: true
		display: AbstractButton.IconOnly // 如果只想显示图标
		icon.name: node.audio.muted ? "audio-volume-muted" : "audio-volume-high"
		icon.color: node.audio.muted ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor

		ToolTip.text: node.audio.muted ? "恢复" : "静音"
		ToolTip.delay: Kirigami.Units.toolTipDelay
		ToolTip.visible: hovered
		onClicked: node.audio.muted = !node.audio.muted
	}
}
