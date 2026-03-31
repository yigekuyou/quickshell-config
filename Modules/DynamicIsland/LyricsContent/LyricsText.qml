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

// 歌词列表
ListView {
    id: lyricListView
    preferredHighlightBegin: 0
    preferredHighlightEnd: width
    anchors.left: albumCoverContainer.right
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    property var player
    property ListModel lyricsWTimes
    readonly property var position: player ? (player.position * 1000 * 1000 || 0) : 0
    property int currentLyricIndex: 0
    property var mprisCurrentPlayingSongTimeMS: 0
    onMprisCurrentPlayingSongTimeMSChanged: {
        if (lyricsWTimes.count > 0 && player) {
            for (let i = 0; i < lyricsWTimes.count; i++) {
                if (lyricsWTimes.get(i).time >= mprisCurrentPlayingSongTimeMS) {
                    currentLyricIndex = i > 0 ? i - 1 : 0;
                    break;
                } else {
                    if (!i) {
                        continue;
                    }
                    if (i > currentLyricIndex) {
                        currentLyricIndex = i;
                    }
                }
            }
        }
    }
    onPositionChanged: {
        mprisCurrentPlayingSongTimeMS = position;
        if (player !== null) {
            positionWatchdog.restart();
        } else {
            positionWatchdog.stop(); // 确保它彻底闭嘴
        }
    }
    Timer {
        id: positionWatchdog
        running: player && player.isPlaying
        interval: 200
        repeat: true
        onTriggered: player.positionChanged()
    }
    Binding {
        target: lyricListView
        property: "currentIndex"
        value: currentLyricIndex
    }
    interactive: false
    clip: true
    flickableDirection: Flickable.AutoFlickDirection
    orientation: ListView.Horizontal // 设置为水平滚动
    snapMode: ListView.SnapOneItem
    cacheBuffer: lyricsWTimes.count
    model: lyricsWTimes
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
        if (lyricsWTimes.count > 0 && currentIndex >= 0) {
            lyricListView.positionViewAtIndex(currentIndex, ListView.Right);
            lyricScrollAnimation.stop();
            lyricMetrics.text = lyricsWTimes.get(currentIndex).lyric;
            if (lyricMetrics.advanceWidth + Kirigami.Units.smallSpacing > width) {
                if (currentIndex + 2 < lyricsWTimes.count) {
                    lyricScrollAnimation.duration = Math.max(0, (lyricsWTimes.get(currentIndex + 1).time - mprisCurrentPlayingSongTimeMS) / 1000); //这是从计算器里验证的ms
                }
                if (currentIndex + 1 === lyricsWTimes.count) {
                    lyricScrollAnimation.duration = (lyricsWTimes.length - mprisCurrentPlayingSongTimeMS) / 1000;
                }
                lyricScrollAnimation.from = contentX - width;
                lyricScrollAnimation.to = contentX - width + lyricMetrics.advanceWidth;
                lyricScrollAnimation.start();
            } else {
                lyricScrollAnimation.from = contentX - width + lyricMetrics.advanceWidth + Kirigami.Units.smallSpacing;
                lyricScrollAnimation.to = contentX - width + lyricMetrics.advanceWidth + Kirigami.Units.smallSpacing;
                lyricScrollAnimation.start();
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
