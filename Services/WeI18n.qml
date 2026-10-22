pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

// Wallpaper Engine 属性标签的翻译/对照层。
//
// WE 的 project.json 里 general.properties.<键>.text 有两种写法：
//   1) 英文字面量，可能带 <p>/<br> 这种 HTML（作者直接写在编辑器里）；
//   2) 一个 ui_ 开头的翻译键（如 ui_browse_properties_scheme_color），
//      WE 用自己的语言包解析它，离开 WE 就只剩这串键名。
// 这里把两种都翻成可读标签，规则写在 i18n/wallpaper-engine.json 的 _meta 里：
//   phrases 精确命中 → tokens 按下划线分段逐词翻译（camelCase 用最长前缀拆）
//   → 都不行就回落到去 HTML 的原文 → 再不行用属性键。
// 原始键名永远以「键 xxx」附在说明后面，方便和 json 对照。
Singleton {
    id: root

    readonly property string path: Directories.configDir + "/i18n/wallpaper-engine.json"

    FileView {
        id: view

        path: root.path
        // 同步读：设置页第一次渲染就要用这张表
        blockLoading: true
        // 手改文本文件即可，改完重载配置（config reload）就生效
        watchChanges: false
        printErrors: true
    }

    // 不能用绑定读 view.text()：QML 先求父对象属性、再建子对象，
    // 那样求值时 FileView 还不存在，表会永远是空的。等全部建完再读一次。
    property var table: ({})

    Component.onCompleted: root.table = root.readTable()

    function readTable() {
        try {
            return JSON.parse(view.text() || "{}") || ({});
        } catch (e) {
            console.warn("[we-i18n] 对照表解析失败:", e);
            return ({});
        }
    }

    // 小写 token → 译文，避免每次比较都 toLowerCase
    readonly property var tokenLower: {
        const out = ({});
        const src = root.table.tokens || ({});
        for (const k in src)
            out[String(k).toLowerCase()] = String(src[k]);
        return out;
    }

    // 去 HTML 标签 / 实体 / 多余空白（WE 的 text 里常见 <p>…<br>…</p>）
    function plain(text) {
        let s = String(text || "");
        s = s.replace(/<br\s*\/?>/gi, "\n");
        s = s.replace(/<[^>]*>/g, " ");
        s = s.replace(/&nbsp;/g, " ");
        s = s.replace(/&amp;/g, "&");
        s = s.replace(/&lt;/g, "<");
        s = s.replace(/&gt;/g, ">");
        s = s.replace(/&quot;/g, "\"");
        s = s.replace(/&#39;/g, "'");
        return s.replace(/\s+/g, " ").trim();
    }

    // 单个 token：先查表，再按最长前缀拆 camelCase
    // （backgroundVideoVolume → background + video + volume）
    function part(token) {
        const lower = String(token).toLowerCase();
        if (root.tokenLower[lower] !== undefined)
            return root.tokenLower[lower];

        let rest = lower;
        let out = "";
        let guard = 0;
        while (rest.length > 0 && guard++ < 16) {
            let best = "";
            for (const key in root.tokenLower) {
                if (key.length > best.length && rest.indexOf(key) === 0)
                    best = key;
            }
            if (best === "") {
                out += rest;
                break;
            }
            out += root.tokenLower[best];
            rest = rest.slice(best.length);
        }
        return out;
    }

    // text 字段 → 显示用标签；翻不出来时返回空串，由 label() 回落
    function translate(text) {
        const raw = String(text || "").trim();
        if (raw === "")
            return "";

        const phrases = root.table.phrases || ({});
        if (phrases[raw] !== undefined)
            return String(phrases[raw]);

        // 只有 ui_ 开头的才是结构性翻译键；英文原句不硬翻
        if (raw.indexOf("ui_") !== 0)
            return "";

        return raw.slice(3).split("_").filter(p => p.length > 0).map(p => root.part(p)).join("");
    }

    // 属性行的标题：翻译 → 去 HTML 的原文 → 属性键
    function label(key, def) {
        const raw = def && def.text !== undefined ? String(def.text) : "";
        const tr = root.translate(raw);
        if (tr !== "")
            return tr;
        const p = root.plain(raw);
        if (p !== "")
            return p;
        return String(key);
    }

    // 属性行的说明：tip（去 HTML）+「键 xxx」对照
    function note(key, def) {
        const tip = def && def.tip !== undefined ? root.plain(String(def.tip)) : "";
        const keyText = qsTr("键 ") + String(key);
        return tip !== "" ? tip + "  ·  " + keyText : keyText;
    }
}
