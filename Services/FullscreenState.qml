pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// 全屏窗口状态提供者。
//
// 数据来自 wayland 的 toplevel-management 协议（ToplevelManager），
// 不依赖 Hyprland IPC，任何合成器只要支持该协议都能用。
//
// 用途：全屏（游戏 / 视频 / 演示）时把挡在前面的东西收起来——
// 目前是通知弹窗和顶栏中间的灵动岛。
//
//   visible: !FullscreenState.covers(modelData)   // 按屏幕判断
//   visible: !FullscreenState.active              // 任意屏幕
//
// 注意：Toplevel 的 fullscreen 变化不会让 toplevels 列表本身失效，
// 所以下面的 Instantiator 给每个窗口挂一个 Connections，
// 状态一变就 revision++ 让依赖它的绑定重新求值。
Singleton {
    id: root

    property int revision: 0

    readonly property var toplevels: ToplevelManager.toplevels.values

    readonly property var fullscreenToplevels: {
        root.revision; // 依赖：任何窗口的全屏状态变化都要重算

        const out = [];
        for (const toplevel of root.toplevels) {
            if (toplevel.fullscreen)
                out.push(toplevel);
        }
        return out;
    }

    // 任意屏幕上是否有全屏窗口
    readonly property bool active: root.fullscreenToplevels.length > 0

    // 该屏幕是否被全屏窗口占满。screen 传 null 时等同于 active。
    function covers(screen) {
        if (root.fullscreenToplevels.length === 0)
            return false;
        if (!screen)
            return true;

        for (const toplevel of root.fullscreenToplevels) {
            const list = toplevel.screens;
            // 合成器没报屏幕归属时保守处理：当作全屏，宁可少画也不挡人
            if (!list || list.length === 0)
                return true;
            for (let i = 0; i < list.length; ++i) {
                if (list[i] === screen)
                    return true;
            }
        }
        return false;
    }

    // 当前挡住屏幕的窗口标题，排查用
    readonly property string description: {
        root.revision;

        const names = [];
        for (const toplevel of root.fullscreenToplevels)
            names.push(toplevel.appId || toplevel.title || "?");
        return names.join(", ");
    }

    Instantiator {
        model: ToplevelManager.toplevels.values

        delegate: Connections {
            required property var modelData

            target: modelData

            function onFullscreenChanged() {
                root.revision++;
            }
            function onClosed() {
                root.revision++;
            }
        }

        onObjectAdded: root.revision++
        onObjectRemoved: root.revision++
    }

    IpcHandler {
        target: "fullscreen"

        // qs ipc call fullscreen state  -> 0 / 1
        function state(): string {
            return root.active ? "1" : "0";
        }

        // qs ipc call fullscreen windows -> "appId1, appId2"
        function windows(): string {
            return root.description;
        }
    }
}
