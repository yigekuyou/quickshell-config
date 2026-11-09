import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Config
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import QtQuick.Effects
import qs.Modules.DynamicIsland.LyricsContent
import qs.Services

Kirigami.Card {
    id: mediaCard
    anchors.fill: parent

    background: Rectangle {
        color: "transparent"
        radius: Kirigami.Units.gridUnit
    }

    // 获取当前激活的 player 对象和 mprisData
    readonly property var currentPlayerObj: Lyrics.player || (Lyrics.playerManager && Lyrics.playerManager.count > 0 ? Lyrics.playerManager.objectAt(Lyrics.activeIndex) : null)
    readonly property var activeplayer: currentPlayerObj ? currentPlayerObj.mprisData : null
    readonly property var lyricsModel: currentPlayerObj ? currentPlayerObj.lyricsModel : null
    readonly property string playername: activeplayer ? (activeplayer.identity || activeplayer.busName || "") : ""
    readonly property string artUrl: (activeplayer && activeplayer.trackArtUrl) ? activeplayer.trackArtUrl : ""
    readonly property string title: (activeplayer && activeplayer.trackTitle) ? activeplayer.trackTitle : "No Media"
    readonly property string artist: (activeplayer && activeplayer.trackArtist) ? activeplayer.trackArtist : ""

    // 进度百分比 (0.0 ~ 1.0)
    property double progress: (activeplayer && activeplayer.length > 0 && activeplayer.position > 0) ? Math.min(activeplayer.position / activeplayer.length, 1.0) : 0

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

                Kirigami.ShadowedImage {
                    anchors.fill: parent
                    source: artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: artUrl !== "" && status === Image.Ready
                }

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

                RowLayout {
                    Layout.fillWidth: true

                    Kirigami.Heading {
                        text: title
                        level: 2
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        type: Kirigami.Heading.Type.Primary
                    }

                    // 右上角：播放器名称 + 下拉箭头，点击弹出播放器切换菜单
                    Item {
                        id: playerSwitchArea
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: playerSwitchRow.implicitWidth
                        implicitHeight: playerSwitchRow.implicitHeight

                        RowLayout {
                            id: playerSwitchRow
                            anchors.centerIn: parent
                            spacing: 2

                            Kirigami.Heading {
                                text: playername
                                level: 5
                                opacity: 0.7
                                elide: Text.ElideRight
                            }

                            Kirigami.Icon {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                Layout.alignment: Qt.AlignVCenter
                                source: "arrow-down-symbolic"
                                opacity: 0.7
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: playerMenu.open()
                            ToolTip.text: "切换播放器"
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 500
                        }

                        // 播放器切换菜单
                        Menu {
                            id: playerMenu
                            popupType: Popup.Window
                            x: playerSwitchArea.width - width
                            y: playerSwitchArea.height

                            Instantiator {
                                model: Lyrics.playerManager ? Lyrics.playerManager.count : 0

                                delegate: MenuItem {
                                    required property int index

                                    text: {
                                        const w = Lyrics.playerManager.objectAt(index)
                                        return w && w.mprisData ? (w.mprisData.identity || w.mprisData.busName || "") : ""
                                    }

                                    icon.name: {
                                        const w = Lyrics.playerManager.objectAt(index)
                                        return w === Lyrics.player ? "checkmark-symbolic" : ""
                                    }
                                    icon.width: Kirigami.Units.iconSizes.small
                                    icon.height: Kirigami.Units.iconSizes.small

                                    onTriggered: {
                                        if (index < Lyrics.playerManager.count) {
                                            Lyrics.player = Lyrics.playerManager.objectAt(index)
                                        }
                                    }
                                }

                                onObjectAdded: (index, object) => playerMenu.insertItem(index, object)
                                onObjectRemoved: (index, object) => playerMenu.removeItem(object)
                            }
                        }
                    }
                }

                Kirigami.Heading {
                    text: artist
                    level: 5
                    Layout.fillWidth: true
                    opacity: 0.7
                    elide: Text.ElideRight
                }

                Kirigami.Heading {
                    text: activeplayer ? (Qt.formatDateTime(new Date(Math.floor(activeplayer.position * 1000)), "mm:ss") + "/" + Qt.formatDateTime(new Date(Math.floor(activeplayer.length * 1000)), "mm:ss")) : "00:00/00:00"
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

        // --- 进度条 ---
        Item {
            id: progressBarContainer
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit

            Rectangle {
                id: trackBg
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Kirigami.Units.gridUnit / 3
                color: Qt.rgba(1, 1, 1, 0.1)
                radius: height / 2

                Rectangle {
                    id: progressFill
                    height: parent.height
                    radius: parent.radius
                    color: "white"
                    width: {
                        if (!activeplayer) return 0;
                        if (seekMa.pressed && activeplayer.canSeek) {
                            return Math.min(Math.max(0, seekMa.mouseX), trackBg.width);
                        }
                        return progress * trackBg.width;
                    }
                }

                Rectangle {
                    x: progressFill.width - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: Kirigami.Units.gridUnit
                    height: Kirigami.Units.gridUnit
                    radius: Kirigami.Units.gridUnit / 2
                    color: "white"
                    visible: seekMa.containsMouse || seekMa.pressed
                    scale: seekMa.pressed ? 1.2 : 1.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                }
            }

            MouseArea {
                id: seekMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: (activeplayer && activeplayer.canSeek) ? Qt.PointingHandCursor : Qt.ArrowCursor

                onClicked: {
                    if (activeplayer && activeplayer.canSeek) {
                        let pos = Math.min(Math.max(0, mouseX / trackBg.width), 1.0);
                        activeplayer.position = pos * activeplayer.length;
                    }
                }

                onReleased: {
                    if (activeplayer && activeplayer.canSeek) {
                        let pos = Math.min(Math.max(0, mouseX / trackBg.width), 1.0);
                        activeplayer.position = pos * activeplayer.length;
                    }
                }
            }
        }

        // --- 控制按钮 ---
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
                onClicked: if (activeplayer) activeplayer.previous()
                display: AbstractButton.IconOnly
                ToolTip.visible: hovered
                ToolTip.text: "上一首"
            }

            Button {
                flat: true
                icon.width: Kirigami.Units.gridUnit * 2
                icon.height: Kirigami.Units.gridUnit * 2
                icon.name: (activeplayer && activeplayer.isPlaying) ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                onClicked: if (activeplayer) activeplayer.togglePlaying()
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
                onClicked: if (activeplayer) activeplayer.next()
                display: AbstractButton.IconOnly
                ToolTip.visible: hovered
                ToolTip.text: "下一首"
            }
        }
    }
}