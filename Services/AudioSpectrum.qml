pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config
import qs.Services

// ============================================================================
// 根类型用 Item 而不是 QtObject：需要一个默认属性来挂 FileView/Process/Timer
// 这些子对象（QtObject 没有默认属性，qmllint 会报 missing-property）。
// Web 壁纸的音频频谱源（Wallpaper Engine web API 的形状：64 频段，0..1）。
//
// 数据链：
//   cava（pipewire monitor，64 bars / 30fps / ASCII 0..100）
//     → 本单例解析成 64 个浮点
//     → 写 $XDG_RUNTIME_DIR/quickshell-audio-bars.json
//     → Wallpaper/Web.qml（裸 qml6 独立进程）每 33ms 轮询读
//     → 推给页面的 wallpaperRegisterAudioListener 回调
//
// 为什么走文件：
//   Web.qml 跑在 qml6 里，没有 Quickshell.Io，能用的只有 XMLHttpRequest；
//   文件在 tmpfs 上，写读都是一次几百字节的小 IO，30Hz 的开销可忽略。
//   （主进程不能直接把数据推进 WebEngine —— 那是另一个进程。）
//
// 为什么不用 Quickshell 的 Pipewire 峰值监视：
//   WE 的 API 要的是 64 个频段的频谱，单个峰值做不出柱状可视化；
//   cava 本来就是这个项目的依赖（顶栏的 Cava 模块），再起一只只多 1~2% CPU。
//
// 开关复用「设置 → 壁纸 → 捕获系统音频」（systemAudioCapture）：
//   场景壁纸读它决定插件是否抓系统音频，web 壁纸读它决定这里起不起 cava。
// ============================================================================
Item {
    id: root

    // 只有「主进程 + 开关打开 + 当前壁纸是 web」才需要这只 cava。
    // 不看 suspended：暂停（切窗口/锁屏）会频繁触发，起停 cava 反而让
    // 可视化恢复时慢半秒；被 SIGSTOP 的 web 进程本来也不会来读数据。
    readonly property bool active: {
        // scene 子进程也会加载本单例，必须排除，否则会多起一只 cava
        if (Quickshell.env("QS_WALLPAPER_SCENE_CHILD") === "1")
            return false;
        if (!Settings.wallpaper.systemAudioCapture)
            return false;
        return WallpaperPath.wallpaperType === "web" && String(WallpaperPath.source) !== "";
    }

    // Web.qml 通过规格文件拿到这个路径（qml6 里读不到环境变量）
    readonly property string barsPath: {
        const dir = String(Quickshell.env("XDG_RUNTIME_DIR") || "");
        return (dir !== "" ? dir : "/tmp") + "/quickshell-audio-bars.json";
    }

    // 上一次写出去的内容：静音/无变化时整条链上什么都不做
    //（不写文件、Web.qml 侧也就不会重复推 JS）
    property string lastPayload: ""

    FileView {
        id: out
        // 不 active 时不占文件（path 为空即关闭）
        path: root.active ? root.barsPath : ""
        // tmpfs 上 rename 是原子的：读端永远看到完整的 JSON，
        // 不会读到写了一半的半个数组
        atomicWrites: true
        // 首帧之前文件还不存在，别刷 "no such file" 警告
        printErrors: false
    }

    Process {
        id: cava
        running: false
        command: ["cava", "-p", Directories.configDir + "/Wallpaper/cava-web.conf"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.publish(String(data))
        }
        // cava 偶发起不来（音频服务没就绪 / 被 OOM）：5s 后重试
        onExited: {
            if (root.active)
                retry.restart();
        }
    }

    Timer {
        id: retry
        interval: 5000
        repeat: false
        onTriggered: if (root.active && !cava.running)
            cava.running = true
    }

    function startIfNeeded(): void {
        if (root.active && !cava.running)
            cava.running = true;
    }

    // 开关 / 壁纸类型变化时起停
    onActiveChanged: {
        if (root.active) {
            root.startIfNeeded();
        } else {
            retry.stop();
            cava.running = false;
            root.lastPayload = "";
        }
    }

    Component.onCompleted: root.startIfNeeded()

    // cava ascii 输出形如 "12;45;...;"（ascii_max_range=100，每帧一行）
    function publish(line: string): void {
        const parts = line.split(";");
        const bars = [];
        for (let i = 0; i < 64 && i < parts.length; ++i) {
            const v = Number(parts[i]);
            bars.push(isFinite(v) ? Math.min(1, Math.max(0, v / 100)) : 0);
        }
        while (bars.length < 64)
            bars.push(0);
        const payload = JSON.stringify(bars);
        if (payload === root.lastPayload)
            return;
        root.lastPayload = payload;
        if (root.active && out.path !== "")
            out.setText(payload);
    }
}