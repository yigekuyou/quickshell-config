import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Config
import qs.Services
import qs.Widget.common
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 壁纸面板：预览、切换 Wallpaper Engine 壁纸，以及播放参数（播放/暂停、帧率、速度、静音）。
// 结构与 NetworkWidget / NotificationWidget 一致：SlideWindow（圆角卡片 + 标题栏）+ 内容。
//
// 渲染约束（见 Wallpaper/Load.qml）：
//   scene  -> 单独的 qs 进程，QSG_RHI_BACKEND=opengl（场景渲染器只有 GL 后端）
//   video  -> 主进程，Vulkan
//   web    -> 单独的 QtWebEngine 渲染进程（QS 本体无法加载 WebEngine，见 Wallpaper/Web.qml）
SlideWindow {
    id: root
    title: qsTr("壁纸")
    icon: "preferences-desktop-wallpaper"
    windowHeight: 680

    signal closeRequested()

    Shortcut {
        sequence: "Escape"
        onActivated: root.closeRequested()
    }

    // 当前壁纸条目（切换后立即用于标题栏）
    readonly property var current: {
        const list = WallpaperLibrary.items;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === WallpaperPath.wallpaperId)
                return list[i];
        }
        return null;
    }

    function typeLabel(type) {
        switch (type) {
        case "scene":
            return qsTr("场景");
        case "video":
            return qsTr("视频");
        case "web":
            return qsTr("Web");
        default:
            return String(type || "?");
        }
    }

    function applyWallpaper(id) {
        WallpaperPath.wallpaperId = id;
    }

    Component.onCompleted: WallpaperLibrary.refresh()

    headerTools: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        ToolButton {
            enabled: !WallpaperLibrary.scanning
            onClicked: WallpaperLibrary.refresh()
            contentItem: Kirigami.Icon {
                source: "view-refresh"
                color: parent.enabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: implicitWidth
                RotationAnimation on rotation {
                    running: WallpaperLibrary.scanning
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }
        }
    }

    // ==================== 当前壁纸 + 播放参数 ====================
    FormCard.FormCard {
        Layout.fillWidth: true

        FormCard.AbstractFormDelegate {
            Layout.fillWidth: true
            background: null
            contentItem: ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Label {
                            Layout.fillWidth: true
                            text: root.current ? root.current.title : qsTr("未知壁纸")
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.weight: Font.DemiBold
                            color: Kirigami.Theme.textColor
                        }

                        Label {
                            Layout.fillWidth: true
                            text: qsTr("%1 · %2").arg(root.typeLabel(root.current ? root.current.type : WallpaperPath.wallpaperType)).arg(WallpaperPath.wallpaperId)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font: Kirigami.Theme.smallFont
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }

                    // 播放 / 暂停
                    ToolButton {
                        checkable: true
                        checked: !WallpaperPath.paused
                        onClicked: WallpaperPath.paused = !checked
                        contentItem: Kirigami.Icon {
                            source: parent.checked ? "media-playback-pause" : "media-playback-start"
                            color: Kirigami.Theme.textColor
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: implicitWidth
                        }
                    }

                    // 静音
                    ToolButton {
                        checkable: true
                        checked: WallpaperPath.muted
                        onClicked: WallpaperPath.muted = checked
                        contentItem: Kirigami.Icon {
                            source: parent.checked ? "audio-volume-muted" : "audio-volume-high"
                            color: Kirigami.Theme.textColor
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: implicitWidth
                        }
                    }
                }

                // ---- 帧率 ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Label {
                        text: qsTr("帧率")
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                    }

                    Slider {
                        id: fpsSlider
                        Layout.fillWidth: true
                        from: 10
                        to: 144
                        stepSize: 2
                        value: WallpaperPath.fps
                        onMoved: WallpaperPath.fps = Math.round(value * 2) / 2
                    }

                    Label {
                        text: Math.round(fpsSlider.value)
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.textColor
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // ---- 速度 ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Label {
                        text: qsTr("速度")
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                    }

                    Slider {
                        id: speedSlider
                        Layout.fillWidth: true
                        from: 0.25
                        to: 2.0
                        stepSize: 0.05
                        value: WallpaperPath.speed
                        onMoved: WallpaperPath.speed = Math.round(value * 20) / 20
                    }

                    Label {
                        text: speedSlider.value.toFixed(2) + "×"
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.textColor
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                        horizontalAlignment: Text.AlignRight
                    }
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    text: WallpaperPath.wallpaperType === "web"
                        ? qsTr("Web 壁纸由独立的 QtWebEngine 进程渲染（QS 本体无法加载 WebEngine），帧率设置对它无效。")
                        : qsTr("场景壁纸强制 OpenGL 渲染；视频 / Web 使用 Vulkan。帧率同时作用于场景与 mpv 视频。")
                }
            }
        }
    }

    // ==================== 壁纸列表标题 ====================
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing

        Label {
            text: qsTr("本地壁纸")
            font.weight: Font.DemiBold
            color: Kirigami.Theme.textColor
        }

        Item {
            Layout.fillWidth: true
        }

        Label {
            text: WallpaperLibrary.scanning ? qsTr("扫描中…") : qsTr("%1 张").arg(WallpaperLibrary.items.length)
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
    }

    // ==================== 缩略图网格 ====================
    GridView {
        id: grid
        Layout.fillWidth: true
        Layout.preferredHeight: 430
        clip: true
        cellWidth: width / 2
        cellHeight: Math.round(cellWidth * 0.64)
        model: WallpaperLibrary.items
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 400
        reuseItems: true

        ScrollBar.vertical: ScrollBar {
            policy: grid.contentHeight > grid.height + 1 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        }

        delegate: Item {
            id: cell
            required property var modelData

            width: grid.cellWidth
            height: grid.cellHeight

            readonly property bool isCurrent: modelData.id === WallpaperPath.wallpaperId
            readonly property bool hovered: hover.hovered

            Rectangle {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing / 2
                radius: Kirigami.Units.gridUnit * 0.4
                color: Qt.alpha(Kirigami.Theme.alternateBackgroundColor, 0.6)
                border.width: cell.isCurrent ? 2 : 1
                border.color: cell.isCurrent
                    ? Kirigami.Theme.highlightColor
                    : Qt.alpha(Kirigami.Theme.dividerColor, 0.5)
                clip: true

                Image {
                    id: thumb
                    anchors.fill: parent
                    anchors.margins: 2
                    source: cell.modelData.preview
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: 360
                    visible: !(cell.modelData.isGif && gif.playing)
                }

                // GIF 预览只在悬停时播放，避免 80 多个动图同时解码
                AnimatedImage {
                    id: gif
                    anchors.fill: thumb
                    source: (cell.modelData.isGif && cell.hovered) ? cell.modelData.preview : ""
                    fillMode: Image.PreserveAspectCrop
                    playing: cell.hovered
                    cache: false
                }

                // 底部信息条
                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: info.implicitHeight + Kirigami.Units.smallSpacing
                    color: Qt.rgba(0, 0, 0, 0.55)

                    RowLayout {
                        id: info
                        anchors {
                            fill: parent
                            leftMargin: Kirigami.Units.smallSpacing
                            rightMargin: Kirigami.Units.smallSpacing
                        }
                        spacing: Kirigami.Units.smallSpacing

                        Label {
                            Layout.fillWidth: true
                            text: cell.modelData.title
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font: Kirigami.Theme.smallFont
                            color: "white"
                        }

                        Label {
                            text: root.typeLabel(cell.modelData.type)
                            font: Kirigami.Theme.smallFont
                            color: "white"
                            opacity: 0.75
                        }
                    }
                }

                // 当前壁纸标记
                Kirigami.Icon {
                    visible: cell.isCurrent
                    anchors {
                        top: parent.top
                        right: parent.right
                        margins: Kirigami.Units.smallSpacing
                    }
                    source: "emblem-ok-symbolic"
                    color: Kirigami.Theme.positiveTextColor
                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                    implicitHeight: implicitWidth
                }
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: root.applyWallpaper(cell.modelData.id)
            }
        }
    }

    // ==================== 空状态 / 错误 ====================
    Kirigami.PlaceholderMessage {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        visible: !WallpaperLibrary.scanning && WallpaperLibrary.items.length === 0
        icon.name: "preferences-desktop-wallpaper"
        text: qsTr("没有找到壁纸")
        explanation: WallpaperLibrary.error !== ""
            ? WallpaperLibrary.error
            : qsTr("检查 Wallpaper Engine 创意工坊目录是否存在：%1").arg(WallpaperPath.workshopBase)
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        visible: WallpaperLibrary.error !== "" && WallpaperLibrary.items.length > 0
        text: WallpaperLibrary.error
        elide: Text.ElideRight
        maximumLineCount: 1
        font: Kirigami.Theme.smallFont
        color: Kirigami.Theme.negativeTextColor
    }
}
