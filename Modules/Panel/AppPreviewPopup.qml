import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import org.kde.kirigami as Kirigami
import qs.Config

// 底部面板任务栏的“应用预览浮窗”：悬停托盘图标时在面板上方弹出一张卡片，
// 用 ScreencopyView 直接抓取该应用窗口的实时画面（live）。
//
// 协议与混成器的限制（Hyprland 0.56 实测）：
//   * 抓窗口内容需要 hyprland-toplevel-export-v1（Hyprland 自家协议）；
//   * 画面由混成器在“窗口被渲染时”产生，只有被渲染过的窗口才给帧——
//     工作区里滚出屏幕的、最小化的、从不重绘的窗口可能很久才给一帧甚至不给，
//     会话失效时混成器会直接 failed。拿不到帧时退化为占位图标 +
//     “暂无预览画面”提示，并周期性重试；
//   * 首帧用 ignoreDamage 请求（强制该屏 damage 一次），已渲染的窗口一般在
//     500ms 内出第一帧（借悬停的 350ms 延迟预热，浮窗出现时帧往往已在路上）。
//
// 交互：
//   * 悬停图标约 350ms 后出现，从图标正上方往上展开；悬停瞬间就开始预热抓流；
//   * 鼠标从图标挪到浮窗上不会消失，点预览直接激活对应窗口;
//   * 隐藏后保留最后一帧，再次悬停同一应用时先出旧缩略图再追新帧；
//   * 鼠标同时离开图标与浮窗后才收起。
PopupWindow {
    id: root

    visible: false
    // 不抢焦点：浮窗的显示/隐藏完全由悬停状态管，点外面不主动收
    grabFocus: false
    color: "transparent"
    // 只有卡片本身拦截点击，浮窗的透明边缘把点击透传给下面的应用
    mask: Region {
        item: card
    }

    // ---- 对外接口（Panelapp 悬停时调用）----
    // 任务栏传进来的应用（TaskbarApps 的 appEntry：displayName / iconName / toplevels）
    property var app: null
    // 鼠标是否停在卡片上（决定隐藏计时器是否真的执行）
    property bool hoverOnPopup: false
    // 待显示的申请：showTimer 触发前可能已经换过好几次图标
    property var pendingApp: null
    property Item pendingAnchor: null

    // 上一次发起抓流的时间：captureSource 对同一对象再赋值会被 setCaptureSource
    // 的 early-return 跳过，用它区分“请求刚发出去、首帧在路上”和“该重开了”
    property real captureStartedAt: 0
    // 1.6s 内不出帧才允许显示“暂无预览画面”，免得正常出帧的过程中闪一下
    property bool hintAllowed: false
    readonly property bool showNoPreviewHint: visible && hintAllowed && !view.hasContent

    // ---- 尺寸 ----
    // 卡片宽度固定，预览高度按窗口画面比例走并封顶；
    // 首帧到达前按 16:9 兜底，免得预览区高度先涨后缩
    readonly property real cardWidth: Kirigami.Units.gridUnit * 20
    // 卡片外给阴影留的呼吸空间（浮窗窗口 = 卡片 + 四周留白）
    readonly property real shadowPad: Kirigami.Units.gridUnit * 0.7
    // 预览区贴到卡片左右/底边（只留顶部间距），宽度按卡片整宽算
    readonly property real previewFrameWidth: cardWidth - 2
    readonly property real previewMaxHeight: Kirigami.Units.gridUnit * 14
    readonly property real previewHeight: {
        if (view.hasContent && view.sourceSize.width > 0)
            return Math.min(previewMaxHeight, Math.round(previewFrameWidth * view.sourceSize.height / view.sourceSize.width));
        return Math.round(previewFrameWidth * 9 / 16);
    }

    implicitWidth: card.width + shadowPad * 2
    implicitHeight: card.height + shadowPad * 2

    // 锚点：图标顶边、水平居中、整体向上展开
    //（edges = 锚在锚矩形的哪条边上，gravity = 浮窗往哪个方向长）
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top

    // 挑要抓的窗口：优先当前激活的，其次第一个还活着（非空槽位）的 toplevel
    function pickToplevel(app) {
        if (!app)
            return null;
        const wins = app.toplevels;
        let fallback = null;
        for (let i = 0; i < wins.length; ++i) {
            const w = wins[i];
            // toplevels 里可能夹着关窗瞬间留下的空槽，别直接解引用
            if (!w)
                continue;
            if (w.activated)
                return w;
            if (!fallback)
                fallback = w;
        }
        return fallback;
    }

    readonly property var toplevel: pickToplevel(app)

    // 标题栏第二行：窗口标题；和应用名一样或没有时不显示
    readonly property string subtitle: toplevel ? (toplevel.title || "") : ""

    // 开始 / 重开抓流。
    //   * 换了目标窗口（或还没设过）：设新的 captureSource；
    //   * 目标相同且已有帧（含隐藏期间保留的旧帧）：留着用，重开会把帧丢掉；
    //   * 目标相同但请求刚发出去不到 1.2s（首帧在路上）：也留着——setCaptureSource
    //     对同一对象是 early-return，先 null 再设回去才能重开，但那会把在途请求废掉，
    //     等下一个周期（retryTimer / 重新悬停）再处理。
    function startCapture(app) {
        const t = pickToplevel(app);
        if (!t) {
            view.captureSource = null;
            return;
        }
        if (view.captureSource === t && view.hasContent)
            return;
        if (view.captureSource === t && Date.now() - root.captureStartedAt < 1200)
            return;
        view.captureSource = null;
        view.captureSource = t;
        root.captureStartedAt = Date.now();
    }

    // 显示防抖：扫过任务栏时不要一路弹浮窗
    Timer {
        id: showTimer
        interval: 350
        onTriggered: root.showNow()
    }
    // 隐藏延迟：给鼠标从图标挪到浮窗留出时间
    Timer {
        id: hideTimer
        interval: 250
        onTriggered: root.applyHide()
    }
    // 没拿到帧时周期性重问一次：会话被混成器停掉 / 窗口刚被重绘后能续上
    Timer {
        id: retryTimer
        interval: 2500
        repeat: true
        onTriggered: {
            if (root.visible && !view.hasContent && root.toplevel) {
                view.captureSource = null;
                view.captureSource = root.toplevel;
                root.captureStartedAt = Date.now();
            }
        }
    }
    // 1.6s 后还没帧，才允许显示“暂无预览画面”
    Timer {
        id: noPreviewTimer
        interval: 1600
        onTriggered: root.hintAllowed = true
    }

    Kirigami.ShadowedRectangle {
        id: card
        anchors.centerIn: parent
        width: root.cardWidth
        // ColumnLayout 的 implicitHeight 不含 anchors margin，顶部间距要自己加；
        // 之前漏掉这一项，布局高度比内容少 8px，ColumnLayout 只能压扁预览区（矮 9px），
        // 预览底部就露出一条卡片底色的“下巴”
        height: cardLayout.implicitHeight + Kirigami.Units.smallSpacing

        radius: Sizes.cornerRadius
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
        shadow.color: Qt.rgba(0, 0, 0, 0.35)
        shadow.size: Kirigami.Units.gridUnit * 0.6
        shadow.yOffset: Kirigami.Units.gridUnit * 0.15

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // ---- 标题栏：图标 + 应用名 + 窗口数 ----
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.15
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.15
                    Layout.alignment: Qt.AlignVCenter
                    source: root.app ? root.app.iconName : "application-x-executable"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    Kirigami.Heading {
                        Layout.fillWidth: true
                        level: 5
                        text: root.app ? root.app.displayName : ""
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.subtitle
                        visible: root.subtitle !== "" && root.subtitle !== (root.app ? root.app.displayName : "")
                        color: Kirigami.Theme.disabledTextColor
                        font.pointSize: Sizes.smallFontSize
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                // 多窗口角标
                Rectangle {
                    visible: root.app && root.app.toplevels.length > 1
                    Layout.preferredWidth: countLabel.implicitWidth + Kirigami.Units.smallSpacing * 1.5
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 0.85
                    Layout.alignment: Qt.AlignVCenter
                    radius: height / 2
                    color: Qt.alpha(Kirigami.Theme.highlightColor, 0.2)
                    border.width: 1
                    border.color: Qt.alpha(Kirigami.Theme.highlightColor, 0.35)

                    Label {
                        id: countLabel
                        anchors.centerIn: parent
                        text: root.app ? root.app.toplevels.length : 0
                        color: Kirigami.Theme.highlightColor
                        font.pointSize: Sizes.smallFontSize
                    }
                }
            }

            // ---- 预览区 ----
            // 贴住卡片左右和底边（上面留 smallSpacing 与标题栏分开），
            // 底部两角跟着卡片的圆角裁掉，否则会露出直角盖住卡片圆角。
            // 用 ClippingRectangle 而不是 Rectangle+clip：Qt 的 clip 只裁矩形，
            // 圆角要额外靠它把内容裁进圆角边框里。
            ClippingRectangle {
                id: previewFrame
                Layout.fillWidth: true
                Layout.preferredHeight: root.previewHeight
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: Sizes.cornerRadius - 1
                bottomRightRadius: Sizes.cornerRadius - 1
                color: Qt.alpha(Kirigami.Theme.textColor, 0.06)

                ScreencopyView {
                    id: view
                    anchors.fill: parent
                    live: true
                    paintCursor: false
                    // 没抓到画面时不绘制，让占位内容顶上
                    //（captureSource 由 startCapture/applyHide 命令式接管，这里不写绑定）
                    visible: hasContent
                }

                // 占位：首帧到来 / 抓流失败时显示一个大图标，免得预览区空着
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.gridUnit * 3
                    height: width
                    source: root.app ? root.app.iconName : "application-x-executable"
                    visible: !view.hasContent
                    opacity: 0.3
                }

                // 提示：窗口没被渲染（滚出屏幕 / 最小化 / 不重绘）时说明一下，
                // 不然用户会以为浮窗坏了
                Label {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: Kirigami.Units.smallSpacing
                    visible: root.showNoPreviewHint
                    text: "暂无预览画面"
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: Sizes.smallFontSize
                }
            }
        }

        // 悬停跟踪：鼠标在卡片上时按住隐藏计时器
        HoverHandler {
            id: popupHover
            onHoveredChanged: {
                root.hoverOnPopup = popupHover.hovered;
                if (popupHover.hovered)
                    hideTimer.stop();
                else
                    root.requestHide();
            }
        }

        // 点击预览：激活被预览的窗口
        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: {
                const w = root.toplevel;
                if (w) {
                    w.activate();
                    if (w.minimized)
                        w.minimized = false;
                }
                root.forceHide();
            }
        }
    }

    // 抓的窗口关掉了：收起（图标会被任务栏模型一起删掉，悬停状态不会再通知到）
    Connections {
        target: root.toplevel
        function onClosed() {
            root.requestHide()
        }
    }

    // ---- 对外函数 ----
    function requestShow(app, anchorItem) {
        hideTimer.stop();
        root.pendingApp = app;
        root.pendingAnchor = anchorItem;
        // 悬停的瞬间就先预热抓流，350ms 的显示延迟期间让首帧跑在路上
        root.startCapture(app);
        // 已经显示着（鼠标在图标间挪动）就直接换内容，否则延迟出现
        if (root.visible)
            root.showNow();
        else
            showTimer.start();
    }

    function requestHide() {
        showTimer.stop();
        if (!root.hoverOnPopup)
            hideTimer.start();
    }

    function forceHide() {
        showTimer.stop();
        hideTimer.stop();
        root.applyHide();
    }

    function showNow() {
        // 图标可能已经被销毁（应用关闭时 showTimer 还在跑），别把死对象喂给锚点
        if (!pendingApp || !pendingAnchor || !pendingAnchor.parent)
            return;
        root.app = pendingApp;
        root.hintAllowed = false;
        noPreviewTimer.start();
        retryTimer.start();
        // 锚定到图标：命令式赋值而不是绑定 —— 锚位置只在重新定位时算，
        // 响应式绑定会和定位互相触发（见 Widget/common/SlideWindow.qml 的教训）
        root.anchor.item = pendingAnchor;
        if (!root.visible)
            root.visible = true;
        else
            root.anchor.updateAnchor();

        // 预热过的会话（同一目标且刚发起）不要重开，免得把在途的首帧废掉；
        // 目标变了 / 早就该重开了才走 startCapture
        const t = pickToplevel(root.app);
        if (view.captureSource !== t)
            root.startCapture(root.app);
    }

    function applyHide() {
        root.visible = false;
        retryTimer.stop();
        noPreviewTimer.stop();
        root.app = null;
        root.pendingApp = null;
        root.pendingAnchor = null;
        // 故意不断开 captureSource：保留最后一帧，下次悬停同一应用时先出旧缩略图
        // 再追新帧；窗口真关掉时 ScreencopyView 的 onCaptureSourceDestroyed
        // 会自己把流清干净，root.toplevel 也会变成 null
    }
}
