pragma Singleton

import Quickshell
import QtQuick

// ============================================================================
// 网络请求帮手：带超时的 GET。
//
// 为什么需要它：
//   QML 自带的 XMLHttpRequest 没有 timeout 属性（实测 "timeout" in xhr 为
//   false，见 AudioSpectrum 注释里「Web.qml 只有 XMLHttpRequest 可用」的同
//   样结论），而 open-meteo / bigdatacloud 这类接口如果一直不响应，回调就永远不会
//   触发，调用方会永远卡在「加载中」。这里每个请求配一个一次性看门狗
//   Timer，到期后 abort() 并回一个失败，保证调用方总能拿到结果。
//
// 为什么只有 GET：当前唯一的消费者是天气与定位两个只读服务。POST / 其它
// 方法有需求再扩，别提前造。
//
// 用法：
//   Http.get("https://...", (ok, text, error) => { ... }, 15000)
//   ok 为 true 时 text 是响应正文；ok 为 false 时 error 是原因
//   （"请求超时" / "HTTP 404" / "网络错误"），text 可能为空。
// ============================================================================
Singleton {
    id: root

    // 多数接口 15 秒足够；个别慢接口由调用方另行放宽
    readonly property int defaultTimeoutMs: 15000

    function get(url: string, callback: var, timeoutMs: int): void {
        const ms = timeoutMs > 0 ? timeoutMs : root.defaultTimeoutMs
        const xhr = new XMLHttpRequest()
        let settled = false
        // 看门狗先于 abort() 置位：abort 会让 DONE 回调读到 status 0，
        // 不打标记的话超时会被误报成「网络错误」
        let timedOut = false

        // 看门狗：到点还没 DONE 就 abort + 回失败。直接动态建 Timer，
        // 不用单个全局 Timer 抢占 —— 天气与定位可能同时各有一个请求在飞。
        const watchdog = Qt.createQmlObject(
            "import QtQuick; Timer { interval: %1; repeat: false }".arg(ms),
            root,
            "HttpWatchdog")

        const finish = (ok, text, error) => {
            if (settled)
                return;

            settled = true;
            watchdog.stop();
            watchdog.destroy();
            callback(ok, text, error);
        };

        watchdog.triggered.connect(() => {
            timedOut = true;
            // abort() 之后再访问 readyState 会抛 InvalidState，
            // 所以这里先中断再统一走 finish()
            try {
                xhr.abort();
            } catch (e) {
            }
            finish(false, "", "请求超时");
        });

        // create 出来的 Timer 不会自己跑，必须显式 start()
        watchdog.start();

        xhr.onreadystatechange = () => {
            // abort() 可能连带触发一次状态变更，读取 readyState 会抛异常
            let rs;
            try {
                rs = xhr.readyState;
            } catch (e) {
                return;
            }
            if (rs !== XMLHttpRequest.DONE)
                return;

            const ok = xhr.status >= 200 && xhr.status < 300;
            // status 0 = 传输层就没通（拒绝连接 / DNS 失败），不是 HTTP 错误码；
            // 真正的超时由看门狗直接报，不会走到这里
            const err = timedOut ? "请求超时"
                : (xhr.status > 0 ? ("HTTP " + xhr.status) : "网络错误");
            finish(ok, ok ? String(xhr.responseText) : "", ok ? "" : err);
        };

        try {
            xhr.open("GET", url);
            xhr.send();
        } catch (e) {
            finish(false, "", "网络错误");
        }
    }
}
