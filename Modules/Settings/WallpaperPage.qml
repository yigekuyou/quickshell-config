import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import com.github.captsilver.wallpaperEngineKde

// ============================================================================
// 壁纸页。版式照 Plasma 的 Wallpaper Engine 壁纸插件
// (/usr/share/plasma/wallpapers/com.github.captsilver.wallpaperEngineKde)：
//   顶部 TabBar（壁纸 / 播放 / Web） + StackLayout
//   壁纸页：搜索框 + 缩略图网格（选中打绿勾，悬停播放 GIF）
//   播放页：分组表单（帧率 / 速度 / 音量 + 静音 / 暂停 + 视频 / 场景选项）
//   Web 页：壁纸自己的 project.json 选项，按壁纸分别存 settings/wallpaper/<id>.json
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



    // ==================== Web 壁纸选项定义 ====================
    // 键 -> {type, text, tip, value, order}；值本身由 WallpaperPath 管
    //（project.json 默认值 + settings/wallpaper/<id>.json 的覆盖值）。
    // 直接用 WallpaperPath 已经解析好的 project.json：同一个文件不再读第二遍，
    // 换壁纸时 UI 与渲染端读到的永远是同一份内容。
    readonly property var webPropertiesDef: {
        const out = {};
        const project = WallpaperPath.project || ({});
        const props = project.general ? project.general.properties : null;
        if (props) {
            for (const key in props) {
                const p = props[key] || {};
                out[key] = {
                    type: p.type !== undefined ? String(p.type) : "string",
                    text: p.text !== undefined ? String(p.text) : key,
                    tip: p.tip !== undefined ? String(p.tip) : "",
                    value: p.value,
                    order: p.order !== undefined ? Number(p.order) : 0
                };
            }
        }
        return out;
    }

    // 选项键列表：按 project.json 里的 order 排（和 WE 自己的设置面板一致），
    // 没有 order 的排在后面。返回普通数组，Repeater 换壁纸时整体重建一次即可。
    function webPropertyKeys(): var {
        const defs = root.webPropertiesDef;
        if (!defs || typeof defs !== "object")
            return [];
        return Object.keys(defs).sort((a, b) => {
            const oa = defs[a] && defs[a].order !== undefined ? Number(defs[a].order) : 100000;
            const ob = defs[b] && defs[b].order !== undefined ? Number(defs[b].order) : 100000;
            return oa - ob;
        });
    }

    // ==================== 分页 ====================
    // 标签栏：两枚文字标签 + 选中下划线（Plasma 配置页的样子）。
    // 只换外观，点击/键盘左右切换仍由 Controls 的 TabBar 负责。
    TabBar {
        id: tabs

        // 只按内容宽度排布（不拉满），靠左；下面的分隔线单独画一条，
        // 否则 TabBar 拉满时 Controls 会把每个标签均分到整行宽度
        Layout.alignment: Qt.AlignLeft
        leftPadding: 0
        rightPadding: 0
        spacing: Kirigami.Units.largeSpacing
        background: null

        Repeater {
            model: [qsTr("壁纸"), qsTr("播放"), qsTr("Web")]

            delegate: TabButton {
                id: tabButton

                text: modelData
                implicitHeight: Kirigami.Units.gridUnit * 2
                implicitWidth: tabLabel.implicitWidth + Kirigami.Units.largeSpacing * 2
                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0

                contentItem: Label {
                    id: tabLabel

                    text: tabButton.text
                    font.weight: tabButton.checked ? Font.DemiBold : Font.Normal
                    color: tabButton.checked
                        ? Kirigami.Theme.highlightColor
                        : (tabButton.hovered ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    Behavior on color {
                        ColorAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                }

                background: Rectangle {
                    color: "transparent"

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        height: 2
                        radius: 1
                        color: tabButton.checked ? Kirigami.Theme.highlightColor : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }
                    }
                }
            }
        }
    }

    // 标签栏下的整行分隔线
    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: -Kirigami.Units.smallSpacing
        implicitHeight: 1
        color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
    }

    StackLayout {
        Layout.fillWidth: true
        // 跟着窗口拉伸；以前写死 gridUnit * 29，窗口矮的时候网格会被裁掉
        Layout.fillHeight: true
        currentIndex: tabs.currentIndex

        // ==================== 一、壁纸库 ====================
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            // 搜索 + 计数 + 重新扫描（SearchField 自带 Ctrl+F 与清空按钮）
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.SearchField {
                    id: search

                    Layout.fillWidth: true
                    placeholderText: qsTr("搜索壁纸")
                    onTextChanged: root.query = text
                }

                Label {
                    text: WallpaperLibrary.scanning
                        ? qsTr("扫描中…")
                        : qsTr("%1 / %2").arg(root.filtered.length).arg(WallpaperLibrary.items.length)
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }

                ToolButton {
                    id: refreshButton

                    enabled: !WallpaperLibrary.scanning
                    onClicked: WallpaperLibrary.refresh()
                    Accessible.name: qsTr("重新扫描")
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("重新扫描")
                    ToolTip.delay: Kirigami.Units.toolTipDelay

                    contentItem: Kirigami.Icon {
                        source: "view-refresh"
                        color: refreshButton.enabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
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

            // 类型筛选用 Kirigami.Chip：文档里 Chip 就是拿来表示“属性 / 筛选条件”
            // 的一排小元素，比下拉框少一次点击，当前筛的是什么也一眼能看到。
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: [
                        {
                            "key": "",
                            "label": qsTr("全部")
                        },
                        {
                            "key": "scene",
                            "label": qsTr("场景")
                        },
                        {
                            "key": "video",
                            "label": qsTr("视频")
                        },
                        {
                            "key": "web",
                            "label": qsTr("Web")
                        }
                    ]

                    Kirigami.Chip {
                        id: typeChip

                        required property var modelData

                        // closable: false 时 Chip 自动变成可勾选（checkable）
                        text: modelData.label
                        closable: false
                        // 点已选中的 Chip 时 AbstractButton 会把它反勾掉，
                        // 这里按页面状态重新断言一次（Binding 是元素形式，
                        // 直接赋值不会把它顶掉）。
                        onClicked: {
                            root.typeKey = typeChip.modelData.key;
                            typeChip.checked = root.typeKey === typeChip.modelData.key;
                        }

                        // 选中态跟着页面状态走。这里必须用 Binding：直接写
                        // checked: ... 的话，点一下 Chip 就会把绑定顶掉，
                        // 之后切别的 Chip 它也不再跟着变了。
                        Binding on checked {
                            value: root.typeKey === typeChip.modelData.key
                            restoreMode: Binding.RestoreBindingOrValue
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            // 扫描出错用 InlineMessage（Kirigami 标准的行内提示）放在网格上方，
            // 不用滚到最底下才看得见
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: WallpaperLibrary.error !== ""
                type: Kirigami.MessageType.Error
                text: WallpaperLibrary.error
            }

            // 缩略图网格：卡片用 Kirigami.AbstractCard（主题化背景 + 悬停/按下
            // 反馈 + 圆角都由 Kirigami 负责），虚拟化和键盘导航交给 GridView。
            // 文档里 CardsLayout / CardsListView 适合“少量卡片”，几十上百张时
            // 用 GridView + 卡片 delegate。
            GridView {
                id: grid

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.filtered
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 800
                reuseItems: true
                visible: root.filtered.length > 0

                // 响应式列数：每张卡片至少 11 个 gridUnit 宽
                readonly property int columns: Math.max(2, Math.min(5, Math.floor(width / (Kirigami.Units.gridUnit * 11))))
                readonly property real cardWidth: Math.floor(width / columns) - Kirigami.Units.largeSpacing
                readonly property real thumbHeight: Math.round((cardWidth - 2 * Kirigami.Units.smallSpacing) * 9 / 16)
                readonly property real cardHeight: Math.round(thumbHeight + 2 * Kirigami.Units.smallSpacing + Kirigami.Units.gridUnit * 2.2)

                cellWidth: Math.floor(width / columns)
                cellHeight: cardHeight + Kirigami.Units.largeSpacing

                ScrollBar.vertical: ScrollBar {
                    policy: grid.contentHeight > grid.height + 1 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                delegate: Kirigami.AbstractCard {
                    id: card

                    required property var modelData

                    readonly property bool isCurrent: card.modelData.id === WallpaperPath.wallpaperId
                    readonly property bool isGif: card.modelData.isGif === true
                    readonly property bool isHovered: cardHover.hovered

                    width: grid.cardWidth
                    height: grid.cardHeight
                    padding: 0
                    showClickFeedback: true

                    Accessible.role: Accessible.Button
                    Accessible.name: card.modelData.title
                    Accessible.description: root.typeLabel(card.modelData.type)

                    onClicked: WallpaperPath.wallpaperId = card.modelData.id

                    contentItem: ColumnLayout {
                        spacing: 0

                        // ---- 缩略图 ----
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: Kirigami.Units.smallSpacing
                            Layout.rightMargin: Kirigami.Units.smallSpacing
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            Layout.preferredHeight: grid.thumbHeight

                            radius: Kirigami.Units.cornerRadius
                            color: Kirigami.Theme.alternateBackgroundColor
                            clip: true

                            Image {
                                id: thumb

                                anchors.fill: parent
                                source: card.modelData.preview
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                sourceSize.width: 320
                                visible: !(card.isGif && gif.playing)
                            }

                            // GIF 只在悬停时解码，避免几十个动图同时跑
                            AnimatedImage {
                                id: gif

                                anchors.fill: parent
                                source: (card.isGif && card.isHovered && Settings.wallpaper.animatedPreview) ? card.modelData.preview : ""
                                fillMode: Image.PreserveAspectCrop
                                playing: card.isHovered
                                cache: false
                            }

                            // 悬停时压暗一点，暗示可点
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0, 0, 0, 0.25)
                                opacity: card.isHovered && !card.isCurrent ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Kirigami.Units.shortDuration
                                    }
                                }
                            }

                            // 选中标记：绿底白勾
                            Rectangle {
                                visible: card.isCurrent
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
                                    text: root.typeLabel(card.modelData.type)
                                    font: Kirigami.Theme.smallFont
                                    color: "white"
                                }
                            }
                        }

                        // ---- 标题 + 类型 ----
                        Column {
                            Layout.fillWidth: true
                            Layout.leftMargin: Kirigami.Units.smallSpacing
                            Layout.rightMargin: Kirigami.Units.smallSpacing
                            Layout.bottomMargin: Kirigami.Units.smallSpacing
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.2
                            spacing: 0

                            Label {
                                width: parent.width
                                text: card.modelData.title
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.weight: card.isCurrent ? Font.DemiBold : Font.Normal
                                color: card.isCurrent ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                            }

                            Label {
                                width: parent.width
                                text: root.typeLabel(card.modelData.type)
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font: Kirigami.Theme.smallFont
                                color: Kirigami.Theme.disabledTextColor
                            }
                        }
                    }

                    HoverHandler {
                        id: cardHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    // 选中边框叠在卡片最上层（AbstractCard 的背景不对外开放，
                    // 不用自己去画背景，避免和主题/圆角打架）
                    Rectangle {
                        anchors.fill: parent
                        radius: Kirigami.Units.cornerRadius
                        color: "transparent"
                        visible: card.isCurrent
                        border.width: 2
                        border.color: Kirigami.Theme.highlightColor
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

                helpfulAction: Kirigami.Action {
                    text: qsTr("重新扫描")
                    icon.name: "view-refresh"
                    enabled: !WallpaperLibrary.scanning
                    onTriggered: WallpaperLibrary.refresh()
                }
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

            // StackLayout 只按 Layout 附加属性给当前页分配尺寸：
            // 少了这两个，播放页永远是 0×0（切过去也是空的/挤成一条）
            Layout.fillWidth: true
            Layout.fillHeight: true
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
                        wired: true
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
                        wired: true
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
                        wired: true
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
                        wired: true
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
                        wired: true
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
                        wired: true
                        description: qsTr("音频响应型壁纸跟随全部系统声音，而不是只跟壁纸自带音乐")
                        switchOn: Settings.wallpaper.systemAudioCapture
                        onSwitchToggled: on => Settings.wallpaper.systemAudioCapture = on
                    }

                    SettingsSwitchRow {
                        text: qsTr("鼠标输入")
                        iconName: "input-mouse"
                        wired: true
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
                        wired: true
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
                        wired: true
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
        // ==================== 三、Web 选项 ====================
        Flickable {
            id: webFlick

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: webCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: webCol

                width: webFlick.width
                spacing: Kirigami.Units.largeSpacing

                // ---------------- Web Option ----------------
                // 选项定义来自壁纸自己的 project.json（general.properties），
                // 用户改过的值按壁纸分别存 settings/wallpaper/<壁纸 id>.json，
                // 没改过的继续用 project.json 的默认值。
                SettingsGroup {
                    title: qsTr("Web 选项")
                    visible: root.current && root.current.type === "web"

                    Label {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.smallSpacing
                        wrapMode: Text.WordWrap
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                        text: qsTr("选项来自壁纸的 project.json，改动按壁纸分别保存在 settings/wallpaper/壁纸 id.json，切换壁纸不会互相覆盖。")
                    }

                    Label {
                        Layout.fillWidth: true
                        Layout.margins: Kirigami.Units.smallSpacing
                        wrapMode: Text.WordWrap
                        visible: root.webPropertyKeys().length === 0
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                        text: qsTr("这张壁纸没有可配置的选项。")
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Repeater {
                            model: root.webPropertyKeys()

                            // 每行都是布局项：宽度/高度全交给 ColumnLayout / RowLayout 算，
                            // 不再自己绑 width / implicitHeight —— 模型从 0 涨到上百项时
                            // 也不会出现宽度还是 0、控件挤成一团的情况。
                            delegate: ColumnLayout {
                                id: propItem

                                Layout.fillWidth: true
                                spacing: 0

                                // 壁纸换掉时 webPropertiesDef 会是空的，用 key 自己兜底
                                property string key: modelData
                                property var propDef: (root.webPropertiesDef || {})[propItem.key]
                                readonly property string propType: propDef && propDef.type ? String(propDef.type) : "string"
                                readonly property string propText: propDef && propDef.text ? String(propDef.text) : propItem.key
                                readonly property string propTip: propDef && propDef.tip ? String(propDef.tip) : ""
                                readonly property var propValue: WallpaperPath.webProperties[propItem.key]

                                function store(v) {
                                    const cur = WallpaperPath.webProperties[propItem.key];
                                    // 值没变就不写：控件被销毁时也会发 editingFinished，
                                    // 不能因此给这张壁纸凭空建一份覆盖文件
                                    if (cur === v)
                                        return;
                                    WallpaperPath.setWebProperty(propItem.key, v);
                                }


                                Loader {
                                    id: propLoader
                                    Layout.fillWidth: true
                                    // Loader 会把加载出来的项撑到自己的大小，
                                    // 所以行内的 RowLayout 只管排布，不用管尺寸
                                    sourceComponent: {
                                        if (propItem.propType === "bool")
                                            return boolComponent;
                                        if (propItem.propType === "color")
                                            return colorComponent;
                                        if (propItem.propType === "file")
                                            return fileComponent;
                                        if (propItem.propType === "number" || propItem.propType === "int"
                                                || propItem.propType === "slider")
                                            return numberComponent;
                                        return textComponent;
                                    }
                                }

                                // 布尔：直接用标准设置行，悬停/无障碍都由 Kirigami 负责
                                Component {
                                    id: boolComponent

                                    SettingsSwitchRow {
                                        text: propItem.propText
                                        description: propItem.propTip
                                        switchOn: propItem.propValue === true
                                        onSwitchToggled: on => propItem.store(on)
                                    }
                                }

                                // 颜色（十六进制字符串）
                                Component {
                                    id: colorComponent

                                    SettingsFieldRow {
                                        label: propItem.propText
                                        description: propItem.propTip

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Kirigami.Units.smallSpacing

                                            Rectangle {
                                                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.2
                                                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.2
                                                Layout.alignment: Qt.AlignVCenter
                                                radius: height / 4
                                                color: String(propItem.propValue || "#000000")
                                                border.width: 1
                                                border.color: Kirigami.Theme.disabledTextColor
                                            }

                                            TextField {
                                                Layout.fillWidth: true
                                                Layout.minimumWidth: Kirigami.Units.gridUnit * 6
                                                text: String(propItem.propValue || "")
                                                placeholderText: qsTr("十六进制颜色，如 #1e90ff")
                                                onEditingFinished: propItem.store(text)
                                            }
                                        }
                                    }
                                }

                                // 文本
                                Component {
                                    id: textComponent

                                    SettingsFieldRow {
                                        label: propItem.propText
                                        description: propItem.propTip

                                        TextField {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: Kirigami.Units.gridUnit * 6
                                            text: propItem.propValue !== undefined ? String(propItem.propValue) : ""
                                            onEditingFinished: propItem.store(text)
                                        }
                                    }
                                }

                                // 文件（壁纸目录内的相对路径）
                                Component {
                                    id: fileComponent

                                    SettingsFieldRow {
                                        label: propItem.propText
                                        description: propItem.propTip

                                        TextField {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: Kirigami.Units.gridUnit * 6
                                            text: propItem.propValue !== undefined ? String(propItem.propValue) : ""
                                            placeholderText: qsTr("壁纸目录内的文件路径")
                                            onEditingFinished: propItem.store(text)
                                        }
                                    }
                                }

                                // 数字（number / int / slider）
                                Component {
                                    id: numberComponent

                                    SettingsFieldRow {
                                        label: propItem.propText
                                        description: propItem.propTip

                                        TextField {
                                            id: numberField
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: Kirigami.Units.gridUnit * 6
                                            text: propItem.propValue !== undefined ? String(propItem.propValue) : ""
                                            placeholderText: propItem.propType === "int" ? qsTr("整数") : qsTr("数字")
                                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                                            onEditingFinished: {
                                                const n = parseFloat(text);
                                                if (isNaN(n)) {
                                                    // 输入不是数字：还原成当前值
                                                    text = propItem.propValue !== undefined ? String(propItem.propValue) : "";
                                                    return;
                                                }
                                                propItem.store(propItem.propType === "int" ? Math.round(n) : n);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

    }
}