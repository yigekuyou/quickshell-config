//LyricsContent.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.config
import qs.Services
import qs.Modules.DynamicIsland.LyricsContent
import org.kde.kirigami as Kirigami
Item {
    id: root
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    required property var player
    property bool active: false
    readonly property string trackTitle: player ? player.trackTitle : ""
    readonly property string trackArtist: player ? player.trackArtist : ""
    readonly property string playerName: player ? (player.identity || player.busName || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property var position: player ? (player.position * 1000 * 1000 || "") : ""
    property int currentLyricIndex: 0
    property int mprisCurrentPlayingSongTimeMS:0
    onMprisCurrentPlayingSongTimeMSChanged: {
	    if (Lyrics.lyricsWTimes.count > 0 && player) {
		    for (let i = 0; i < Lyrics.lyricsWTimes.count; i++) {
			    if (Lyrics.lyricsWTimes.get(i).time >= mprisCurrentPlayingSongTimeMS) {
				    root.currentLyricIndex = i > 0 ? i - 1 : 0;
				    break;
			    } else {
				    if (!i) {
					    continue;
				    }
				    if (i > currentLyricIndex) {
					    root.currentLyricIndex = i;
				    }
			    }
		    }
	    }
}
onPositionChanged:{
	root.mprisCurrentPlayingSongTimeMS = position

}
    Timer {
	    running: player.playbackState == MprisPlaybackState.Playing
	    interval: 200
	    repeat: true
	    onTriggered: player.positionChanged()
    }
    Binding {
        target: lyricListView
        property: "currentIndex"
        value: currentLyricIndex
    }
    Item {
        anchors.fill: parent
        clip: true
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
        ListView {
            id: lyricListView
            preferredHighlightBegin: 0
            preferredHighlightEnd: width
            anchors.left: albumCoverContainer.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            interactive: false
            clip: true
            flickableDirection: Flickable.AutoFlickDirection
            orientation: ListView.Horizontal // 设置为水平滚动
            snapMode: ListView.SnapOneItem
            cacheBuffer: Lyrics.lyricsWTimes.count
            model: Lyrics.lyricsWTimes
            spacing: width
            // 歌词条目的委托
            delegate: Kirigami.Heading {
		level: 2
                height: lyricListView.height
                Layout.preferredWidth: implicitWidth
                text: model.lyric
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                color: Kirigami.Theme.textColor
            }
            onCurrentIndexChanged: {
                if (Lyrics.lyricsWTimes.count > 0 && currentIndex >= 0) {
                    lyricListView.positionViewAtIndex(currentIndex, ListView.Right);
                    lyricScrollAnimation.stop();
                    lyricMetrics.text = Lyrics.lyricsWTimes.get(currentIndex).lyric;
                    if (lyricMetrics.advanceWidth+Kirigami.Units.smallSpacing > width) {
                        if (currentIndex + 2 < Lyrics.lyricsWTimes.count) {
                            lyricScrollAnimation.duration =Math.max(0,(Lyrics.lyricsWTimes.get(currentIndex + 1).time - mprisCurrentPlayingSongTimeMS) / 1000); //这是从计算器里验证的ms
                        }
                        if (currentIndex + 1 === Lyrics.lyricsWTimes.count) {
                            lyricScrollAnimation.duration = (Lyrics.lyricsWTimes.length - mprisCurrentPlayingSongTimeMS) / 1000;
                        }
                        lyricScrollAnimation.from = contentX - width;
                        lyricScrollAnimation.to = contentX - width + lyricMetrics.advanceWidth;
                        lyricScrollAnimation.start();
                    }else {
			    lyricScrollAnimation.from = contentX - width + lyricMetrics.advanceWidth +Kirigami.Units.smallSpacing ;
			    lyricScrollAnimation.to = contentX - width + lyricMetrics.advanceWidth +Kirigami.Units.smallSpacing ;
			    lyricScrollAnimation.start();
		}
                }
            }
        }
        Kirigami.Heading {
		id: dummyHeading
		level: 2
		visible: false // 不显示，只为了拿数据
	}
        TextMetrics {
		id: lyricMetrics
		font: dummyHeading.font
	}
        Binding {
            target: lyricListView
            property: "currentIndex"
            value: currentLyricIndex
        }
        PropertyAnimation {
            id: lyricScrollAnimation
            target: lyricListView
            property: "contentX"
            easing.type: Easing.Linear
        }

    }
}
