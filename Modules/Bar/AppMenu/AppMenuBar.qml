import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import com.github.yigekuyou.appmenu
import qs.Config
import qs.Widget
import org.kde.kirigami as Kirigami

// 顶栏左栏：全局菜单（应用菜单栏）。
//
// 全局菜单注册：
//   引用 com.github.yigekuyou.appmenu 的 AppMenu 单例时，它会尝试占用
//   com.canonical.AppMenu.Registrar —— 这是 Qt 应用把菜单栏导出到 D-Bus 的前提。
//   占到了 ownsRegistrar == true；名字被 KDE / hypr-appmenu / 别的实例占着时，
//   模块安静地退化为纯客户端，继续发现对方注册表里的菜单。
//   （想强制只当客户端：APPMENU_NO_REGISTRAR=1 qs）
//
// 窗口绑定：
//   Wayland 没有 XID，本模块按 pid 关联菜单。Hyprland 活动窗口的 ipc 对象
//   （j/clients）里就有 pid，跟随活动窗口 activatePid(pid) / clearActive() 即可。
Kirigami.ShadowedRectangle {
    id: root

    color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.5)
    radius: Sizes.cornerRadius
    border.width: 1
    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.1)

    implicitHeight: Sizes.barHeight
    // 宽度封顶：菜单特别多的应用（KDE 全家桶动辄十几个顶层项）会把顶栏左栏
    // 撑到半个屏幕宽，把剪贴板 / 壁纸按钮一路挤走。
    // 到上限后菜单条“压缩”：每项一起变窄、标题省略，而不是把后面的项挤出可视区。
    // 实际可用上限：屏幕宽度的 36%，且不超过 Sizes.menuBarMaxWidth。
    // 顶栏左栏最多占到这里，中间的「工作区」和右栏的托盘都不会被挤动。
    readonly property real maxWidth: Math.min(Sizes.menuBarMaxWidth, Math.max(Sizes.gridUnit * 16, Screen.width * 0.36))
    implicitWidth: Math.min(Math.ceil(menuStrip.implicitWidth + Sizes.smallSpacing * 2), root.maxWidth)
    visible: root.hasItems || root.fallbackAppName !== ""
    clip: true

    // ==================== 活动窗口 → pid ====================
    readonly property var activeToplevel: Hyprland.activeToplevel
    readonly property var activeIpc: activeToplevel ? activeToplevel.lastIpcObject : null
    readonly property int activePid: (activeIpc && activeIpc.pid !== undefined) ? activeIpc.pid : 0
    // Shell 启动后才打开的窗口：openwindow 事件不带 pid，lastIpcObject 要等
    // j/clients 刷新才填 —— 缺 pid 时拉一次 refreshToplevels，事件到达后自动重绑
    readonly property bool ipcStale: activeToplevel !== null && activeIpc !== null && activeIpc.pid === undefined

    onIpcStaleChanged: {
        if (root.ipcStale)
            Hyprland.refreshToplevels()
    }

    property int openIndex: -1 // 已展开的顶层菜单序号

    // 没有可绑的菜单（应用未导出 / 加载中）时显示应用名占位，
    // 模块保持可见 —— 全局菜单区域不该整个消失
    readonly property bool hasItems: AppMenu.menuModel !== null && AppMenu.menuModel.count > 0
    readonly property string fallbackAppName: {
        if (root.hasItems)
            return ""
        const t = root.activeToplevel
        if (!t || !t.wayland)
            return ""
        return t.wayland.appId ? t.wayland.appId : ""
    }

    // 单例被引用即占用 registrar；同时用它提前触发构造
    readonly property bool registrarOnline: AppMenu.available

    onVisibleChanged: if (!visible)
        root.closeMenu()

    onActivePidChanged: root.updateBinding()
    Component.onCompleted: root.updateBinding()

    Connections {
        target: AppMenu
        // 应用晚于面板启动（菜单几秒后才出现在总线上）时重新绑定
        function onMenusChanged() {
            root.updateBinding()
        }
        // 菜单整体被换掉（切应用）时收起弹窗
        function onMenuModelChanged() {
            root.closeMenu()
        }
    }

    function updateBinding() {
        if (root.activePid > 0 && AppMenu.hasMenuFor(root.activePid))
            AppMenu.activatePid(root.activePid)
        else
            AppMenu.clearActive()
    }

    // ==================== 菜单条 ====================
    // 菜单条宽度 = 可视宽度（不够时压缩每一项），但不会小于“每项都压到
    // menuBarItemMinWidth”的总宽 —— 只有压到最小还放不下时才退回横向滚动。
    // 滚动是很难在这么窄的一条带子上触发的手势，所以它只作为最后兜底。
    readonly property int topItemCount: AppMenu.menuModel ? AppMenu.menuModel.count : 0
    readonly property real stripMinWidth: root.topItemCount * Sizes.menuBarItemMinWidth

    Flickable {
        id: stripView

        anchors.fill: parent
        anchors.leftMargin: Sizes.smallSpacing
        anchors.rightMargin: Sizes.smallSpacing
        contentWidth: menuStrip.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width
        clip: true

        RowLayout {
            id: menuStrip

            // 宽于可视区 → RowLayout 把每一项按比例压到 minimumWidth；
            // 等于可视区时不会被撑大（每项的 maximumWidth 就是它的自然宽度）
            width: Math.max(stripView.width, root.stripMinWidth)
            height: stripView.height
            spacing: 0

            // 占位：当前活动窗口没有可绑定的菜单（未导出 / 加载中）时
            // 显示应用名，让全局菜单区域保持可见
            Kirigami.Heading {
                level: 4
                visible: root.fallbackAppName !== ""
                text: root.fallbackAppName
                color: Kirigami.Theme.disabledTextColor
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
            }

            Repeater {
                model: AppMenu.menuModel

                delegate: Item {
                    id: topItem

                    // 顶栏不显示助记符（"文件(F)" → "文件"）：菜单多的时候这几个字符
                    // 能省掉一大块宽度，弹出菜单里仍然保留
                    readonly property string rawText: model.text !== undefined ? model.text : ""
                    readonly property string barText: rawText.replace(/\s*\(&?[A-Za-z0-9]\)$/, "")
                    // 向上取整 + 2px 余量：少 1px 就会把标题省略成「…」
                    implicitWidth: Math.ceil(topLabel.implicitWidth + Sizes.menuBarItemPadding) + 2
                    implicitHeight: Sizes.barHeight
                    // 压缩规则交给 RowLayout：可以长到自然宽度，也可以窄到最小宽度。
                    // fillWidth 只影响“分配多出来的空间”，max 卡在自然宽度所以
                    // 菜单少的时候不会被拉宽。
                    Layout.fillWidth: true
                    // min 不能大于 max（极短的标题自然宽度可能比下限还小）
                    Layout.minimumWidth: Math.min(Sizes.menuBarItemMinWidth, topItem.implicitWidth)
                    Layout.maximumWidth: topItem.implicitWidth
                    opacity: model.enabled === false ? 0.45 : 1.0
                    // 纯分隔 / 既无文字又无图标的顶层项不渲染
                    visible: (model.text !== undefined && model.text !== "") || (model.iconName !== undefined && model.iconName !== "")

                    Rectangle {
                        anchors.fill: parent
                        radius: Sizes.menuBarItemRadius
                        color: root.openIndex === index ? Qt.alpha(Kirigami.Theme.highlightColor, 0.4) : (hoverHandler.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.2) : "transparent")

                        Behavior on color {
                            ColorAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }
                    }

                    Label {
                        id: topLabel

                        // 宽度跟着项走（而不是决定项宽），压缩时文字自己省略
                        anchors.fill: parent
                        anchors.leftMargin: Sizes.menuBarItemPadding / 2
                        anchors.rightMargin: Sizes.menuBarItemPadding / 2
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        font.pointSize: Sizes.menuBarFontSize
                        text: topItem.barText !== "" ? topItem.barText : "…"
                        color: Kirigami.Theme.highlightColor
                    }

                    // 压缩后标题被省略：悬停时把完整标题浮在本项上方（纯绘制，
                    // 不参与布局，所以既不会挤动邻居，也不需要横向滚动）
                    Rectangle {
                        visible: hoverHandler.hovered && topLabel.truncated
                        width: topItem.implicitWidth
                        height: topItem.height
                        x: (topItem.width - width) / 2
                        z: 10
                        radius: Sizes.menuBarItemRadius
                        color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.97)
                        border.width: 1
                        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.18)

                        Label {
                            anchors.centerIn: parent
                            text: topItem.rawText
                            font.pointSize: Sizes.menuBarFontSize
                            color: Kirigami.Theme.textColor
                        }
                    }
                    // 菜单已展开时，悬停到别的顶层项直接切换（macOS / Windows 行为）
                    HoverHandler {
                        id: hoverHandler

                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hoverHandler.hovered && root.openIndex >= 0 && root.openIndex !== index)
                                root.openMenu(index, topItem)
                        }
                    }

                    TapHandler {
                        onTapped: {
                            if (root.openIndex === index) {
                                root.closeMenu()
                                return
                            }
                            if (model.hasSubMenu === true) {
                                root.openMenu(index, topItem)
                            } else if (AppMenu.menuModel) {
                                AppMenu.menuModel.activate(index)
                            }
                        }
                    }
                }
            }
        }

        // 兜底滚动：滚轮纵向也能横向挪动菜单条（压缩后仍放不下的极端情况）
        WheelHandler {
            onWheel: (ev) => {
                if (!stripView.interactive)
                    return;
                const delta = ev.angleDelta.y !== 0 ? ev.angleDelta.y : ev.angleDelta.x;
                const maxX = Math.max(0, stripView.contentWidth - stripView.width);
                stripView.contentX = Math.max(0, Math.min(maxX, stripView.contentX - delta));
            }
        }
    }

    // 溢出提示：右边缘渐隐，说明菜单条后面还有内容（滚轮 / 横向滑动可见）
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 1
        width: Sizes.menuBarFadeWidth
        visible: stripView.contentWidth > stripView.width
        opacity: stripView.contentX < stripView.contentWidth - stripView.width ? 1 : 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: "transparent"
            }
            GradientStop {
                position: 1.0
                color: root.color
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }

    AppMenuPopup {
        id: menuPopup

        onVisibleChanged: if (!menuPopup.visible)
            root.openIndex = -1
    }

    // ==================== 弹窗控制 ====================
    function openMenu(index, item) {
        const m = AppMenu.menuModel
        if (!m)
            return
        const sub = m.subMenu(index)
        if (!sub)
            return
        menuPopup.switchModel(sub, m, index, item)
        root.openIndex = index
    }

    function closeMenu() {
        if (menuPopup.visible)
            menuPopup.closeChain()
        root.openIndex = -1
    }

    // ==================== 调试 IPC ====================
    // qs ipc call appmenu status / activate <pid> / clear / reload
    IpcHandler {
        target: "appmenu"

        function status(): string {
            return JSON.stringify({
                        "registrar": AppMenu.ownsRegistrar,
                        "available": AppMenu.available,
                        "menuCount": AppMenu.menuCount,
                        "menus": AppMenu.menus,
                        "activePid": AppMenu.activePid,
                        "barActivePid": root.activePid
                    })
        }
        function modelInfo(): string {
            const m = AppMenu.menuModel
            if (!m)
                return JSON.stringify({
                            "bound": false
                        })
            // TextRole = Qt.UserRole + 3 = 259, HasSubMenuRole = 267
            const items = []
            for (let r = 0; r < m.count; r++) {
                const idx = m.index(r, 0)
                items.push({
                            "text": m.data(idx, 259),
                            "hasSubMenu": m.data(idx, 267)
                        })
            }
            return JSON.stringify({
                        "bound": true,
                        "widgetVisible": root.visible,
                        "items": items
                    })
        }
        function geometry(): string {
            return JSON.stringify({
                        "barW": root.implicitWidth,
                        "stripImplicit": menuStrip.implicitWidth,
                        "stripMin": root.stripMinWidth,
                        "menuW": menuStrip.width,
                        "shrunk": menuStrip.implicitWidth > menuStrip.width,
                        "viewW": stripView.width,
                        "contentW": stripView.contentWidth,
                        "count": AppMenu.menuModel ? AppMenu.menuModel.count : -1,
                        "fallback": root.fallbackAppName,
                        "visible": root.visible
                    })
        }
        function activate(pid: int): void {
            AppMenu.activatePid(pid)
        }
        function clear(): void {
            AppMenu.clearActive()
        }
        function reload(): void {
            AppMenu.reload()
        }
    }

}
