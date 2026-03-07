// Bar.qml
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
	id: root
	property string time

	Variants {
		model: Quickshell.screens
		PanelWindow {
			WlrLayershell.namespace: "Nox:bar"
			required property var modelData
			screen: modelData
			anchors {
				top: true
				left: true
				right: true
			}
			color: "transparent"
			implicitHeight: 30
			Rectangle {
				color: "transparent"
				anchors.fill: parent
				border.color: '#cba6f7'
				border.width: 6
				radius:28
			}
			RowLayout {
				anchors.fill: parent
				RowLayout {
					Text {
						Layout.alignment: Qt.AlignLeft
						anchors.left: parent
						text: ""
					}
				}
				RowLayout {
					Layout.alignment: Qt.AlignLeft
					Repeater {
						model: 10
						Text {
							property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
							property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
							text: index + 1
							color: isActive ? "#0db9d7" : (ws ? "#7aa2f7" : "#444b6a")
							font { bold: true }
							MouseArea {
								anchors.fill: parent
								onClicked: Hyprland.dispatch("workspace " + (index + 1))
							}
						}
					}
				}
				Notification{}
				LyricWidget {
					Layout.alignment: Qt.AlignRight
				}
				ClockWidget {
					Layout.alignment: Qt.AlignRight
				}
				RowLayout {
					Layout.alignment: Qt.AlignRight
					anchors.fill: parent
					Text {
						text: ""
					}
				}
			}
		}
	}

}
