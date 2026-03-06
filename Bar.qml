// Bar.qml
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Scope {
	id: root
	property string time

	Variants {
		model: Quickshell.screens
		PanelWindow {
			exclusiveZone:1
			required property var modelData
			screen: modelData
			color: "transparent"
			anchors {
				top: true
				left: true
				right: true
			}
			implicitHeight: 30

			RowLayout {
				anchors.fill: parent
				RowLayout {
					Text {
						anchors.left: parent
						text: " "
					}
				}
				RowLayout {
					Layout.alignment: Qt.AlignLeft
					Repeater {
						model: 10
						Text {
							Layout.fillHeight: true
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
				LyricWidget {
					Layout.fillHeight: true
					Layout.alignment: Qt.AlignRight
				}
				ClockWidget {
					Layout.fillHeight: true
					Layout.alignment: Qt.AlignRight
				}
				RowLayout {
					Layout.alignment: Qt.AlignRight
					anchors.centerIn:parent
					Text {
						text: " "
					}
				}
			}
		}
	}

}
