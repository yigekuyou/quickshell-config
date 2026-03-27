import Quickshell
import Quickshell.Wayland
import org.kde.kirigami as Kirigami
import qs.Modules.Launcher
import QtQuick
import QtQuick.Layouts

Variants {
	model: Quickshell.screens
	PanelWindow {
		LauncherManager{}
		id: panelWindow
		WlrLayershell.namespace:"panelWindow"
		WlrLayershell.layer: WlrLayer.Top
		WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
		exclusionMode: ExclusionMode.Ignore
		required property var modelData
		property bool isExpanded :true
		property int triggerHeight: 1
		screen: modelData
		Timer {
			id: hideTimer
			interval: 500 // 鼠标离开半秒后收起
			running:isExpanded
			onTriggered: panelWindow.isExpanded = false
		}
		anchors {
			bottom: true
		}
		margins {
			bottom: isExpanded ? Kirigami.Units.smallSpacing : 0
		}
		color: "transparent"
		implicitWidth: isExpanded ? layout.implicitWidth:modelData.width
		implicitHeight: isExpanded ? layout.implicitHeight : triggerHeight
		Behavior on implicitHeight {
			NumberAnimation {
				duration: 250
				easing.type: Easing.OutCubic
			}
		}
		Behavior on implicitWidth {
			SequentialAnimation {
				PauseAnimation {
					duration: isExpanded ? 250 : 0
				}

				PropertyAction {}

				// 如果是收起，变窄后可以加个占位等待，确保和高度动画同步结束（可选）
				PauseAnimation {
					duration: isExpanded ? 0 : 250
				}			}
		}
		MouseArea {
			anchors.fill: parent
			hoverEnabled: true

			// 核心逻辑：进入展开，离开触发定时器
			onEntered: {
				hideTimer.stop()
				panelWindow.isExpanded = true
			}
			onExited: hideTimer.start()
		Kirigami.ShadowedRectangle {
			anchors.fill: parent
			color: Kirigami.Theme.backgroundColor
			radius: Kirigami.Units.smallSpacing
			border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
			border.width: isExpanded ?1:0
			shadow.size:isExpanded ? Kirigami.Units.smallSpacing :0
			shadow.color: Qt.rgba(0, 0, 0, 0.3)
			shadow.yOffset: 2
		RowLayout{
			id:layout
			anchors.centerIn: parent
			spacing: Kirigami.Units.mediumSpacing
			anchors.margins: Kirigami.Units.smallSpacing
			Panelapp{}
		}
		}
	}
}
}
