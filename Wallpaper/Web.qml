import QtQuick
import QtWebEngine
import org.kde.layershell as LayerShell

// Wallpaper Engine 的 Web 壁纸渲染器。
//
// 为什么不是 Quickshell 的一部分：
//   Quickshell 启动时把 QGuiApplication 的 argc 硬编码成 0（src/launch/launch.cpp），
//   QCoreApplication::arguments() 因此为空，Chromium 初始化会直接
//     FATAL: Argument list is empty, the program name is not passed to QCoreApplication
//   在 qs 里 `import QtWebEngine` 必然崩溃。这里用 Qt 自带的 qml6 运行时单独跑一个
//   进程，再通过 LayerShellQt 把它挂成背景层，效果等同于壁纸。
//
// 用法（由 Modules/Wallpaper/WallpaperContent/Wallpaper.qml 启动）：
//   qml6 Wallpaper/Web.qml -- <规格 JSON 路径>
//   规格文件内容：{ url, muted, paused, background, properties }
//   参数走文件而不是一排 argv：属性 JSON 有上百个键（argv 要防引号、防长度），
//   而且 qml6 会把“最后一个参数”当成第二个 QML 文件。
// 渲染后端沿用父进程的 QSG_RHI_BACKEND（主进程是 vulkan）。
Window {
    id: root
    visible: true

    // qml6 会把 "--" 之后的参数原样放进 Qt.application.arguments
    readonly property int dash: Qt.application.arguments.indexOf("--")
    readonly property string specPath: dash >= 0 && Qt.application.arguments.length > dash + 1
        ? Qt.application.arguments[dash + 1] : ""

    // 规格只读一次：任何参数变化都由父进程重启本进程（跨进程没有别的通道）
    readonly property var spec: {
        if (root.specPath === "")
            return ({});
        const text = root.readLocalFile(root.specPath);
        try {
            return JSON.parse(text) || ({});
        } catch (e) {
            console.warn("[web-wallpaper] 规格文件解析失败:", e);
            return ({});
        }
    }

    readonly property string wallpaperUrl: String(root.spec.url || "")
    readonly property bool muted: root.spec.muted === undefined ? true : !!root.spec.muted
    readonly property bool paused: root.spec.paused === true
    readonly property string propertiesJson: String(root.spec.properties || "{}")
    // 底色：页面还没画出来 / 加载失败时看到的就是这个颜色
    readonly property string background: String(root.spec.background || "black")

    color: root.background

    // ---- 挂成背景层：没有这段就只是一个普通浮动窗口 ----
    // 必须是 LayerBackground + 四边 anchor + exclusionZone -1（不占位、别的窗口
    // 可以盖在上面）+ 不吃键盘。QML 里这些是 LayerShell.Window 的附加属性。
    LayerShell.Window.layer: LayerShell.Window.LayerBackground
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
        | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.scope: "qs:webwall"

    // ---- 暂停与退出：实测结论 + 为什么是这样 ----
    // 暂停本身由父进程发 SIGSTOP/SIGCONT（它能保住最后一帧，CPU 归零）。
    // 这里只保留两件子进程自己能做的事：
    //
    // 1) 为什么不用 lifecycleState 当暂停开关（Qt 官方接口，但在这里无效）：
    //    实测 WebEngineView.lifecycleState = Frozen 在视图可见时是**空操作**，
    //    页面里的 setInterval/rAF 照常跑（每 500ms 仍在打印）；QtWebEngine
    //    只有当页面被隐藏时才真冻结（那时 recommendedState 变成 Frozen），
    //    而隐藏会丢掉最后一帧、只剩窗口底色。所以下面只把它当"出生时的初值"，
    //    运行期的暂停交给父进程的信号。
    //
    // 2) 父进程没了就自己退出：否则会变成孤儿占着背景层，跟下一个 qs 起的
    //    实例抢图层（实测同时跑过 3 个 WebEngine）。/proc/self/stat 的格式是
    //    "pid (comm) state ppid ..."，取最后一个 ')' 之后就是 state 和 ppid。
    //    读 /proc 需要 QML_XHR_ALLOW_FILE_READ=1，父进程启动我们时已经设了。
    property string parentPid: ""

    function readLocalFile(path) {
        if (path === "")
            return "";
        const xhr = new XMLHttpRequest();
        try {
            xhr.open("GET", "file://" + path, false);
            xhr.send();
            return String(xhr.responseText || "");
        } catch (e) {
            return "";
        }
    }

    function readParentPid() {
        const s = root.readLocalFile("/proc/self/stat");
        const close = s.lastIndexOf(")");
        if (close < 0)
            return "";
        return s.slice(close + 2).split(" ")[1] || "";
    }

    Component.onCompleted: root.parentPid = root.readParentPid()

    Timer {
        // 2s 一次读 /proc/self/stat，开销可以忽略；读失败就不动，
        // 避免 /proc 偶发失败导致壁纸自己退出。
        interval: 2000
        repeat: true
        running: root.parentPid !== ""
        onTriggered: {
            const now = root.readParentPid();
            if (now !== "" && now !== root.parentPid)
                Qt.exit(0);
        }
    }

    WebEngineView {
        id: web
        anchors.fill: parent
        url: root.wallpaperUrl
        audioMuted: root.muted
        activeFocusOnPress: false
        backgroundColor: root.background

        // 出生时的生命周期状态（Active/Frozen/Discarded）。运行期的暂停
        // 由父进程的 SIGSTOP/SIGCONT 负责 —— 见上方注释：视图可见时
        // 设成 Frozen 并不会真的停掉页面，它是空操作。
        lifecycleState: root.paused
            ? WebEngineView.LifecycleState.Frozen
            : WebEngineView.LifecycleState.Active

        // Wallpaper Engine 的 Web 壁纸通常会访问这几个全局，缺少时会在
        // DOMContentLoaded 阶段抛异常导致整张壁纸黑屏。给一个无害的默认实现。
        // 用 userScripts.insert(JS 对象) 而不是内联 WebEngineScript{}：
        // Qt 6.11 把非 creatable 的 QWebEngineScript 值类型暴露在同一个名字上，
        // 内联声明会报 "Element is not creatable"。
        Component.onCompleted: {
            // 让 Web 壁纸能在没有用户手势的情况下自动播放视频/音频
            settings.playbackRequiresUserGesture = false;
            settings.localContentCanAccessFileUrls = true;
            settings.localContentCanAccessRemoteUrls = true;
            settings.showScrollBars = false;
            settings.autoLoadIconsForPage = false;
            settings.fullScreenSupportEnabled = true;

            // 注入 Wallpaper Engine 的属性 API。
            // 兼容两种页面写法：
            //   A) window.wallpaperPropertyListener = { applyUserProperties: fn }
            //   B) window.wallpaperPropertyListener = {};
            //      window.wallpaperPropertyListener.applyUserProperties = fn
            // 脚本注入点比页面脚本早，所以用 getter/setter 接管赋值，
            // 等页面把自己的 listener 挂好之后再把属性推过去。
            let props = ({});
            try {
                props = JSON.parse(root.propertiesJson) || ({});
            } catch (e) {
                console.warn("[web-wallpaper] 属性 JSON 解析失败:", e);
            }

            const bootstrap = `(function () {
  var values = ${JSON.stringify(props)};
  var page = null;
  function payload() {
    var out = {};
    for (var k in values) out[k] = { value: values[k] };
    return out;
  }
  function push(target) {
    if (target && typeof target.applyUserProperties === "function") {
      try { target.applyUserProperties(payload()); }
      catch (e) { console.warn("applyUserProperties:", e); }
    }
  }
  var proxy = {
    applyUserProperties: function (p) {
      if (page && typeof page.applyUserProperties === "function")
        page.applyUserProperties(p);
    }
  };
  try {
    Object.defineProperty(window, "wallpaperPropertyListener", {
      configurable: true,
      get: function () { return page || proxy; },
      set: function (v) { page = v; setTimeout(function () { push(page || proxy); }, 0); }
    });
  } catch (e) {
    window.wallpaperPropertyListener = window.wallpaperPropertyListener || proxy;
  }
  window.wallpaperRegisterAudioListener = window.wallpaperRegisterAudioListener || function () {};
  window.wallpaperRequestRandomFileForProperty = window.wallpaperRequestRandomFileForProperty || function () {};
  [0, 250, 1000].forEach(function (ms) {
    setTimeout(function () { push(page || proxy); }, ms);
  });
})();`;

            userScripts.insert([{
                "name": "qs-webwall-compat",
                "sourceCode": bootstrap,
                "injectionPoint": WebEngineScript.DocumentCreation,
                "worldId": WebEngineScript.MainWorld,
                "runOnSubframes": false
            }]);
        }

        onLoadingChanged: (info) => {
            if (info.status === WebEngineView.LoadFailedStatus)
                console.error("[web-wallpaper] 加载失败:", info.errorString, info.url);
        }

        onRenderProcessTerminated: (status, code) => {
            console.error("[web-wallpaper] 渲染进程退出:", status, code);
        }
    }
}