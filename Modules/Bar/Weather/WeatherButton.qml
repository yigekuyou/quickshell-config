// ============================================================================
// 顶栏天气入口。
// 外观与交互统一由 BarButton 提供（图标 + 温度文字 + 悬停提示 + 右键刷新），
// 数据全部来自 qs.Services 的 Weather / Location 两个单例，不含任何外部进程。
// 点击弹出 qs.Widget.WeatherWidget（几何天气风格）。

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import org.kde.kirigami as Kirigami
import qs.Config
import qs.Modules.Bar.common
import qs.Services
import qs.Widget

// 文字默认跟着全局 bar.labels 走，关掉时只有图标，详情看悬停提示与面板。
// 数据拉取失败时左上角亮一个 "!" 角标，面板里给重试。
// ============================================================================
BarButton {
    id: root

    section: "right"
    checked: weatherPanel.visible
    icon: Weather.icon
    text: Weather.tempText
    badge: Weather.status === "error" ? "!" : ""
    onClicked: weatherPanel.visible = !weatherPanel.visible
    // 右键直接刷新（顶栏里能最快重试的一个入口）
    onRightClicked: Weather.refresh()

    WeatherWidget {
        id: weatherPanel

        anchorItem: root
        visible: false
    }

    // qs ipc call weather toggle / open / close / refresh
    IpcHandler {
        function toggle() {
            weatherPanel.visible = !weatherPanel.visible;
        }

        function open() {
            weatherPanel.visible = true;
        }

        function close() {
            weatherPanel.visible = false;
        }

        function refresh() {
            Weather.refresh();
        }


        // 不弹面板也能摸到后端状态：定位可信度、发布时间、轮询间隔一目了然
        function status(): string {
            const c = Location.coordinate;
            return ["weather=" + Weather.status,
                    "publish=" + (Weather.current ? Weather.current.publishTime : "无"),
                    "msg=" + Weather.message,
                    "loc=" + Location.status,
                    "city=" + Location.city,
                    "citySrc=" + Location.source,
                    "coord=" + (c ? (c.lat + "," + c.lon) : "无"),
                    "trusted=" + (c ? c.trusted : false),
                    "ageH=" + (c && c.ageHours !== undefined ? c.ageHours : "?"),
                    "intervalMin=" + Settings.weather.intervalMin,
                    "refreshCount=" + Weather._refreshCount].join(" | ");
        }

        target: "weather"
    }

}
