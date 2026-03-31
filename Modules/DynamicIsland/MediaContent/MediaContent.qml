import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import QtQuick.Effects
import qs.Modules.DynamicIsland.LyricsContent
import qs.Services

Kirigami.CardsListView {
    anchors.fill: parent
    spacing: parent.width / 5
    model: Lyrics.players
    orientation: ListView.Horizontal
    snapMode: ListView.SnapOneItem
    highlightRangeMode: ListView.StrictlyEnforceRange
    delegate: Kirigami.Card {
        background: Rectangle {
            color: "transparent"
            radius: Kirigami.Units.gridUnit

            // 如果你希望完全透明，直接用 color: "transparent"
        }
        property var activeplayer: Lyrics.playerManager.objectAt(index).mprisData
        property ListModel lyricsModel: Lyrics.playerManager.objectAt(index).lyricsModel

        property string artUrl: (activeplayer.trackArtUrl) ? activeplayer.trackArtUrl : ""
        property string title: (activeplayer.trackTitle) ? activeplayer.trackTitle : "No Media"
        property string artist: (activeplayer.trackArtist) ? activeplayer.trackArtist : ""

        // 进度百分比 (0.0 ~ 1.0)
	property double progress: (activeplayer.length > 0&&activeplayer.position>0) ? Math.min(activeplayer.position / activeplayer.length, 1.0): 0
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
                        source: artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: artUrl !== "" && status === Image.Ready
                    }

                    // 没封面时显示的图标
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.medium
                        height: Kirigami.Units.iconSizes.medium
                        source: "audio-x-generic"
                        visible: artUrl === "" && status !== Kirigami.Icon.Error
                    }
                }

                // 文本信息
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    Kirigami.Heading {
                        text: title
                        level: 2
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        type: Kirigami.Heading.Type.Primary
                    }
                    Kirigami.Heading {
                        text: artist
                        level: 5
                        Layout.fillWidth: true
                        opacity: 0.7
                        elide: Text.ElideRight
                    }
                        LyricsText {
                            player: activeplayer
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            implicitHeight: Kirigami.Units.gridUnit
                            implicitWidth: Kirigami.Units.gridUnit * 17
                            lyricsWTimes: lyricsModel
                        }
                }
            }
            Item {
                id: progressBarContainer
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit // 增加感应区域高度，方便手指/鼠标操作

                Rectangle {
                    id: trackBg
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: Kirigami.Units.gridUnit / 3
                    color: Qt.rgba(1, 1, 1, 0.1) // 半透明深色背景
                    radius: height / 2

                    // 进度填充 (白色条)
                    Rectangle {
                        id: progressFill
                        height: parent.height
                        radius: parent.radius
                        color: "white"
                        width: {
                            if (seekMa.pressed && activeplayer.canSeek) {
                                // 拖动时：强制跟随鼠标，限制在 0 到 总宽 之间
                                return Math.min(Math.max(0, seekMa.mouseX), trackBg.width);
                            }
                            // 播放时：根据百分比计算宽度
                            return progress * trackBg.width;
                        }
                    }

                    Rectangle {
                        x: progressFill.width - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: Kirigami.Units.gridUnit
                        height: Kirigami.Units.gridUnit
                        radius: Kirigami.Units.gridUnit/2
                        color: "white"
                        visible: seekMa.containsMouse || seekMa.pressed

                        // 给小圆点加个简单的阴影或缩放效果
                        scale: seekMa.pressed ? 1.2 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }
                    }
                }

                // 交互区域
                MouseArea {
                    id: seekMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: activeplayer.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onClicked: {
                        if (activeplayer.canSeek) {
                            // 计算点击位置占总长的比例
                            let pos = Math.min(Math.max(0, mouseX / trackBg.width), 1.0);
                            // 执行跳转： activeplayer.length * 比例
                            activeplayer.position = pos * activeplayer.length;
                        }
                    }

                    onPositionChanged: {
                        if (pressed && activeplayer.canSeek) {
                            // 实时拖动时不需要立即给 activeplayer 发送 position（防止性能损耗或爆音）
                            // 宽度会通过上面的 binding 自动更新
                        }
                    }

                    onReleased: {
                        if (activeplayer.canSeek) {
                            let pos = Math.min(Math.max(0, mouseX / trackBg.width), 1.0);
                            activeplayer.position = pos * activeplayer.length;
                        }
                    }
                }
            }
            // --- 控制按钮 (上一曲/暂停/下一曲) ---
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.gridUnit * 2
                Button {
                    implicitWidth: Kirigami.Units.gridUnit * 2
                    implicitHeight: Kirigami.Units.gridUnit * 2
                    icon.width: Kirigami.Units.gridUnit * 1.2
                    icon.height: Kirigami.Units.gridUnit * 1.2
                    flat: true
                    icon.name: "media-skip-backward-symbolic"
                    onClicked: if (activeplayer)
                        activeplayer.previous()
                    display: AbstractButton.IconOnly
                    ToolTip.visible: hovered
                    ToolTip.text: "上一首"
                }

                Button {
                    flat: true
                    // 增大播放按钮
                    icon.width: Kirigami.Units.gridUnit * 2
                    icon.height: Kirigami.Units.gridUnit * 2
                    icon.name: (activeplayer && activeplayer.isPlaying) ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                    onClicked: if (activeplayer)
                        activeplayer.togglePlaying()
                    display: AbstractButton.IconOnly
                    ToolTip.visible: hovered
                    ToolTip.text: (activeplayer && activeplayer.isPlaying) ? "暂停" : "播放"
                }

                Button {
                    implicitWidth: Kirigami.Units.gridUnit * 2
                    implicitHeight: Kirigami.Units.gridUnit * 2
                    icon.width: Kirigami.Units.gridUnit * 1.2
                    icon.height: Kirigami.Units.gridUnit * 1.2
                    flat: true
                    icon.name: "media-skip-forward-symbolic"
                    onClicked: if (activeplayer)
                        activeplayer.next()
                    display: AbstractButton.IconOnly
                    ToolTip.visible: hovered
                    ToolTip.text: "下一首"
                }
            }
            Item {
                id: pageindex
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit // 增加感应区域高度，方便手指/鼠标操作
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
