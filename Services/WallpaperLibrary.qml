pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import com.github.captsilver.wallpaperEngineKde
import qs.Config

// 壁纸库：直接使用 Wallpaper Engine 插件的 FileHelper 扫描创意工坊目录，
// 不再依赖 python。
//
//   getFolderList(dir, {only_dir:true}) -> { folder, items:[{name, mtime}] }
//   requestReadFile(path)               -> fileReadReady(path, contents, ok)
//
// project.json 通过插件异步读取（75 个目录也不会卡住主线程），
// contents 是 ArrayBuffer，QML 的 JS 引擎没有 TextDecoder，这里手写 UTF-8 解码。
Singleton {
    id: root

    property var items: []
    property bool scanning: false
    property string error: ""

    FileHelper {
        id: helper

        onFileReadReady: (path, contents, ok) => root.onFileRead(path, contents, ok)
    }

    // path -> 扫描上下文
    property var pending: ({})
    property int remaining: 0
    property var collected: []

    function refresh(): void {
        if (root.scanning)
            return;

        root.scanning = true;
        root.error = "";
        root.collected = [];
        root.pending = {};
        root.remaining = 0;

        let listing = null;
        try {
            listing = helper.getFolderList(WallpaperPath.workshopBase, { "only_dir": true });
        } catch (e) {
            root.error = String(e);
        }

        if (!listing || !listing.items) {
            root.items = [];
            root.scanning = false;
            if (root.error === "")
                root.error = qsTr("无法读取壁纸目录: %1").arg(WallpaperPath.workshopBase);
            return;
        }

        const dirs = listing.folder || WallpaperPath.workshopBase;
        for (let i = 0; i < listing.items.length; i++) {
            const entry = listing.items[i];
            const dir = String(dirs).replace(/\/+$/, "") + "/" + entry.name;
            const project = dir + "/project.json";
            root.pending[project] = { "id": String(entry.name), "dir": dir };
            root.remaining += 1;
            helper.requestReadFile(project);
        }

        if (root.remaining === 0) {
            root.items = [];
            root.scanning = false;
        }
    }

    function onFileRead(path, contents, ok): void {
        const meta = root.pending[path];
        if (!meta)
            return;

        delete root.pending[path];

        if (ok) {
            try {
                const text = root.decodeUtf8(contents);
                const project = JSON.parse(text);
                const type = String(project.type || "").toLowerCase();

                if (type === "scene" || type === "video" || type === "web") {
                    const entryFile = type === "scene"
                        ? "scene.pkg"
                        : String(project.file || "");

                    if (entryFile !== "") {
                        const previewName = String(project.preview || "preview.jpg");
                        root.collected.push({
                            "id": meta.id,
                            "title": String(project.title || meta.id),
                            "type": type,
                            "file": entryFile,
                            "preview": previewName === ""
                                ? ""
                                : Qt.resolvedUrl(meta.dir + "/" + previewName).toString(),
                            "isGif": previewName.toLowerCase().endsWith(".gif")
                        });
                    }
                }
            } catch (e) {
                // 单个壁纸的 project.json 坏掉不影响整个列表
            }
        }

        root.remaining -= 1;
        if (root.remaining <= 0) {
            const list = root.collected;
            list.sort((a, b) => a.title.toLowerCase() < b.title.toLowerCase() ? -1 : 1);
            root.items = list;
            root.scanning = false;
        }
    }

    // IPC：qs ipc call wallpaper set <id> / refresh / current / list
    IpcHandler {
        target: "wallpaper"

        function setWallpaper(id: string): void {
            WallpaperPath.wallpaperId = id;
        }
        function refresh(): void {
            root.refresh();
        }
        function current(): string {
            return WallpaperPath.wallpaperId;
        }
        function list(): string {
            return JSON.stringify(root.items.map(item => ({
                "id": item.id,
                "title": item.title,
                "type": item.type
            })));
        }
        function setFps(value: int): void {
            WallpaperPath.fps = value;
        }
        function setPaused(value: bool): void {
            WallpaperPath.paused = value;
        }
        function setMuted(value: bool): void {
            WallpaperPath.muted = value;
        }
        function setSpeed(value: real): void {
            WallpaperPath.speed = value;
        }
    }

    // QML 的 JS 引擎没有 TextDecoder，手写一个按块拼装的 UTF-8 解码器
    function decodeUtf8(buffer): string {
        const bytes = new Uint8Array(buffer);
        const parts = [];
        let codes = [];
        let i = 0;

        while (i < bytes.length) {
            const b0 = bytes[i++];
            let cp = 0;

            if (b0 < 0x80) {
                cp = b0;
            } else if (b0 < 0xE0) {
                cp = ((b0 & 0x1F) << 6) | (bytes[i++] & 0x3F);
            } else if (b0 < 0xF0) {
                cp = ((b0 & 0x0F) << 12) | ((bytes[i++] & 0x3F) << 6) | (bytes[i++] & 0x3F);
            } else {
                cp = ((b0 & 0x07) << 18) | ((bytes[i++] & 0x3F) << 12)
                    | ((bytes[i++] & 0x3F) << 6) | (bytes[i++] & 0x3F);
            }

            if (cp > 0xFFFF) {
                cp -= 0x10000;
                codes.push(0xD800 + (cp >> 10), 0xDC00 + (cp & 0x3FF));
            } else {
                codes.push(cp);
            }

            if (codes.length >= 8192) {
                parts.push(String.fromCharCode.apply(null, codes));
                codes = [];
            }
        }

        if (codes.length > 0)
            parts.push(String.fromCharCode.apply(null, codes));

        return parts.join("");
    }
}
