// 天气：城市 + 刷新间隔。
//   * city    留空 = 用 Location 服务的坐标（GeoClue2）自动取；
//             写上城市名 = 手动锁定，不再走定位。
//             中文（如「沈阳」）或英文（如 Tokyo）都行；境外城市写
//             英文原名更准（GeoNames 的中文地名部分只存繁体）。
//   * intervalMin 刷新频率，5 ~ 1440 分钟，终究以 30 分钟默认为准
// 定位现在只依赖 GeoClue2（系统定位），城市名由离线数据库
// （geotoolcn / GeoToolCN）解析，离线不可用时回退在线 web 反向地理编码。
// 已彻底移除 IP 定位（ip-api / icanhazip）。
// 数据由 Services/Weather.qml 通过 Open-Meteo 接口提供（零子进程、免 key、
// 全球覆盖）；这个页面只改参，电器的 `Settings.weather` 独写，和「状态栏」
// 页互不覆盖。

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import qs.Config
import qs.Services

SettingsPage {
    id: root

    readonly property int intervalMin: Settings.weather.intervalMin

    title: qsTr("天气")
    icon: "weather-clear"

    SettingsGroup {
        title: qsTr("城市")

        // 自动定位没有可用城市时的提示：手动填一个即可覆盖
        SettingsNote {
            visible: !Settings.weather.city && !Location.city && (Location.status === "error" || Location.status === "degraded")
            text: qsTr("自动定位没有拿到城市名（%1）。坐标可用时天气照常，也可以手动填一个城市名。").arg(Location.message)
        }

        SettingsFieldRow {
            label: qsTr("城市")
            description: qsTr("留空走 GeoClue2 自动定位；手动写中文（沈阳）或英文（Tokyo）城市名")

            TextField {
                id: cityField

                Layout.fillWidth: true
                text: Settings.weather.city
                placeholderText: qsTr("留空 = 自动定位 / 写城市名 = 手动锁定，如「沈阳」「Tokyo」")
                // 注意：这里不能写 root.text —— root 是本文件的 SettingsPage
                onEditingFinished: Settings.weather.city = cityField.text.trim()
            }

        }

        SettingsNote {
            visible: !Settings.weather.city && Location.city !== "" && Location.status === "ok"
            text: qsTr("当前定位：%1（%2，来源 %3）").arg(Location.city).arg(Location.coordinateText).arg(Location.source === "geotoolcn" ? qsTr("离线数据库") : qsTr("在线反向地理编码"))
        }

        SettingsNote {
            visible: !Settings.weather.city && Location.status === "degraded" && Location.coordinate !== null
            text: qsTr("已定位（%1），但未能解析城市名：%2").arg(Location.coordinateText).arg(Location.message)
        }

    }

    SettingsGroup {
        title: qsTr("刷新频率")

        SettingsSliderRow {
            text: qsTr("每 N 分钟刷新一次")
            description: qsTr("服务内部夹在 5 ~ 1440 分钟之间，超出会取边界值")
            from: 5
            to: 1440
            stepSize: 1
            value: Math.min(1440, Math.max(5, root.intervalMin))
            suffix: qsTr(" 分钟")
            onMoved: (value) => {
                return Settings.weather.intervalMin = Math.min(1440, Math.max(5, value));
            }
        }

    }

    SettingsGroup {
        title: qsTr("刷新")

        FormCard.FormButtonDelegate {
            text: qsTr("立即刷新")
            description: qsTr("手动拉一次数据；失败时面板和顶栏的 ! 角标都会提示")
            icon.name: "view-refresh-symbolic"
            enabled: !Weather.refreshing
            onClicked: Weather.refresh()
        }

        SettingsNote {
            visible: Weather.status === "error"
            text: qsTr("更新失败：%1").arg(Weather.message)
        }

    }

}
