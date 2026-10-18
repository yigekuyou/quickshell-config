pragma Singleton
import qs.Config
import QtQuick
import Quickshell
import Quickshell.Wayland

// 底部面板的“运行中应用”（按 appId 归组）。
//
// 这里顺带把 .desktop 条目解析出来：托盘显示图标/名字时用 entry.icon / entry.name，
// 而不是直接拿 appId 当图标名——像 steam_app_1234 这种没有同名图标的应用
// 就会显示成问号占位图。
Singleton {
    id: root

    property list<var> apps: {
        var map = new Map();
        for (const toplevel of ToplevelManager.toplevels.values) {
            const appId = (toplevel.appId || "").toLowerCase();
            if (appId === "")
                continue;
            if (!map.has(appId))
                map.set(appId, []);
            map.get(appId).push(toplevel);
        }

        var values = [];
        for (const [key, toplevels] of map) {
            values.push(appEntryComp.createObject(null, {
                appId: key,
                desktopEntry: root.findEntry(key),
                toplevels: toplevels
            }));
        }
        // 固定按名字排序，避免窗口开关导致托盘顺序乱跳
        values.sort((a, b) => a.displayName.localeCompare(b.displayName));
        return values;
    }

    // 把 appId 映射到 .desktop 条目；找不到就返回 null（调用方自行兜底）
    function findEntry(appId) {
        if (!appId)
            return null;
        const entries = DesktopEntries.applications.values;
        // 1) .desktop 文件名与 appId 完全一致（绝大多数应用）
        for (const entry of entries) {
            if (entry.id.toLowerCase() === appId)
                return entry;
        }
        // 2) StartupWMClass 与 appId 一致
        for (const entry of entries) {
            if (entry.startupClass && entry.startupClass.toLowerCase() === appId)
                return entry;
        }
        // 3) 应用名兜底
        for (const entry of entries) {
            if (entry.name && entry.name.toLowerCase() === appId)
                return entry;
        }
        return null;
    }

    function hasActiveWindow(toplevels) {
        for (let i = 0; i < toplevels.length; i++) {
            if (toplevels[i].activated)
                return true;
        }
        return false;
    }

    component TaskbarAppEntry: QtObject {
        id: wrapper
        property string appId: ""
        property var desktopEntry: null
        property list<var> toplevels: []

        // 显示名：优先 .desktop 的本地化名称，其次窗口标题，最后 appId
        readonly property string displayName: {
            if (desktopEntry && desktopEntry.name)
                return desktopEntry.name;
            if (toplevels.length > 0 && toplevels[0].title)
                return toplevels[0].title;
            return appId;
        }

        // 图标名：.desktop 的 Icon= 最准；steam 的游戏窗口没有 .desktop，退回 Steam 图标
        readonly property string iconName: {
            if (desktopEntry && desktopEntry.icon)
                return desktopEntry.icon;
            if (appId.startsWith("steam_app_"))
                return "steam";
            return appId !== "" ? appId : "application-x-executable";
        }

        readonly property bool active: root.hasActiveWindow(toplevels)

        readonly property string tooltip: {
            const title = toplevels.length > 0 ? (toplevels[0].title || "") : "";
            const name = displayName;
            if (title === "" || title === name)
                return name;
            if (toplevels.length > 1)
                return name + " · " + toplevels.length + " 个窗口\n" + title;
            return name + "\n" + title;
        }
    }

    Component {
        id: appEntryComp
        TaskbarAppEntry {}
    }
}
