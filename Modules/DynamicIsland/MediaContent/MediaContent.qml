import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.config
import QtQuick.Controls
import org.kde.kirigami as Kirigami
Kirigami.Card {
    id: root
    background: Rectangle {
	    color: Qt.rgba(0.1, 0.1, 0.1, 0.8) // 稍微带点深色的透明
	    radius: Kirigami.Units.gridUnit

	    // 如果你希望完全透明，直接用 color: "transparent"
	    // 如果你的组件在 Quickshell 里运行，配合系统的 Blur 特效会更好看
    }
    required property var player

    readonly property bool isActive: root.visible && root.player

    property string artUrl: (isActive && player.trackArtUrl) ? player.trackArtUrl : ""
    property string title: (isActive && player.trackTitle) ? player.trackTitle : "No Media"
    property string artist: (isActive && player.trackArtist) ? player.trackArtist : ""

    // 进度百分比 (0.0 ~ 1.0)
    property double progress: (isActive && player.length > 0) ? (player.position / player.length) : 0
    padding: Kirigami.Units.largeSpacing
    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        // --- 顶部信息栏 (封面 + 歌名) ---
        RowLayout {
            Layout.fillWidth: true

            spacing: Kirigami.Units.largeSpacing

            // 专辑封面
            Kirigami.ShadowedRectangle {
		    Layout.preferredWidth: Kirigami.Units.gridUnit * 3
		    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
		    radius: Kirigami.Units.smallSpacing
		    color: Kirigami.Theme.backgroundColor

                Image {
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: root.artUrl !== "" && status === Image.Ready
                }

                // 没封面时显示的图标
                Kirigami.Icon {
			anchors.centerIn: parent
			width: 32; height: 32
			source: "audio-x-generic"
			visible: root.artUrl === ""
		}
            }

            // 文本信息
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                Kirigami.Heading {
			text: root.title
			level: 2
			Layout.fillWidth: true
			elide: Text.ElideRight
			type: Kirigami.Heading.Type.Primary
		}
                Label {
                    text: root.artist
                    color: "#aaa"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    Layout.fillWidth: true
                    opacity: 0.7
                    elide: Text.ElideRight
                }
            }
        }
        ProgressBar {
		Layout.fillWidth: true
		value: (isActive && player.length > 0) ? (player.position / player.length) : 0
		visible: isActive && player.length > 0
	}
        // --- 控制按钮 (上一曲/暂停/下一曲) ---
            RowLayout {
                anchors.centerIn: parent
                spacing: Kirigami.Units.gridUnit

                // 1. 上一曲
                MouseArea {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if(root.player) root.player.previous()

                    Kirigami.Icon {
                        id: prevIcon
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: "media-skip-backward-symbolic"
			color: Kirigami.Theme.textColor
                    }
                }

                // 2. 播放/暂停
                MouseArea {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if(root.player) root.player.togglePlaying()

                    Kirigami.Icon {
                        id: playPauseIcon
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        source: (root.player && root.player.isPlaying) ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
			color: Kirigami.Theme.textColor
                    }
                }

                // 3. 下一曲
                MouseArea {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if(root.player) root.player.next()

                    Kirigami.Icon {
                        id: nextIcon
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        color: Kirigami.Theme.textColor
                        source:  "media-skip-forward-symbolic"
                    }
                }
            }
        }
}
