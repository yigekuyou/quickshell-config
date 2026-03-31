//LyricsContent.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami
Item {
    id: root
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    property var player: Lyrics.player.mprisData
    property ListModel lyricsWTimes :Lyrics.player.lyricsWTimes
    property bool active: player.Playing
    readonly property string trackTitle: player ? player.trackTitle : ""
    readonly property string trackArtist: player ? player.trackArtist : ""
    readonly property string playerName: player ? (player.identity || player.busName || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""

        // 专辑封面
        Item {
            id: albumCoverContainer
            anchors.left: parent.left
            anchors.leftMargin: 15
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26

            Kirigami.ShadowedImage {
                id: coverImg
                anchors.fill: parent
                source: root.artUrl
                visible: root.artUrl !== ""
                fillMode: Image.PreserveAspectCrop
                radius: Kirigami.Units.smallSpacing
                shadow.size: Kirigami.Units.smallSpacing
                shadow.xOffset: 0
                shadow.yOffset: 2
                shadow.color: Qt.rgba(0, 0, 0, 0.3)
		}
	}
        // 歌词列表
        LyricsText{
		anchors.leftMargin: Kirigami.Units.largeSpacing
		anchors.rightMargin: Kirigami.Units.largeSpacing

		player:root.player
		lyricsWTimes:root.lyricsWTimes
	}
}
