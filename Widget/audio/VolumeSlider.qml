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
	Rectangle {
		Layout.fillWidth: true
		height: 28
		color: Qt.rgba(theme.primary.r, theme.primary.g, theme.primary.b, 0.1)
		radius: 14

		Rectangle {
			height: parent.height
			width: node ? parent.width * node.audio.volume : 0
			color: theme.primary
			radius: 14

		}
		Kirigami.Icon {
			anchors.left: parent.left
			anchors.leftMargin: Kirigami.Units.mediumSpacing
			anchors.verticalCenter: parent.verticalCenter
			source: (node && node.audio.muted) ? "audio-volume-muted" : (root.isHeadphone ? "audio-headphones" : "audio-speakers")
			implicitWidth: Kirigami.Units.iconSizes.small
			implicitHeight: Kirigami.Units.iconSizes.small
			color: "white" // 进度条上的图标通常固定白色以保证对比度
		}

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor
			hoverEnabled: true
			function setVol(mouse) {
				if (!node) return
					let v = mouse.x / width
					if (v < 0) v = 0; if (v > 1) v = 1;
					node.audio.volume = v
					if (node.audio.muted) node.audio.muted = false
			}
			onPressed: (mouse) => setVol(mouse)
			onPositionChanged: (mouse) => setVol(mouse)
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
