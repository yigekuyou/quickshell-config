import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Config
import qs.Services
import qs.Modules.Bar.common
import org.kde.kirigami as Kirigami

// ============================================================================
// 顶栏电源入口（钉在右栏最右端）。
// ============================================================================
// 旧实现是 Rectangle + MouseArea 直接 exec 外部程序 wlogout（一个独立的
// 注销菜单），和栏里其它按钮的胶囊外观完全不是一个体系，也没有悬停反馈。
// 现在改成纯 QML 构造：
//
//   外观  → 统一走 common/BarButton（危险色实心 filled 模式，复刻旧的
//           Colorscheme.error 红底 + 背景色图标观感）
//   菜单  → QtQuick.Controls 的 Menu / MenuItem（见 Qt 文档
//           qml-qtquick-controls-menu.html），popupType: Popup.Window 让它
//           作为独立窗口渲染，不会被栏窗口的矮高度裁掉；
//           Menu 声明在按钮内部 → 拿到按钮所在窗口作 transient parent，
//           Wayland 上由合成器正确定位（见 KDE Wayland 移植指南）
//   动作  → 和 wlogout 默认布局一一对应：
//             锁屏  → Shortcuts.triggerLock()，走项目自己的 WlSessionLock
//                     锁屏（与全局快捷键 quickshell:lock 同一条入口），
//                     不用 loginctl lock-session
//             挂起 / 休眠 / 重启 / 关机 → systemctl
//             注销  → loginctl terminate-session self（wlogout 默认命令）
//           不再依赖 wlogout 二进制，不想装 / 装不了的机器也能用。
//
// 点击切换开合：菜单可见时再点按钮（或者点菜单外的任意位置，由
// closePolicy 默认值 CloseOnEscape | CloseOnPressOutside 处理）都会收起。
BarButton {
    id: root
    section: "right"

    // 危险操作：filled 让 BarButton 走 fillColor + onFillColor（实心底、
    // 无描边、图标翻转为 onFillColor），等价于旧版的红底白字写法
    filled: true
    fillColor: Colorscheme.error

    // 图标跟随系统图标主题（Breeze: system-shutdown-symbolic），
    // 替换旧版硬编码的 "⏻" 文本字符
    icon: "system-shutdown-symbolic"
    square: true

    // 菜单开着时点亮高亮描边，和其它栏按钮打开面板时的 checked 语义一致
    checked: powerMenu.visible

    // 开合总入口：按钮点击、全局快捷键 quickshell:power-menu 都走这里。
    function toggleMenu() {
        powerMenu.visible = !powerMenu.visible
    }

    onClicked: root.toggleMenu()

    // 全局快捷键 quickshell:power-menu（Hyprland 侧绑定示例：
    // hl.bind("SUPER + ESC", hl.dsp.global("quickshell:power-menu"))）
    Connections {
        target: Shortcuts

        function onPowerMenuRequested(): void {
            root.toggleMenu()
        }
    }

    Menu {
        id: powerMenu

        // Qt 6.8+：独立窗口渲染，不被栏窗口的高度裁掉。若 Qt 版本低于
        // 6.8 或风格不支持，Menu 会回落到在父窗口内渲染（栏太矮会被裁，
        // 但功能仍在）。
        popupType: Popup.Window

        // 贴着按钮下沿、右缘与按钮右缘对齐（按钮在屏幕右上角，菜单向左下
        // 方展开，不冲出屏幕）。声明式绑定：菜单测量宽度变化时 x 自动重算。
        x: root.width - width
        y: root.height + Kirigami.Units.smallSpacing

        MenuItem {
            text: qsTr("锁屏")
            icon.name: "system-lock-screen"
            onTriggered: Shortcuts.triggerLock()
        }

        MenuSeparator {}

        MenuItem {
            text: qsTr("挂起")
            icon.name: "system-suspend"
            onTriggered: Quickshell.execDetached(["systemctl", "suspend"])
        }

        MenuItem {
            text: qsTr("休眠")
            icon.name: "system-hibernate"
            onTriggered: Quickshell.execDetached(["systemctl", "hibernate"])
        }

        MenuSeparator {}

        MenuItem {
            text: qsTr("注销")
            icon.name: "system-log-out"
            onTriggered: Quickshell.execDetached(["loginctl", "terminate-session", "self"])
        }

        MenuItem {
            text: qsTr("重启")
            icon.name: "system-reboot"
            onTriggered: Quickshell.execDetached(["systemctl", "reboot"])
        }

        MenuItem {
            text: qsTr("关机")
            icon.name: "system-shutdown"
            onTriggered: Quickshell.execDetached(["systemctl", "poweroff"])
        }
    }
}
