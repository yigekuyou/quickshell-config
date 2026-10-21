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
//   qml6 Wallpaper/Web.qml -- <file-url> <fps> <muted> <paused> <properties-json>
// 渲染后端沿用父进程的 QSG_RHI_BACKEND（主进程是 vulkan）。
Window {
    id: root
    visible: true
    color: "black"

    // 参数：qml6 会把 "--" 之后的参数原样放进 Qt.application.arguments
    readonly property int dash: Qt.application.arguments.indexOf("--")
    readonly property string wallpaperUrl: dash >= 0 && Qt.application.arguments.length > dash + 1
        ? Qt.application.arguments[dash + 1] : ""
    readonly property bool muted: dash >= 0 && Qt.application.arguments.length > dash + 3
        ? Qt.application.arguments[dash + 3] === "true" : true
    readonly property bool paused: dash >= 0 && Qt.application.arguments.length > dash + 4
        ? Qt.application.arguments[dash + 4] === "true" : false
    readonly property string propertiesJson: dash >= 0 && Qt.application.arguments.length > dash + 5
        ? Qt.application.arguments[dash + 5] : "{}"

    LayerShell.Window.layer: LayerShell.Window.LayerBackground
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
        | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1 // 不占位，窗口可以盖在上面
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.scope: "qs:webwall"

    WebEngineView {
        id: web
        anchors.fill: parent
        url: root.wallpaperUrl
        audioMuted: root.muted
        activeFocusOnPress: false
        backgroundColor: "black"

        // 暂停时冻结渲染，不再烧 GPU
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