//LyricsContent.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.config

Item {
    id: root
    required property var player
    property bool active: false
    readonly property string trackTitle: player ? player.trackTitle : ""
    readonly property string trackArtist: player ? player.trackArtist : ""
    readonly property string playerName: player ? (player.identity || player.busName || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property string position: player ? (player.position * 1000 * 1000 || "") : ""
    property int currentLyricIndex: 0
    property int mprisCurrentPlayingSongTimeMS: {
        if (position == 0) {
            return -1;
        } else {
            return position;
        }
    }
    Timer {
        id: positionTimer
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            if (position > 0) {
                root.mprisCurrentPlayingSongTimeMS = position;
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
        }
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

            Image {
                id: coverImg
                anchors.fill: parent
                source: root.artUrl
                visible: root.artUrl !== ""
                fillMode: Image.PreserveAspectCrop
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: ShaderEffectSource {
                        sourceItem: Rectangle {
                            width: coverImg.width
                            height: coverImg.height
                            radius: 5
                            color: "black"
                        }
                    }
                }
            }
            Text {
                visible: root.artUrl === ""
                anchors.centerIn: parent
                text: "\uf001"
                font.family: "Symbols Nerd Font Mono"
                font.pixelSize: 14
                color: "#80ffffff"
            }
        }
        // 歌词列表
        ListView {
            id: lyricListView
            preferredHighlightBegin: 0
            preferredHighlightEnd: 42
            anchors.left: albumCoverContainer.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 15
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            // 将 ListView 的右边界与 iconsContainer 的左边界对齐
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            flickableDirection: Flickable.AutoFlickDirection
            orientation: ListView.Horizontal // 设置为水平滚动
            cacheBuffer: Lyrics.lyricsWTimes.count
            model: Lyrics.lyricsWTimes
            anchors.verticalCenterOffset: 20

            // 歌词条目的委托
            delegate: Label{
		    Layout.preferredWidth: implicitWidth
		    text: model.lyric
		    horizontalAlignment: Text.AlignRight
                font.pixelSize: 14
                anchors.verticalCenterOffset: 20
                color: "#80ffffff"
	}
            onCurrentIndexChanged: {
                if (Lyrics.lyricsWTimes.count > 0 && currentIndex >= 0) {
                    lyricListView.positionViewAtIndex(currentIndex, ListView.Right);
                    lyricScrollAnimation.stop();
                    lyricMetrics.text = Lyrics.lyricsWTimes.get(currentIndex).lyric;
                    if (lyricMetrics.advanceWidth > width) {
                        if (currentIndex + 2 < Lyrics.lyricsWTimes.count) {
                            lyricScrollAnimation.duration = (Lyrics.lyricsWTimes.get(currentIndex + 1).time - mprisCurrentPlayingSongTimeMS) / 1000; //这是从计算器里验证的ms
                        }
                        if (currentIndex + 1 === Lyrics.lyricsWTimes.count) {
                            lyricScrollAnimation.duration = (Lyrics.lyricsWTimes.length - mprisCurrentPlayingSongTimeMS) / 1000;
                        }
                        lyricScrollAnimation.from = contentX - width;
                        lyricScrollAnimation.to = contentX - width + lyricMetrics.advanceWidth;
                        lyricScrollAnimation.start();
                    }
                }
            }
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
        TextMetrics {
            id: lyricMetrics
            font.pixelSize:14
        }
    }
}
