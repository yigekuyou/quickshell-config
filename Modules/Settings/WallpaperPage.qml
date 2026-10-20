import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// ============================================================================
// 壁纸页。版式照 Plasma 的 Wallpaper Engine 壁纸插件
// (/usr/share/plasma/wallpapers/com.github.captsilver.wallpaperEngineKde)：
//   顶部 TabBar（壁纸 / 播放） + StackLayout
//   壁纸页：搜索框 + 缩略图网格（选中打绿勾，悬停播放 GIF）
//   播放页：分组表单（帧率 / 速度 / 音量 + 静音 / 暂停）
//
// 渲染约束（见 Wallpaper/Load.qml）：
//   scene  -> 单独的 qs 进程，QSG_RHI_BACKEND=opengl（场景渲染器只有 GL 后端）
//   video  -> 主进程，Vulkan
//   web    -> 单独的 QtWebEngine 渲染进程（QS 本体无法加载 WebEngine）
// ============================================================================
SettingsPage {
    id: root

    title: qsTr("壁纸")
    icon: "preferences-desktop-wallpaper"

    // 当前壁纸条目（搜索/选中态都要用）
    readonly property var current: {
        const list = WallpaperLibrary.items;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === WallpaperPath.wallpaperId)
                return list[i];
        }
        return null;
    }

    // 搜索 + 类型过滤
    property string query: ""
    property string typeKey: ""     // "" | "scene" | "video" | "web"
    readonly property var filtered: {
        const list = WallpaperLibrary.items;
        const q = root.query.trim().toLowerCase();
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const it = list[i];
            if (root.typeKey !== "" && it.type !== root.typeKey)
                continue;
            if (q !== "") {
                const title = String(it.title || "").toLowerCase();
                if (title.indexOf(q) < 0 && String(it.id).indexOf(q) < 0)
                    continue;
            }
            out.push(it);
        }
        return out;
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

    Component.onCompleted: WallpaperLibrary.refresh()




    // ==================== 分页 ====================
    TabBar {
        id: tabs

        TabButton {
            text: qsTr("壁纸")
        }

        TabButton {
            text: qsTr("播放")
        }
    }

    StackLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 29
        currentIndex: tabs.currentIndex

        // ==================== 一、壁纸库 ====================
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.SearchField {
                    id: search

                    Layout.fillWidth: true
                    placeholderText: qsTr("搜索壁纸")
                    onTextChanged: root.query = text
                }

                ComboBox {
                    id: typeFilter

                    Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                    model: [qsTr("全部类型"), qsTr("场景"), qsTr("视频"), qsTr("Web")]
                    onActivated: index => root.typeKey = ["", "scene", "video", "web"][index]
                }

                Label {
                    text: WallpaperLibrary.scanning
                        ? qsTr("扫描中…")
                        : qsTr("%1 / %2").arg(root.filtered.length).arg(WallpaperLibrary.items.length)
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    color: Kirigami.Theme.disabledTextColor
                }

                ToolButton {
                    enabled: !WallpaperLibrary.scanning
                    onClicked: WallpaperLibrary.refresh()
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("重新扫描")
                    ToolTip.delay: Kirigami.Units.toolTipDelay

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

            GridView {
                id: grid

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: width / 3
                cellHeight: Math.round(cellWidth * 0.56) + Kirigami.Units.gridUnit * 1.6
                model: root.filtered
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 600
                reuseItems: true

                ScrollBar.vertical: ScrollBar {
                    policy: grid.contentHeight > grid.height + 1 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                delegate: Item {
                    id: cell

                    required property var modelData

                    readonly property bool isCurrent: cell.modelData.id === WallpaperPath.wallpaperId
                    readonly property bool isHovered: cellHover.hovered

                    width: grid.cellWidth
                    height: grid.cellHeight

                    // ---- 缩略图 ----
                    Rectangle {
                        id: frame

                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: Kirigami.Units.smallSpacing
                        }
                        height: Math.round(cell.width * 0.56) - Kirigami.Units.smallSpacing
                        radius: Kirigami.Units.smallSpacing
                        color: Kirigami.Theme.alternateBackgroundColor
                        border.width: cell.isCurrent ? 2 : 1
                        border.color: cell.isCurrent
                            ? Kirigami.Theme.highlightColor
                            : Qt.alpha(Kirigami.Theme.textColor, cell.isHovered ? 0.3 : 0.12)
                        clip: true

                        Image {
                            id: thumb

                            anchors.fill: parent
                            anchors.margins: frame.border.width
                            source: cell.modelData.preview
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 320
                            visible: !(cell.modelData.isGif && gif.playing)
                        }

                        // GIF 只在悬停时解码，避免几十个动图同时跑
                        AnimatedImage {
                            id: gif

                            anchors.fill: thumb
                            source: (cell.modelData.isGif && cell.isHovered && Settings.wallpaper.animatedPreview) ? cell.modelData.preview : ""
                            fillMode: Image.PreserveAspectCrop
                            playing: cell.isHovered
                            cache: false
                        }

                        // 悬停时压暗一点，暗示可点
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, 0.25)
                            opacity: cell.isHovered && !cell.isCurrent ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                        }

                        // 选中标记：绿底白勾（跟 Plasma 壁纸对话框一样）
                        Rectangle {
                            visible: cell.isCurrent
                            anchors {
                                top: parent.top
                                right: parent.right
                                margins: Kirigami.Units.smallSpacing
                            }
                            implicitWidth: Kirigami.Units.gridUnit * 1.2
                            implicitHeight: implicitWidth
                            radius: width / 2
                            color: Kirigami.Theme.positiveTextColor
                            border.width: 1
                            border.color: Qt.rgba(0, 0, 0, 0.45)

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                source: "emblem-ok-symbolic"
                                color: "white"
                                implicitWidth: parent.width * 0.65
                                implicitHeight: implicitWidth
                            }
                        }

                        // 类型角标
                        Rectangle {
                            anchors {
                                top: parent.top
                                left: parent.left
                                margins: Kirigami.Units.smallSpacing
                            }
                            implicitWidth: typeLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
                            implicitHeight: typeLabel.implicitHeight + 2
                            radius: 3
                            color: Qt.rgba(0, 0, 0, 0.55)

                            Label {
                                id: typeLabel

                                anchors.centerIn: parent
                                text: root.typeLabel(cell.modelData.type)
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                color: "white"
                            }
                        }
                    }

                    // ---- 标题（缩略图下方，两行内截断） ----
                    Label {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: frame.bottom
                            leftMargin: Kirigami.Units.smallSpacing + 2
                            rightMargin: Kirigami.Units.smallSpacing + 2
                            topMargin: 2
                        }
                        text: cell.modelData.title
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        font.weight: cell.isCurrent ? Font.DemiBold : Font.Normal
                        color: cell.isCurrent ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                    }

                    HoverHandler {
                        id: cellHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: WallpaperPath.wallpaperId = cell.modelData.id
                    }
                }
            }

            Kirigami.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !WallpaperLibrary.scanning && root.filtered.length === 0
                icon.name: "preferences-desktop-wallpaper"
                text: root.query !== "" ? qsTr("没有匹配的壁纸") : qsTr("没有找到壁纸")
                explanation: root.query !== ""
                    ? qsTr("换个关键词试试")
                    : (WallpaperLibrary.error !== ""
                        ? WallpaperLibrary.error
                        : qsTr("检查 Wallpaper Engine 创意工坊目录是否存在：%1").arg(WallpaperPath.workshopBase))
            }
        }

        // ==================== 二、播放 / 渲染 ====================
        // 分组、顺序、档位、默认值全部照 Plasma 的 Wallpaper Engine 插件
        // (/usr/share/plasma/wallpapers/com.github.captsilver.wallpaperEngineKde,
        //  contents/ui/page/SettingPage.qml)：Common / Video / Scene 三组。
        // wired: false 的是插件里有、但当前渲染器（scene 子进程 + mpv +
        // WebEngine）不消费的参数——按钮置灰，字段照样写进 settings.json。
        Flickable {
            id: playFlick

            clip: true
            contentWidth: width
            contentHeight: playCol.implicitHeight

            ColumnLayout {
                id: playCol
                width: playFlick.width
                spacing: Kirigami.Units.largeSpacing

                // 当前壁纸 + 播放/静音快捷开关
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: "preferences-desktop-wallpaper"
                        implicitWidth: Kirigami.Units.iconSizes.medium
                        implicitHeight: implicitWidth
                        color: Kirigami.Theme.highlightColor
                    }

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
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }

                    ToolButton {
                        checkable: true
                        checked: !WallpaperPath.paused
                        onClicked: WallpaperPath.paused = !WallpaperPath.paused
                        ToolTip.visible: hovered
                        ToolTip.text: checked ? qsTr("暂停") : qsTr("继续播放")
                        ToolTip.delay: Kirigami.Units.toolTipDelay

                        contentItem: Kirigami.Icon {
                            source: parent.checked ? "media-playback-pause" : "media-playback-start"
                            color: Kirigami.Theme.textColor
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: implicitWidth
                        }
                    }

                    ToolButton {
                        checkable: true
                        checked: WallpaperPath.muted
                        onClicked: WallpaperPath.muted = checked
                        ToolTip.visible: hovered
                        ToolTip.text: checked ? qsTr("取消静音") : qsTr("静音")
                        ToolTip.delay: Kirigami.Units.toolTipDelay

                        contentItem: Kirigami.Icon {
                            source: parent.checked ? "audio-volume-muted" : "audio-volume-high"
                            color: Kirigami.Theme.textColor
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: implicitWidth
                        }
                    }
                }

                // ---------------- Common Option ----------------
                SettingsGroup {
                    title: qsTr("通用选项")

                    SettingsComboRow {
                        text: qsTr("暂停")
                        iconName: "media-playback-pause"
                        description: qsTr("检测到指定窗口时自动暂停壁纸")
                        wired: false
                        model: [
                            { text: qsTr("焦点或最大化窗口"), value: 0 },
                            { text: qsTr("焦点窗口"), value: 1 },
                            { text: qsTr("最大化窗口"), value: 2 },
                            { text: qsTr("全屏"), value: 3 },
                            { text: qsTr("任意窗口"), value: 4 },
                            { text: qsTr("从不"), value: 5 }
                        ]
                        currentValue: Settings.wallpaper.pauseMode
                        onSelected: value => Settings.wallpaper.pauseMode = value
                    }

                    SettingsSwitchRow {
                        text: qsTr("只在当前屏幕检查窗口")
                        wired: false
                        switchOn: Settings.wallpaper.pauseFilterByScreen
                        onSwitchToggled: on => Settings.wallpaper.pauseFilterByScreen = on
                    }

                    SettingsSwitchRow {
                        text: qsTr("电池供电时暂停")
                        iconName: "battery-low"
                        wired: false
                        switchOn: Settings.wallpaper.pauseOnBattery
                        onSwitchToggled: on => Settings.wallpaper.pauseOnBattery = on
                    }

                    SettingsSliderRow {
                        text: qsTr("电量低于")
                        iconName: "battery-empty"
                        wired: false
                        from: 0
                        to: 100
                        stepSize: 1
                        value: Settings.wallpaper.pauseBatPercent
                        suffix: " %"
                        onMoved: value => Settings.wallpaper.pauseBatPercent = Math.round(value)
                    }

                    SettingsComboRow {
                        text: qsTr("锁屏时")
                        iconName: "system-lock-screen"
                        wired: false
                        model: [
                            { text: qsTr("继续运行"), value: 0 },
                            { text: qsTr("暂停（推荐）"), value: 1 }
                        ]
                        currentValue: Settings.wallpaper.screenSaverPolicy
                        onSelected: value => Settings.wallpaper.screenSaverPolicy = value
                    }

                    SettingsSwitchRow {
                        text: qsTr("记录暂停条件日志")
                        iconName: "text-x-generic"
                        wired: false
                        switchOn: Settings.wallpaper.pauseDebugLogging
                        onSwitchToggled: on => Settings.wallpaper.pauseDebugLogging = on
                    }

                    SettingsComboRow {
                        text: qsTr("渲染分辨率")
                        iconName: "video-display"
                        wired: false
                        description: qsTr("以更低分辨率绘制再放大：画面更软，GPU 开销大幅下降")
                        model: [
                            { text: qsTr("原生（100%）"), value: 100 },
                            { text: "75%", value: 75 },
                            { text: "50%", value: 50 },
                            { text: "25%", value: 25 }
                        ]
                        currentValue: Settings.wallpaper.renderScale
                        onSelected: value => Settings.wallpaper.renderScale = value
                    }

                    SettingsComboRow {
                        text: qsTr("抗锯齿")
                        iconName: "video-display"
                        wired: false
                        model: [
                            { text: qsTr("自动（推荐）"), value: 0 },
                            { text: qsTr("关"), value: 1 },
                            { text: "2x", value: 2 },
                            { text: "4x", value: 4 }
                        ]
                        currentValue: Settings.wallpaper.msaaMode
                        onSelected: value => Settings.wallpaper.msaaMode = value
                    }

                    SettingsComboRow {
                        text: qsTr("显示模式")
                        iconName: "transform-scale"
                        description: qsTr("画面比例与屏幕不一致时的处理方式（作用于 mpv 视频）")
                        model: [
                            { text: qsTr("保持宽高比"), value: 0 },
                            { text: qsTr("裁剪填充"), value: 1 },
                            { text: qsTr("拉伸填充"), value: 2 }
                        ]
                        currentValue: Settings.wallpaper.displayMode
                        onSelected: value => Settings.wallpaper.displayMode = value
                    }

                    SettingsSliderRow {
                        text: qsTr("恢复延迟")
                        iconName: "chronometer"
                        wired: false
                        description: qsTr("从暂停恢复播放前等待多久")
                        from: 1
                        to: 60000
                        stepSize: 1
                        value: Settings.wallpaper.resumeTime
                        suffix: " ms"
                        onMoved: value => Settings.wallpaper.resumeTime = Math.round(value)
                    }

                    SettingsSwitchRow {
                        text: qsTr("随机切换")
                        iconName: "media-playlist-shuffle"
                        wired: false
                        switchOn: Settings.wallpaper.randomizeWallpaper
                        onSwitchToggled: on => Settings.wallpaper.randomizeWallpaper = on
                    }

                    SettingsSliderRow {
                        text: qsTr("随机间隔")
                        iconName: "chronometer"
                        wired: false
                        from: 1
                        to: 60 * 24 * 30
                        stepSize: 1
                        value: Settings.wallpaper.switchTimer
                        suffix: " " + qsTr("分钟")
                        onMoved: value => Settings.wallpaper.switchTimer = Math.round(value)
                    }

                    SettingsSwitchRow {
                        text: qsTr("暂停时不随机")
                        wired: false
                        switchOn: Settings.wallpaper.noRandomWhilePaused
                        onSwitchToggled: on => Settings.wallpaper.noRandomWhilePaused = on
                    }

                    SettingsSwitchRow {
                        text: qsTr("切换壁纸时通知")
                        iconName: "notifications"
                        wired: false
                        switchOn: Settings.wallpaper.playlistNotify
                        onSwitchToggled: on => Settings.wallpaper.playlistNotify = on
                    }

                    SettingsSliderRow {
                        text: qsTr("播放速度")
                        iconName: "media-playback-speed-1"
                        description: qsTr("仅对视频壁纸生效")
                        from: 0.25
                        to: 2
                        stepSize: 0.05
                        decimals: 2
                        value: WallpaperPath.speed
                        suffix: "×"
                        onMoved: value => WallpaperPath.speed = Math.round(value * 20) / 20
                    }

                    SettingsSwitchRow {
                        text: qsTr("静音")
                        iconName: "audio-volume-muted"
                        switchOn: WallpaperPath.muted
                        onSwitchToggled: on => WallpaperPath.muted = on
                    }

                    SettingsSliderRow {
                        text: qsTr("音量")
                        iconName: "audio-volume-high"
                        from: 0
                        to: 100
                        stepSize: 1
                        value: Math.round(WallpaperPath.volume * 100)
                        suffix: "%"
                        onMoved: value => WallpaperPath.volume = Math.round(value) / 100
                    }

                    SettingsSwitchRow {
                        text: qsTr("捕获系统音频")
                        iconName: "audio-input-microphone"
                        wired: false
                        description: qsTr("音频响应型壁纸跟随全部系统声音，而不是只跟壁纸自带音乐")
                        switchOn: Settings.wallpaper.systemAudioCapture
                        onSwitchToggled: on => Settings.wallpaper.systemAudioCapture = on
                    }

                    SettingsSwitchRow {
                        text: qsTr("鼠标输入")
                        iconName: "input-mouse"
                        wired: false
                        switchOn: Settings.wallpaper.mouseInput
                        onSwitchToggled: on => Settings.wallpaper.mouseInput = on
                    }

                    SettingsSwitchRow {
                        text: qsTr("动态预览")
                        iconName: "image-gif"
                        description: qsTr("壁纸库里悬停缩略图时播放动图")
                        switchOn: Settings.wallpaper.animatedPreview
                        onSwitchToggled: on => Settings.wallpaper.animatedPreview = on
                    }

                    SettingsSwitchRow {
                        text: qsTr("详细日志")
                        iconName: "text-x-generic"
                        wired: false
                        switchOn: Settings.wallpaper.verboseLogging
                        onSwitchToggled: on => Settings.wallpaper.verboseLogging = on
                    }
                }

                // ---------------- Video Option ----------------
                SettingsGroup {
                    title: qsTr("视频选项")

                    SettingsComboRow {
                        text: qsTr("视频后端")
                        iconName: "preferences-media-playback"
                        wired: false
                        description: qsTr("QML 侧只用 mpv（Vulkan 硬解），QtMultimedia 仅作回退")
                        model: [
                            { text: "QtMultimedia", value: 0 },
                            { text: "mpv", value: 1 }
                        ]
                        currentValue: Settings.wallpaper.videoBackend
                        onSelected: value => Settings.wallpaper.videoBackend = value
                    }

                    SettingsSwitchRow {
                        text: qsTr("显示 mpv 统计")
                        iconName: "text-x-generic"
                        wired: false
                        switchOn: Settings.wallpaper.mpvStats
                        onSwitchToggled: on => Settings.wallpaper.mpvStats = on
                    }

                    SettingsSwitchRow {
                        text: qsTr("省电播放")
                        iconName: "battery-good"
                        wired: false
                        description: qsTr("更省的缩放、按视频自身帧率出帧")
                        switchOn: Settings.wallpaper.mpvPowerSaving
                        onSwitchToggled: on => Settings.wallpaper.mpvPowerSaving = on
                    }
                }

                // ---------------- Scene Option ----------------
                SettingsGroup {
                    title: qsTr("场景选项")

                    SettingsSliderRow {
                        text: qsTr("帧率")
                        iconName: "video-television"
                        description: qsTr("场景与 mpv 视频共用")
                        from: 5
                        to: 60
                        stepSize: 1
                        value: WallpaperPath.fps
                        suffix: " fps"
                        onMoved: value => WallpaperPath.fps = Math.round(value)
                    }

                    SettingsComboRow {
                        text: qsTr("呈现模式")
                        iconName: "video-display"
                        wired: false
                        model: [
                            { text: qsTr("自动"), value: 0 },
                            { text: qsTr("立即"), value: 1 },
                            { text: qsTr("垂直同步"), value: 2 },
                            { text: qsTr("先进先出"), value: 3 }
                        ]
                        currentValue: Settings.wallpaper.presentMode
                        onSelected: value => Settings.wallpaper.presentMode = value
                    }

                    SettingsSwitchRow {
                        text: qsTr("HDR 输出")
                        iconName: "video-display-brightness"
                        wired: false
                        switchOn: Settings.wallpaper.hdrOutput
                        onSwitchToggled: on => Settings.wallpaper.hdrOutput = on
                    }

                    SettingsSliderRow {
                        text: qsTr("缓存配额")
                        iconName: "drive-harddisk"
                        wired: false
                        description: qsTr("着色器 / 资源缓存占用上限")
                        from: 0
                        to: 100000
                        stepSize: 64
                        value: Settings.wallpaper.cacheQuotaMB
                        suffix: " MB"
                        onMoved: value => Settings.wallpaper.cacheQuotaMB = Math.round(value)
                    }
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    color: Kirigami.Theme.disabledTextColor
                    text: qsTr("灰色项是 Wallpaper Engine 插件的原始选项：当前渲染器（scene 子进程 / mpv / WebEngine）不消费这些参数，但字段已写进 settings.json，方便对齐与后续接入。Web 壁纸由独立进程渲染，帧率设置对它无效。")
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: playFlick.contentHeight > playFlick.height + 1 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }
        }
    }
    // 扫描出错时提示（有壁纸也照样提示，方便排查）
    Label {
        Layout.fillWidth: true
        visible: WallpaperLibrary.error !== ""
        text: WallpaperLibrary.error
        elide: Text.ElideRight
        maximumLineCount: 1
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        color: Kirigami.Theme.negativeTextColor
    }
}