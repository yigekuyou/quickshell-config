import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import com.github.yigekuyou.appmenu
import qs.Config
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
    implicitWidth: menuStrip.implicitWidth + Sizes.smallSpacing * 2
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
    RowLayout {
        id: menuStrip

        anchors.centerIn: parent
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

                implicitWidth: topLabel.implicitWidth + Sizes.menuBarItemPadding
                implicitHeight: Sizes.barHeight
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

                    anchors.centerIn: parent
                    font.pointSize: Sizes.menuBarFontSize
                    text: model.text !== undefined && model.text.length > 0 ? model.text : "…"
                    color: Kirigami.Theme.textColor
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
