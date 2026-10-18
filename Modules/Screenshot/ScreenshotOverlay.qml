import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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
            sel = Qt.rect(0, 0, width, height);
            armTimer.restart();
        } else {
            armTimer.stop();
            closeTimer.stop();
            view.captureSource = null;
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
        if (overlay.instant)
            overlay.confirm("copy");
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

    // 依据选区把冻结画面裁出来：一次抓整屏（原生分辨率），再用 magick 裁矩形。
    // 这样只需要一帧画面，UI 上的遮罩 / 边框不会被带进成品。
    function confirm(action) {
        if (overlay.busy || !overlay.captured)
            return;
        overlay.busy = true;

        const sw = Math.max(1, view.sourceSize.width);
        const sh = Math.max(1, view.sourceSize.height);
        const kx = sw / Math.max(1, view.width);
        const ky = sh / Math.max(1, view.height);
        const r = overlay.sel;
        const cx = Math.max(0, Math.min(sw - 1, Math.round(r.x * kx)));
        const cy = Math.max(0, Math.min(sh - 1, Math.round(r.y * ky)));
        const cw = Math.max(1, Math.min(sw - cx, Math.round(r.width * kx)));
        const ch = Math.max(1, Math.min(sh - cy, Math.round(r.height * ky)));

        view.grabToImage(function (res) {
            if (!res || !res.image) {
                console.warn("[screenshot] grabToImage 返回空图像");
                overlay.busy = false;
                overlay.failed();
                return;
            }
            if (!res.saveToFile("file://" + overlay.shotPath)) {
                console.warn("[screenshot] 临时文件写入失败: " + overlay.shotPath);
                overlay.busy = false;
                overlay.failed();
                return;
            }
            overlay.runCrop(action, cx, cy, cw, ch);
        }, Qt.size(sw, sh));
    }

    function runCrop(action, x, y, w, h) {
        const crop = "-crop " + w + "x" + h + "+" + x + "+" + y + " +repage";
        const shot = overlay.shotPath;

        if (action === "copy") {
            overlay.toast = qsTr("已复制到剪贴板");
            cropProcess.exec(["/bin/sh", "-c",
                "magick '" + shot + "' " + crop + " png:- | wl-copy --type image/png"]);
        } else {
            const dir = Quickshell.env("HOME") + "/图片/Screenshots";
            const name = "Screenshot_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
            overlay.toast = qsTr("已保存到 图片/Screenshots/" + name);
            // magick 的 security policy 只允许写 /tmp，因此先落到临时文件再 cp
            cropProcess.exec(["/bin/sh", "-c",
                "magick '" + shot + "' " + crop + " /tmp/quickshell-crop.png"
                + " && mkdir -p '" + dir + "'"
                + " && cp /tmp/quickshell-crop.png '" + dir + "/" + name + "'"]);
        }
    }

    Process {
        id: cropProcess
        onExited: (code) => {
            if (code !== 0) {
                console.warn("[screenshot] 导出失败，退出码 " + code);
                overlay.toast = qsTr("导出失败");
            }
            closeTimer.restart();
        }
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
