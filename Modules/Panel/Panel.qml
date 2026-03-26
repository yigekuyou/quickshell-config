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
		screen: modelData
		anchors {
			bottom: true
		}
		color: "transparent"
		implicitWidth: layout.implicitWidth
		implicitHeight: layout.implicitHeight
		RowLayout{
			id:layout
			Panelapp{}
		}


	}
}
