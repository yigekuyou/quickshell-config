import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Services
import org.kde.kirigami as Kirigami

// 截图覆盖层（每块屏幕一个），交互仿常见截图工具：
//   按下 Print -> 桌面被冻结 -> 拖动框选 -> 工具栏选择「复制 / 保存 / 全屏 / 取消」
//
// 冻结画面来自 ScreencopyView 的单帧（live: false）。窗口刚出现时内容全部不可见，
// 等首帧到达后才显示界面——否则抓到的画面里会带上我们自己的遮罩与工具栏。
// 选区外的压暗只是四个矩形，选区本身是“挖空”的，因此用户看到的是冻结的原画面。
PanelWindow {
    id: overlay

    property var modelData // Quickshell.screens 中的一项（由 Variants 注入）
    property bool active: false     // 由 Screenshot.qml 统一开关
    property bool instant: false    // 立即全屏复制到剪贴板，不显示界面
    property string shotPath: "/tmp/quickshell-shot.png"
    property string cropPath: Directories.shotCropFile

    signal finished()
    signal failed()

    // ==================== 状态 ====================
    property bool captured: false   // 首帧已到，界面可以显示了
    property bool busy: false       // 正在裁切 / 写盘
    property rect sel: Qt.rect(0, 0, width, height)
    property real pressX: 0
    property real pressY: 0
    property string toast: ""
    readonly property color dimColor: Qt.rgba(0, 0, 0, 0.58)

    screen: modelData
    visible: active
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-screenshot"
    WlrLayershell.layer: WlrLayer.Overlay
    // 只有交互式界面才独占键盘；"直接整屏复制"模式不抢焦点，避免打断用户正在用的窗口
    WlrLayershell.keyboardFocus: (active && !instant) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // ==================== 生命周期 ====================
    onActiveChanged: {
        if (active) {
            captured = false;
            busy = false;
            toast = "";
            frameWidth = 0;
            frameHeight = 0;
            sel = Qt.rect(0, 0, width, height);
            // 关键：清掉上一轮裁切留在窗口左上角的那块旧图。
            // ScreencopyView 抓的是整个输出，包含我们自己的覆盖层窗口；
            // 如果不清，这块旧图会被一起抓进冻结帧，成为截图里「被糊住」的方块。
            cropper.reset();
            armTimer.restart();
        } else {
            armTimer.stop();
            closeTimer.stop();
            // 释放捕获源挪到本轮事件处理之后：销毁 screencopy 上下文会让合成器
            // 回收缓冲，不要在属性变更通知链里做（整屏复制的卡死曾停在这一步）
            Qt.callLater(function () {
                view.captureSource = null;
            });
            // 关掉界面时把 busy 一起复位，否则 saveWatchdog 会继续计时，
            // 每次截图 5 秒后都误报一次“导出超时”
            busy = false;
        }
    }

    onWidthChanged: if (!busy && !captured)
        sel = Qt.rect(0, 0, width, height)

    // 窗口先映射并渲染一帧，wayland 表面就绪后再连捕获源
    Timer {
        id: armTimer
        interval: 260
        onTriggered: {
            if (!overlay.active)
                return;
            view.captureSource = overlay.modelData;
            if (view.hasContent && view.sourceSize.width > 0)
                overlay.onFrame();
            else
                view.captureFrame();
        }
    }

    // 抓帧看门狗：3 秒还没画面就退出，避免留下一个不可见却独占键盘的全屏层
    Timer {
        id: captureWatchdog
        interval: 3000
        running: overlay.active && !overlay.captured
        onTriggered: {
            console.warn("[screenshot] 3 秒内没有收到画面，退出截图界面");
            overlay.failed();
        }
    }

    // 导出看门狗：裁切 / 写盘卡住时兜底关闭
    Timer {
        id: saveWatchdog
        interval: 5000
        running: overlay.busy
        onTriggered: {
            console.warn("[screenshot] 导出超时，退出截图界面");
            overlay.finished();
        }
    }

    function onFrame() {
        if (overlay.captured || !overlay.active)
            return;
        overlay.captured = true;
        overlay.sel = Qt.rect(0, 0, overlay.width, overlay.height);
        // 不要在这个回调里直接导出：onFrame 由 ScreencopyView 的帧事件触发，
        // 在帧回调里跑 grabToImage + 子进程会把事件循环卡死（整屏复制模式
        // 之前就这样把 shell 冻住）。挪到本轮事件处理结束之后再做。
        if (overlay.instant)
            Qt.callLater(() => overlay.confirm("copy"));
    }

    // ==================== 选区 ====================
    function updateSelection(mx, my) {
        const x = Math.min(overlay.pressX, mx);
        const y = Math.min(overlay.pressY, my);
        const x2 = Math.max(overlay.pressX, mx);
        const y2 = Math.max(overlay.pressY, my);
        const left = Math.max(0, Math.min(width - 1, x));
        const top = Math.max(0, Math.min(height - 1, y));
        const right = Math.max(0, Math.min(width, x2));
        const bottom = Math.max(0, Math.min(height, y2));
        overlay.sel = Qt.rect(left, top, Math.max(1, right - left), Math.max(1, bottom - top));
    }

    function selectAll() {
        overlay.sel = Qt.rect(0, 0, overlay.width, overlay.height);
    }

    // ==================== 动作 ====================
    function cancel() {
        overlay.finished();
    }

    function trigger(action) {
        if (action === "copy")
            overlay.confirm("copy");
        else if (action === "save")
            overlay.confirm("save");
        else if (action === "full")
            overlay.selectAll();
        else
            overlay.cancel();
    }

    // ==================== 导出：全程在 Qt 内部完成，不调用任何外部程序 ====================
    //   1. 冻结画面整屏抓一次（原生分辨率）→ shotPath
    //   2. 用 Image.sourceClipRect 把选区那一块单独解码出来，渲染成 1:1 的
    //      小 Item 再整块抓图（见下面的 cropper）
    //   3. ItemGrabResult.saveToFile() 落盘（Qt 6.2 起可直接传 URL）
    // 整屏复制（SHIFT+Print）不需要第 2 步：整屏抓图本身就是成品。
    property string pendingAction: "" // 已按剪贴板能力降级后的动作: "copy" / "save"
    property string pendingNote: ""
    property var pendingTarget: null // { dir, name, path }

    // 冻结帧真正写盘的像素尺寸。所有「逻辑坐标 <-> 像素」换算只认这两个值，
    // 不再用 view.sourceSize —— 那是合成器报的捕获缓冲尺寸，和 grabToImage
    // 真正抓出来的图像尺寸不保证一致（HiDPI、合成器换缓冲时就会差一行/一列），
    // 拿它去算 sourceClipRect 会越出图片边界，越界读到的就是缓冲里的残留内容。
    property int frameWidth: 0
    property int frameHeight: 0

    // 逻辑坐标的选区 -> 像素坐标，并钳制在 frameW x frameH 之内（含右/下边界）
    function regionFor(frameW, frameH) {
        const w = Math.max(1, frameW);
        const h = Math.max(1, frameH);
        const kx = w / Math.max(1, overlay.width);
        const ky = h / Math.max(1, overlay.height);
        const s = overlay.sel;
        const cx = Math.max(0, Math.min(w - 1, Math.round(s.x * kx)));
        const cy = Math.max(0, Math.min(h - 1, Math.round(s.y * ky)));
        const cw = Math.max(1, Math.min(w - cx, Math.round(s.width * kx)));
        const ch = Math.max(1, Math.min(h - cy, Math.round(s.height * ky)));
        return Qt.rect(cx, cy, cw, ch);
    }

    function regionIsFull(r) {
        return r.x === 0 && r.y === 0 && r.width >= overlay.frameWidth && r.height >= overlay.frameHeight;
    }

    function confirm(action) {
        if (overlay.busy || !overlay.captured)
            return;

        // 旧版 clipboard 模块用阻塞写把选区塞给请求方：图片一大，读写两端在同一
        // 个事件循环里互等，整个 shell 会冻住。模块没更新时把“复制”降级成存盘。
        const downgraded = action === "copy" && !ClipboardService.asyncSend;

        overlay.busy = true;
        overlay.pendingAction = downgraded ? "save" : action;
        overlay.pendingTarget = overlay.targetFile();
        overlay.pendingNote = downgraded ? qsTr("剪贴板模块待更新，已保存到 图片/Screenshots/" + overlay.pendingTarget.name) : "";
        overlay.frameWidth = 0;
        overlay.frameHeight = 0;

        // 1:1 抓冻结画面，不传 targetSize。
        // 以前传的是 Qt.size(sourceSize.width, sourceSize.height)：只要捕获缓冲的
        // 真实尺寸和 sourceSize 差一点（HiDPI、合成器换缓冲），Qt 就会按一个比缓冲
        // 更大的尺寸去重采样，越界读出来的那部分就是缓冲里的残留像素。不缩放就没有
        // 这种错位。（左上角那块方块的主要成因是上一轮裁切图残留在窗口里，
        // 见下面 cropper.reset()。）
        // grabToImage 的回调仍在抓图 / 渲染的同步上下文里：之后每一步（写盘、
        // 解码、抓图、发布剪贴板）都用 Qt.callLater 挪到本轮事件处理之后，
        // 否则容易在那里把事件循环锁死（保存后 shell 冻住就是这样来的）。
        view.grabToImage(function (res) {
            if (!res || !res.image || res.image.width < 2 || res.image.height < 2) {
                console.warn("[screenshot] grabToImage 返回空图像");
                Qt.callLater(() => overlay.abort());
                return;
            }
            if (!res.saveToFile("file://" + overlay.shotPath)) {
                console.warn("[screenshot] 临时文件写入失败: " + overlay.shotPath);
                Qt.callLater(() => overlay.abort());
                return;
            }
            // 以抓到的图像实际尺寸为准；它和合成器报的 sourceSize 不一致时留个痕迹
            overlay.frameWidth = res.image.width;
            overlay.frameHeight = res.image.height;
            if (view.sourceSize.width > 0 && (view.sourceSize.width !== overlay.frameWidth || view.sourceSize.height !== overlay.frameHeight))
                console.warn("[screenshot] 捕获缓冲尺寸不符: sourceSize=" + view.sourceSize.width + "x" + view.sourceSize.height + " frame=" + overlay.frameWidth + "x" + overlay.frameHeight);
            Qt.callLater(() => overlay.exportSelection());
        });
    }

    function exportSelection() {
        // 整屏 + 复制：shotPath 里的整屏抓图就是成品，不必再裁一遍
        if (overlay.pendingAction === "copy" && overlay.regionIsFull(overlay.regionFor(overlay.frameWidth, overlay.frameHeight))) {
            overlay.publish(overlay.shotPath);
            return;
        }
        cropper.start();
    }

    // 裁好的图像写盘之后执行动作。
    // 注意：saveToFile 必须在抓图回调里当场做完（见 cropper.grab）——
    // ItemGrabResult 是 grabToImage 的一次性产物，挪到下一轮事件循环
    // 可能已经被回收，image 就空了。
    function finishExport(dest) {
        if (overlay.pendingAction === "copy") {
            overlay.publish(dest);
        } else {
            overlay.done(overlay.pendingNote !== "" ? overlay.pendingNote : qsTr("已保存到 图片/Screenshots/" + overlay.pendingTarget.name));
        }
    }

    function publish(path) {
        if (overlay.instant) {
            // 整屏复制模式没有界面可看：先关掉覆盖层（释放 screencopy、窗口消失），
            // 再把成品交给剪贴板 —— 发布这一步历史上最容易卡住，别把覆盖层
            // 一起拖在里面，卡住也不会留一个抢焦点的全屏层。
            overlay.finished();
            Qt.callLater(() => ClipboardService.copyImage(path, "image/png"));
            return;
        }
        overlay.toast = qsTr("已复制到剪贴板");
        ClipboardService.copyImage(path, "image/png");
        closeTimer.restart();
    }

    function done(note) {
        if (overlay.instant)
            overlay.finished();
        else {
            overlay.toast = note;
            closeTimer.restart();
        }
    }

    function abort() {
        overlay.busy = false;
        if (overlay.instant)
            overlay.finished();
        else
            overlay.failed();
    }

    // 截图落盘位置： <XDG 图片目录>/Screenshots/Screenshot_<时间>.png
    // 走 StandardPaths 解析 XDG_PICTURES_DIR，不硬编码 "图片"。
    function targetFile() {
        const dir = Directories.screenshotsDir;
        const name = "Screenshot_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
        return {
            "dir": dir,
            "name": name,
            "path": dir + "/" + name
        };
    }

    Timer {
        id: closeTimer
        interval: 850
        onTriggered: overlay.finished()
    }

    // 所有可见内容放在一个 Item 里：既方便统一控制，也便于整层抓图调试
    Item {
        id: ui
        anchors.fill: parent

        // ==================== 冻结画面 ====================
        // 首帧到达前不绘制（此时也没有内容可绘制），到达后作为冻结背景。
        ScreencopyView {
            id: view
            anchors.fill: parent
            live: false
            paintCursor: false
            visible: overlay.captured
            opacity: overlay.captured ? 1 : 0

            onHasContentChanged: {
                if (hasContent && overlay.active && !overlay.captured)
                    overlay.onFrame();
            }
        }

        // ==================== 纯 Qt 裁切器 ====================
        // 只把选区那块单独解码（Image.sourceClipRect），渲染成 1:1 的小 Item 再
        // 整块抓图 —— 不用 magick，也不起任何子进程。
        // 放在冻结画面下面（z: -1）用户看不到它，但它必须是可见的：
        // grabToImage 对不可见 / 不在窗口里的 Item 只会给出空图。
        Item {
            id: cropper

            z: -1
            width: 1
            height: 1
            property rect region: Qt.rect(0, 0, 0, 0)
            property bool grabRequested: false

            // 清空一切可能被画到屏幕上的内容。
            // 这个 Item 在窗口里是「可见」的（grabToImage 对不可见 Item 只给空图），
            // 所以上一次裁切留下的图片会一直挂在窗口左上角；下一次截图时
            // ScreencopyView 会把整个输出（含我们自己的窗口）抓进冻结帧，
            // 那块旧图就被烙进新截图里。每次开/关界面都必须清干净。
            function reset() {
                cropper.grabRequested = false;
                cropper.width = 1;
                cropper.height = 1;
                // 只要不画东西就够了：source 清空后这个 Item 是空的。
                // 注意别把 region 清成 0x0 —— 那个矩形会被直接塞给
                // QImageReader::setScaledClipRect()，下一轮解码会卡在 Loading。
                cropImage.source = "";
            }

            function start() {
                if (!overlay.busy)
                    return;
                cropper.grabRequested = false;
                // 用刚抓到的图像的真实像素尺寸换算选区：只读得到、且钳制在图内
                const r = overlay.regionFor(overlay.frameWidth, overlay.frameHeight);
                cropper.region = r;
                cropper.width = Math.max(1, r.width);
                cropper.height = Math.max(1, r.height);
                // 绑定会把 sourceClipRect 同步成刚钳制过的 region：
                // 解码器只读选区那一块，且读之前区域就已经落在图片边界内
                //
                // 同一张图 + 同一块区域时改 sourceClipRect 不一定会重新解码，
                // 先清空 source 逼它读一遍
                cropImage.source = "";
                cropImage.source = "file://" + overlay.shotPath;
                // 本地文件是同步解码的，这里 status 通常已经 Ready
                Qt.callLater(cropper.grabIfReady);
            }

            function grabIfReady() {
                if (!overlay.busy || cropper.grabRequested)
                    return;
                if (cropImage.status === Image.Ready)
                    cropper.grab();
                else if (cropImage.status === Image.Error) {
                    console.warn("[screenshot] 选区解码失败");
                    overlay.abort();
                }
                // Loading: 等 onStatusChanged
            }

            function grab() {
                if (cropper.grabRequested)
                    return;
                cropper.grabRequested = true;
                const dest = overlay.pendingAction === "copy" ? overlay.cropPath : overlay.pendingTarget.path;
                // 记录期望尺寸：抓图按 item 自身尺寸 1:1 出图，两者必须一致
                const wantW = cropper.region.width;
                const wantH = cropper.region.height;

                cropper.grabToImage(function (res) {
                    // 写盘必须在回调里当场完成：ItemGrabResult 是抓图的一次性产物，
                    // 挪到下一轮事件循环可能已经被回收
                    if (!res || !res.image || res.image.width < 1 || res.image.height < 1) {
                        console.warn("[screenshot] 裁切抓图返回空图像");
                        Qt.callLater(() => overlay.abort());
                        return;
                    }
                    if (res.image.width !== wantW || res.image.height !== wantH)
                        console.warn("[screenshot] 裁切尺寸不符: 期望 " + wantW + "x" + wantH + " 实得 " + res.image.width + "x" + res.image.height);
                    if (!res.saveToFile("file://" + dest)) {
                        console.warn("[screenshot] 写入失败: " + dest);
                        Qt.callLater(() => overlay.abort());
                        return;
                    }
                    // 产物已经落盘：立刻把窗口左上角那块临时图像清掉，
                    // 别让它挂到下一次截图里
                    Qt.callLater(cropper.reset);
                    // 之后的动作（发布剪贴板 / 提示 / 关窗）挪出抓图上下文
                    Qt.callLater(() => overlay.finishExport(dest));
                });
            }

            Image {
                id: cropImage

                anchors.fill: parent
                fillMode: Image.Pad
                cache: false
                asynchronous: false
                // 只解码选区那一块（像素坐标，已按真实图像尺寸钳制），
                // 内存里不会多一份整屏
                sourceClipRect: cropper.region

                onStatusChanged: {
                    if (status === Image.Ready) {
                        Qt.callLater(cropper.grabIfReady);
                    } else if (status === Image.Error && overlay.busy) {
                        console.warn("[screenshot] 选区解码失败");
                        overlay.abort();
                    }
                }
            }
        }

        // ==================== 选区压暗：四个矩形，中间留空 ====================
        Item {
            anchors.fill: parent
            visible: overlay.captured && !overlay.instant && !overlay.busy

            Rectangle {
                x: 0
                y: 0
                width: parent.width
                height: overlay.sel.y
                color: overlay.dimColor
            }
            Rectangle {
                x: 0
                y: overlay.sel.y + overlay.sel.height
                width: parent.width
                height: Math.max(0, parent.height - overlay.sel.y - overlay.sel.height)
                color: overlay.dimColor
            }
            Rectangle {
                x: 0
                y: overlay.sel.y
                width: overlay.sel.x
                height: overlay.sel.height
                color: overlay.dimColor
            }
            Rectangle {
                x: overlay.sel.x + overlay.sel.width
                y: overlay.sel.y
                width: Math.max(0, parent.width - overlay.sel.x - overlay.sel.width)
                height: overlay.sel.height
                color: overlay.dimColor
            }
        }

        // ==================== 拖动框选 ====================
        MouseArea {
            id: dragArea
            anchors.fill: parent
            visible: overlay.captured && !overlay.instant && !overlay.busy
            cursorShape: Qt.CrossCursor
            acceptedButtons: Qt.LeftButton

            onPressed: (m) => {
                overlay.pressX = m.x;
                overlay.pressY = m.y;
                overlay.sel = Qt.rect(m.x, m.y, 1, 1);
            }
            onPositionChanged: (m) => {
                if (pressed)
                    overlay.updateSelection(m.x, m.y);
            }
            onReleased: {
                // 只是点了一下（没拖出尺寸）→ 回到全屏选区
                if (overlay.sel.width < 8 || overlay.sel.height < 8)
                    overlay.selectAll();
            }
        }

        // ==================== 选边框 + 尺寸 ====================
        Rectangle {
            x: overlay.sel.x
            y: overlay.sel.y
            width: overlay.sel.width
            height: overlay.sel.height
            color: "transparent"
            border.width: 2
            border.color: Kirigami.Theme.highlightColor
            visible: overlay.captured && !overlay.instant && !overlay.busy
            antialiasing: true
        }

        Rectangle {
            id: sizePill
            readonly property bool roomAbove: overlay.sel.y > height + Kirigami.Units.smallSpacing * 2
            visible: overlay.captured && !overlay.instant && !overlay.busy
            x: Math.max(Kirigami.Units.smallSpacing, Math.min(parent.width - width - Kirigami.Units.smallSpacing, overlay.sel.x))
            y: roomAbove ? overlay.sel.y - height - Kirigami.Units.smallSpacing
                         : overlay.sel.y + Kirigami.Units.smallSpacing
            width: sizeLabel.implicitWidth + Kirigami.Units.largeSpacing
            height: sizeLabel.implicitHeight + Kirigami.Units.smallSpacing
            radius: height / 2
            color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.85)

            Label {
                id: sizeLabel
                anchors.centerIn: parent
                text: Math.round(overlay.sel.width) + " × " + Math.round(overlay.sel.height)
                color: Kirigami.Theme.textColor
                font: Kirigami.Theme.smallFont
            }
        }

        // ==================== 工具栏 ====================
        Kirigami.ShadowedRectangle {
            id: toolbar
            visible: overlay.captured && !overlay.instant && !overlay.busy
            width: toolbarRow.implicitWidth + Kirigami.Units.largeSpacing * 2
            height: Kirigami.Units.gridUnit * 2.9
            radius: Kirigami.Units.gridUnit * 0.9
            color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.94)
            border.width: 1
            border.color: Qt.alpha(Kirigami.Theme.focusColor, 0.35)
            shadow.color: Qt.rgba(0, 0, 0, 0.45)
            shadow.size: 20
            shadow.yOffset: 5

            x: Math.max(Kirigami.Units.largeSpacing,
                Math.min(parent.width - width - Kirigami.Units.largeSpacing,
                    overlay.sel.x + overlay.sel.width / 2 - width / 2))
            y: {
                const below = overlay.sel.y + overlay.sel.height + Kirigami.Units.smallSpacing * 2;
                if (below + height < parent.height - Kirigami.Units.smallSpacing)
                    return below;
                const above = overlay.sel.y - height - Kirigami.Units.smallSpacing * 2;
                return above > Kirigami.Units.smallSpacing ? above
                                                           : parent.height - height - Kirigami.Units.largeSpacing;
            }

            RowLayout {
                id: toolbarRow
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: [
                        { "icon": "edit-copy-symbolic", "label": qsTr("复制"), "action": "copy", "danger": false },
                        { "icon": "document-save-symbolic", "label": qsTr("保存"), "action": "save", "danger": false },
                        { "icon": "view-fullscreen-symbolic", "label": qsTr("全屏"), "action": "full", "danger": false },
                        { "icon": "window-close-symbolic", "label": qsTr("取消"), "action": "cancel", "danger": true }
                    ]

                    Rectangle {
                        id: toolButton
                        readonly property var action: modelData
                        implicitWidth: toolRow.implicitWidth + Kirigami.Units.largeSpacing
                        implicitHeight: Kirigami.Units.gridUnit * 2
                        radius: Kirigami.Units.gridUnit * 0.45
                        color: toolHover.hovered
                            ? Qt.alpha(toolButton.action.danger ? "#da4453" : Kirigami.Theme.highlightColor, 0.28)
                            : "transparent"

                        RowLayout {
                            id: toolRow
                            anchors.centerIn: parent
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                source: toolButton.action.icon
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: implicitWidth
                                color: Kirigami.Theme.textColor
                            }
                            Label {
                                text: toolButton.action.label
                                color: Kirigami.Theme.textColor
                            }
                        }

                        HoverHandler {
                            id: toolHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: overlay.trigger(toolButton.action.action)
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }
                    }
                }

                Item {
                    implicitWidth: Kirigami.Units.smallSpacing
                    implicitHeight: 1
                }

                Label {
                    text: qsTr("拖动框选 · Enter 复制 · Ctrl+S 保存 · Esc 取消")
                    color: Kirigami.Theme.disabledTextColor
                    font: Kirigami.Theme.smallFont
                    Layout.rightMargin: Kirigami.Units.smallSpacing
                }
            }
        }

        // ==================== 结果提示 ====================
        Kirigami.ShadowedRectangle {
            visible: overlay.toast !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Kirigami.Units.gridUnit * 2.5
            width: toastRow.implicitWidth + Kirigami.Units.largeSpacing * 2
            height: Kirigami.Units.gridUnit * 2.2
            radius: Kirigami.Units.gridUnit * 0.6
            color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.95)
            border.width: 1
            border.color: Qt.alpha(Kirigami.Theme.focusColor, 0.35)
            shadow.color: Qt.rgba(0, 0, 0, 0.4)
            shadow.size: 18
            shadow.yOffset: 4

            RowLayout {
                id: toastRow
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "dialog-ok-symbolic"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    color: Kirigami.Theme.highlightColor
                }
                Label {
                    text: overlay.toast
                    color: Kirigami.Theme.textColor
                    elide: Text.ElideMiddle
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                }
            }
        }

        // ==================== 键盘 ====================
        Shortcut {
            sequence: "Escape"
            enabled: overlay.active && !overlay.instant
            onActivated: overlay.cancel()
        }
        Shortcut {
            sequence: "Return"
            enabled: overlay.active && !overlay.instant
            onActivated: overlay.confirm("copy")
        }
        Shortcut {
            sequence: "Enter"
            enabled: overlay.active && !overlay.instant
            onActivated: overlay.confirm("copy")
        }
        Shortcut {
            sequence: "Ctrl+C"
            enabled: overlay.active && !overlay.instant
            onActivated: overlay.confirm("copy")
        }
        Shortcut {
            sequence: "Ctrl+S"
            enabled: overlay.active && !overlay.instant
            onActivated: overlay.confirm("save")
        }
        Shortcut {
            sequence: "F"
            enabled: overlay.active && !overlay.instant
            onActivated: overlay.selectAll()
        }
    }
}
