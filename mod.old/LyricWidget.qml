import QtQuick
import QtQuick
import QtQuick.Controls
import Quickshell.Services.Mpris
Item {
	property var currentPlayer: Lyrics.currentPlayer
	property alias lyricsModel: Lyrics.lyricsWTimes
	id: mediaControlsContainer
	anchors.left: logoSeparator.right
	anchors.verticalCenter: parent.verticalCenter
	width: 130
	height: parent.height

	property var currentPlayer: Mpris.players.values[0] || null

	ListView {
		id: lyricListView
		anchors.fill: parent
		orientation: ListView.Horizontal
		interactive: false
		model: lyricsModel
		currentIndex: Lyrics.currentLyricIndex

		delegate: Text {
			height: parent.height
			text: model.lyric
			color: "#cba6f7"
			font.pixelSize: 16
			verticalAlignment: Text.AlignVCenter
			margin: 20 // 间距
		}
	Row {
		spacing: 24
		anchors.centerIn: parent
		visible: mediaControlsContainer.currentPlayer !== null

		// Previous button

		Text {
			text: "󰒮"
			color: "#cba6f7"
			font.pixelSize: 20
			font.family: Globals.iconFont
			anchors.verticalCenter: parent.verticalCenter
			verticalAlignment: Text.AlignVCenter
			opacity: mediaControlsContainer.currentPlayer && mediaControlsContainer.currentPlayer.canGoPrevious ? 1.0 : 0.5

			MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor
				onClicked: {
					if (mediaControlsContainer.currentPlayer && mediaControlsContainer.currentPlayer.canGoPrevious) {
						mediaControlsContainer.currentPlayer.previous()
					}
				}
				hoverEnabled: true
				onEntered: if (mediaControlsContainer.currentPlayer && mediaControlsContainer.currentPlayer.canGoPrevious) parent.opacity = 0.8
				onExited: parent.opacity = mediaControlsContainer.currentPlayer && mediaControlsContainer.currentPlayer.canGoPrevious ? 1.0 : 0.5
			}
		}

		// Play/Pause button
		Text {
			text: mediaControlsContainer.currentPlayer && mediaControlsContainer.currentPlayer.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
			color: "#cba6f7"
			font.pixelSize: 20
			font.family: Globals.iconFont
			anchors.verticalCenter: parent.verticalCenter
			verticalAlignment: Text.AlignVCenter

			MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor
				onClicked: {
					if (mediaControlsContainer.currentPlayer) {
						if (mediaControlsContainer.currentPlayer.playbackState === MprisPlaybackState.Playing) {
							if (mediaControlsContainer.currentPlayer.canPause) {
								mediaControlsContainer.currentPlayer.pause()
							}
						} else {
							if (mediaControlsContainer.currentPlayer.canPlay) {
								mediaControlsContainer.currentPlayer.play()
							}
						}
					}
				}
				hoverEnabled: true
				onEntered: parent.opacity = 0.8
				onExited: parent.opacity = 1.0
			}
		}

		// Next button
		Text {
			text: "󰒭"
			color: "#cba6f7"
			font.pixelSize: 20
			font.family: Globals.iconFont
			anchors.verticalCenter: parent.verticalCenter
			verticalAlignment: Text.AlignVCenter
			opacity: mediaControlsContainer.currentPlayer && mediaControlsContainer.currentPlayer.canGoNext ? 1.0 : 0.5

			MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor
				onClicked: {
					if (mediaControlsContainer.currentPlayer && mediaControlsContainer.currentPlayer.canGoNext) {
						mediaControlsContainer.currentPlayer.next()
					}
				}
				hoverEnabled: true
				onEntered: if (mediaControlsContainer.currentPlayer && mediaControlsContainer.currentPlayer.canGoNext) parent.opacity = 0.8
				onExited: parent.opacity = mediaControlsContainer.currentPlayer && mediaControlsContainer.currentPlayer.canGoNext ? 1.0 : 0.5
			}
		}
	}
}
