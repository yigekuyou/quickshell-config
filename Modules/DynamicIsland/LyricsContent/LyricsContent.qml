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

Kirigami.CardsListView {
    anchors.fill: parent
    spacing: parent.width / 5
    model: Lyrics.players
    orientation: ListView.Horizontal
    snapMode: ListView.SnapOneItem
    highlightRangeMode: ListView.StrictlyEnforceRange
    delegate: Kirigami.Card {
        id: actived
        background: Rectangle {
            color: "transparent"
            radius: Kirigami.Units.gridUnit

            // 如果你希望完全透明，直接用 color: "transparent"
        }
        property var player: Lyrics.playerManager.objectAt(index).mprisData
        property ListModel lyricsWTimes: Lyrics.playerManager.objectAt(index).lyricsModel
        readonly property string trackTitle: player ? player.trackTitle : ""
        readonly property string trackArtist: player ? player.trackArtist : ""
        readonly property string playerName: player ? (player.identity || player.busName || "") : ""
        readonly property string artUrl: player ? (player.trackArtUrl || "") : ""

        // 专辑封面
        contentItem:RowLayout {
		spacing: Kirigami.Units.mediumSpacing
            Kirigami.ShadowedImage {
		    Layout.alignment: Qt.AlignVCenter
                id: coverImg
                source: actived.artUrl
                visible: actived.artUrl !== ""
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                Layout.preferredWidth: Layout.preferredHeight
                fillMode: Image.PreserveAspectCrop
            }
            LyricsText {
		    Layout.alignment: Qt.AlignVCenter
                player: actived.player
                lyricsWTimes: actived.lyricsWTimes
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
            }
        }
    }
    PageIndicator {
	    anchors.bottom: parent.bottom
	    anchors.horizontalCenter: parent.horizontalCenter
	    count: parent.count
	    currentIndex: parent.currentIndex
    }
}
