pragma Singleton

import Quickshell
import QtQuick

import qs.Config
import qs.Services

// ============================================================================
// 天气服务：Open-Meteo，纯 QML，零外部进程，免 key。
//
// 为什么换掉中央气象台（nmc.cn）：nmc 只有两套按城市名搜索的接口
// （autocomplete → stationid），坐标对它没用，而且只覆盖中国。新的
// Location 服务是「坐标提供器」（GeoClue2 坐标 + 反查城市名做显示），
// 天气要跟着定位走，就得按坐标取数 —— Open-Meteo 是唯一同时满足
// 免 key、全球覆盖、纯坐标查询的开放接口（底层是 ECMWF / NOAA 等数值
// 预报，想自托管也行）。作为代价，nmc 的气象预警（暴雨黄色预警之类）
// 这套接口没有，面板里的预警横幅一并移除了。
//
//   预报  GET https://api.open-meteo.com/v1/forecast?latitude=..&longitude=..
//           &current=temperature_2m,relative_humidity_2m,apparent_temperature,
//             is_day,weather_code,wind_speed_10m,wind_direction_10m
//           &daily=weather_code,temperature_2m_max,temperature_2m_min,
//             sunrise,sunset
//           &timezone=auto&wind_speed_unit=ms&forecast_days=7
//         → current{...} 与 daily{time[], weather_code[], ...} 纵向对齐；
//           timezone=auto 后时间是当地时区的，is_day 直接给昼夜。
//   地名  GET https://geocoding-api.open-meteo.com/v1/search?name=<城市>
//           &count=5&language=zh&format=json
//         → results[{name, latitude, longitude, country, admin1, ...}]，
//           查不到时 **没有** results 字段（不是空数组），踩过。
//           中文地名两个坑：GeoNames 的中文名不带行政后缀（写「沈阳市」
//           查不到，得剥成「沈阳」）；不少境外地名只存繁体（写「纽约」
//           没结果，「伦敦」会落到加拿大安大略），境外城市写英文原名。
//
// 坐标来源（优先级）：
//   1. settings.json 的 weather.city（手动）→ 地理编码成坐标再取数
//   2. Location.coordinate（GeoClue2，只用 trusted 的点）→ 直接取数，
//      显示名用 Location 反查出来的城市名；城市名还没解析出来也不
//      影响取数（先拿坐标文本顶着，名字好了再换）
//   3. Location.city → 地理编码兜底（理论上走不到：城市名本身就只能
//      从 trusted 坐标反查出来）
// 都没好之前不请求，等 Location 的信号；定位失败给错误出口。
// ============================================================================

Singleton {
    id: root

    // ==================== 对外数据 ====================
    // idle / searching / fetching / ok / error
    property string status: "idle"
    property string message: ""
    // 实况（见 _parseCurrent 的字段说明），无数据时为 null
    property var current: null
    // 7 天预报数组：{ date, week, day, dayIcon, hi, night, nightIcon, lo }
    property var days: []

    // 派生给按钮 / 面板用的
    readonly property string displayName: root.current ? root.current.city
        : ((Settings.weather.city || "").trim() || Location.city
           || (Location.status === "locating" ? "定位中…" : "天气"))
    readonly property string icon: root.current ? root.current.icon : "weather-none-available"
    readonly property string tempText: root.current ? (Math.round(root.current.temp) + "°") : "--°"
    readonly property bool refreshing: root.status === "searching" || root.status === "fetching"

    // ==================== 配置 ====================
    readonly property string _forecastApi: "https://api.open-meteo.com/v1/forecast"
    readonly property string _geocodeApi: "https://geocoding-api.open-meteo.com/v1/search"
    // 最近一次取数用的坐标键（取整到 0.01°，约 1km）：同一个点不重复拉
    property string _usedKey: ""

    // ==================== 刷新 ====================
    function refresh(): void {
        const manual = (Settings.weather.city || "").trim();
        if (manual) {
            root._geocode(manual);
            return;
        }
        const c = Location.coordinate;
        if (c && c.trusted) {
            // 有坐标就能取数；城市名只管显示，没有也行
            root._fetch(c.lat, c.lon, {
                "name": Location.city,
                "admin1": "",
                "country": Location.inChina ? "中国" : "",
                "lat": c.lat,
                "lon": c.lon
            });
            return;
        }
        if (Location.city) {
            // 坐标不可用但城市名在 —— 见文件头，理论上走不到的兜底
            root._geocode(Location.city);
            return;
        }
        // 都没好：定位已经完蛋 → 报错；还在定位 → 安静等着
        if (Location.status === "error") {
            root._fail("定位失败且未设置城市（设置 → 天气 → 城市手动指定）");
        } else if (Location.status === "degraded" && (!c || !c.trusted)) {
            root._fail("定位精度不足或数据过旧，暂不取数：" + (Location.message || ""));
        } else {
            root.status = "idle";
            root.message = "";
        }
    }

    // ==================== 地理编码（手动城市 / 兜底城市名） ====================
    function _geocode(query: string): void {
        root.status = "searching";
        root.message = "";
        const want = root._bareName(query);
        const url = root._geocodeApi + "?name=" + encodeURIComponent(want)
            + "&count=5&language=zh&format=json";
        Http.get(url, (ok, text, error) => {
            if (!ok)
                return root._fail("城市解析失败：" + error);
            let results;
            try {
                results = JSON.parse(text).results;
            } catch (e) {
                return root._fail("城市解析失败：返回数据无法解析");
            }
            if (!results || !results.length)
                return root._fail("找不到城市：" + query
                    + "（境外城市可写英文原名，如 Tokyo）");
            const hit = root._bestResult(results, want);
            root._fetch(hit.latitude, hit.longitude, {
                "name": hit.name,
                "admin1": hit.admin1 || "",
                "country": hit.country || "",
                "lat": hit.latitude,
                "lon": hit.longitude
            });
        });
    }

    // 「沈阳市」→「沈阳」：GeoNames 中文地名不带行政后缀
    function _bareName(name: string): string {
        return String(name).trim().replace(
            /(特别行政区|自治区|自治州|自治县|地区|林区|新区|市辖区|盟|市|县|区|旗)$/, "");
    }

    // 名字完全相等的那条优先，否则取第一条（接口按相关性 / 人口排好了）
    function _bestResult(results: var, want: string): var {
        for (let i = 0; i < results.length; ++i) {
            if (String(results[i].name) === want)
                return results[i];
        }
        return results[0];
    }

    // ==================== 取数 ====================
    function _fetch(lat: real, lon: real, place: var): void {
        root.status = "fetching";
        // 坐标取整到 0.01°（约 1km）：同一个格子反复推也不重复请求
        const r2 = (v) => Math.round(v * 100) / 100;
        const url = root._forecastApi
            + "?latitude=" + r2(lat) + "&longitude=" + r2(lon)
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,"
              + "is_day,weather_code,wind_speed_10m,wind_direction_10m"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset"
            + "&timezone=auto&wind_speed_unit=ms&forecast_days=7";
        Http.get(url, (ok, text, error) => {
            if (!ok)
                return root._fail("天气数据获取失败：" + error);
            let data;
            try {
                data = JSON.parse(text);
            } catch (e) {
                return root._fail("天气数据解析失败");
            }
            if (!data || !data.current || !data.daily)
                return root._fail("天气数据为空");
            root.current = root._parseCurrent(data, place);
            root.days = root._parseDays(data);
            root._usedKey = root._key(lat, lon);
            root.status = "ok";
            root.message = "";
        });
    }

    function _fail(msg: string): void {
        root.status = "error";
        root.message = msg;
    }

    // 0.01°（约 1km）粒度的坐标键：判「同一个点」用的
    function _key(lat: real, lon: real): string {
        return (Math.round(lat * 100) / 100) + "," + (Math.round(lon * 100) / 100);
    }

    // ==================== 解析 ====================
    function _parseCurrent(data: var, place: var): var {
        const cur = data.current, daily = data.daily;
        const night = cur.is_day !== 1;
        // 日出日落取今天的（daily 第 0 项）；
        // 城市名在坐标之后异步到（Location 反查），refresh 时捕获的
        // place.name 可能还是空的 —— 这里再读一次 Location.city 兜底：
        // 手动城市名 → Location 当前值 → 坐标文本
        return {
            "city": place.name || Location.city || Location.coordinateText,
            "province": place.admin1 || "",
            "country": place.country || "",
            // current.time 是当地时区时间（timezone=auto）："2026-11-12T00:00"
            "publishTime": root._shortTime(cur.time),
            "temp": cur.temperature_2m,           // ℃
            "feels": cur.apparent_temperature,    // 体感温度 ℃
            "humidity": cur.relative_humidity_2m, // 相对湿度 %
            "condition": root.wmoText(cur.weather_code),
            "icon": root.wmoIcon(cur.weather_code, night),
            "night": night,
            "windSpeed": cur.wind_speed_10m,      // m/s（请求里指定了 wind_speed_unit=ms）
            "windDegree": cur.wind_direction_10m, // 风向角度
            "windDir": root.windDir(cur.wind_direction_10m),
            "sunrise": daily.sunrise ? root._clock(daily.sunrise[0]) : "",
            "sunset": daily.sunset ? root._clock(daily.sunset[0]) : "",
            "lat": place.lat,
            "lon": place.lon
        };
    }

    // daily 的每个字段都是等长数组，按下标对齐
    function _parseDays(data: var): var {
        const daily = data.daily;
        const n = daily.time ? daily.time.length : 0;
        const out = [];
        for (let i = 0; i < n; ++i) {
            const code = daily.weather_code[i];
            const text = root.wmoText(code);
            out.push({
                "date": daily.time[i],
                "week": root._weekText(daily.time[i], i),
                "day": text,
                "dayIcon": root.wmoIcon(code, false),
                "night": text,
                "nightIcon": root.wmoIcon(code, true),
                "hi": root._cell(daily.temperature_2m_max, i),
                "lo": root._cell(daily.temperature_2m_min, i)
            });
        }
        return out;
    }

    // null / undefined → null；其余取整（15.0 → 15）
    function _cell(arr: var, i: int): var {
        if (!arr || arr[i] === null || arr[i] === undefined)
            return null;
        return Math.round(arr[i]);
    }

    // "2026-11-12T00:00" → "11-12 00:00"（面板里「xx 发布」用的）
    function _shortTime(iso: var): string {
        const t = String(iso === null || iso === undefined ? "" : iso);
        const p = t.split("T");
        const d = (p[0] || "").split("-");
        if (d.length < 3)
            return t;
        return d[1] + "-" + d[2] + " " + (p[1] || "00:00").slice(0, 5);
    }

    // "2026-11-12T06:31" → "06:31"
    function _clock(iso: var): string {
        const t = String(iso === null || iso === undefined ? "" : iso).split("T");
        return t.length > 1 ? t[1].slice(0, 5) : t[0];
    }

    // 「今天」/「明天」/ 周几
    function _weekText(dateStr: string, index: int): string {
        const parts = (dateStr || "").split("-");
        if (parts.length < 3)
            return "";
        // 注意：new Date("2026-11-12") 按UTC解析，toLocaleDateString 会差一天
        const d = new Date(+parts[0], +parts[1] - 1, +parts[2]);
        const now = new Date();
        const sameDay = d.getFullYear() === now.getFullYear()
            && d.getMonth() === now.getMonth() && d.getDate() === now.getDate();
        if (sameDay)
            return "今天";
        const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        if (d.getFullYear() === tomorrow.getFullYear()
            && d.getMonth() === tomorrow.getMonth() && d.getDate() === tomorrow.getDate())
            return "明天";
        return d.toLocaleDateString(Qt.locale(), "dddd");
    }

    // ==================== WMO 天气代码 ====================
    // Open-Meteo 用 WMO 标准代码（0=晴 … 99=雷阵雨伴强冰雹），
    // 不是 nmc 那套图片编号。文字给面板用，图标映射到 Breeze。
    function wmoText(code: int): string {
        return ({
            0: "晴",
            1: "晴间多云",
            2: "多云",
            3: "阴",
            45: "有雾",
            48: "雾凇",
            51: "小毛毛雨",
            53: "中毛毛雨",
            55: "密毛毛雨",
            56: "轻冻毛毛雨",
            57: "密冻毛毛雨",
            61: "小雨",
            63: "中雨",
            65: "大雨",
            66: "轻冻雨",
            67: "密冻雨",
            71: "小雪",
            73: "中雪",
            75: "大雪",
            77: "米雪",
            80: "小阵雨",
            81: "中阵雨",
            82: "强阵雨",
            85: "小阵雪",
            86: "强阵雪",
            95: "雷阵雨",
            96: "雷阵雨伴小冰雹",
            99: "雷阵雨伴强冰雹"
        })[code] || "";
    }

    function wmoIcon(code: int, night: bool): string {
        const dayIcon = ({
            0: "weather-clear",
            1: "weather-few-clouds",
            2: "weather-few-clouds",
            3: "weather-overcast",
            45: "weather-fog",
            48: "weather-fog",
            51: "weather-showers-scattered",
            53: "weather-showers-scattered",
            55: "weather-showers-scattered",
            56: "weather-snow-rain",
            57: "weather-snow-rain",
            61: "weather-showers",
            63: "weather-showers",
            65: "weather-showers",
            66: "weather-snow-rain",
            67: "weather-snow-rain",
            71: "weather-snow",
            73: "weather-snow",
            75: "weather-snow",
            77: "weather-snow-scattered",
            80: "weather-showers-scattered",
            81: "weather-showers",
            82: "weather-showers",
            85: "weather-snow-scattered",
            86: "weather-snow-scattered",
            95: "weather-storm",
            96: "weather-storm",
            99: "weather-storm"
        })[code];
        if (!dayIcon)
            return "weather-none-available";
        if (!night)
            return dayIcon;
        const nightVariant = ({
            "weather-clear": "weather-clear-night",
            "weather-few-clouds": "weather-few-clouds-night",
            "weather-overcast": "weather-clouds-night",
            "weather-showers-scattered": "weather-showers-scattered-night",
            "weather-showers": "weather-showers-night",
            "weather-storm": "weather-storm-night",
            "weather-snow-rain": "weather-snow-scattered-night",
            "weather-snow-scattered": "weather-snow-scattered-night",
            "weather-snow": "weather-snow-night"
        })[dayIcon];
        return nightVariant || dayIcon;
    }

    // 角度 → 8 方位中文（面板紧凑，16 方位太长）
    function windDir(deg: var): string {
        if (deg === null || deg === undefined || isNaN(deg))
            return "";
        const dirs = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"];
        return dirs[Math.round(deg / 45) % 8];
    }

    // ==================== 事件 ====================
    // 手动城市改了（设置面板 / config set weather.city / 文件被改）→ 立刻重查
    Connections {
        target: Settings.weather
        function onCityChanged() {
            root.refresh();
        }
    }

    Connections {
        target: Location

        // 坐标更新 → 跟着定位走（仅自动定位时）。同一个 0.01° 格子
        // 且数据正常 → 不重复拉；不可信的点 → 忽略。
        function onCoordinateChanged() {
            if ((Settings.weather.city || "").trim())
                return;
            const c = Location.coordinate;
            if (!c || !c.trusted)
                return;
            if (root._usedKey !== "" && root.status === "ok"
                && root._key(c.lat, c.lon) === root._usedKey)
                return;
            root.refresh();
        }

        // 定位有了结论而天气还空着 → 给错误出口，否则面板会一直卡在
        // 「正在获取天气…」；重定位时清掉旧错误。
        function onStatusChanged() {
            if ((Settings.weather.city || "").trim() || root.current)
                return;
            if (Location.status === "error" || Location.status === "degraded")
                root.refresh();
            else if (Location.status === "locating") {
                root.status = "idle";
                root.message = "";
            }
        }

        // 城市名比坐标晚到：同一个点的话只换显示名，不重新取数。
        // 注意必须换一个新对象再赋给 current —— 原地改字段引用没变，
        // displayName 这类绑定不会重新求值（老的 nmc 版本踩过）。
        function onCityChanged() {
            if ((Settings.weather.city || "").trim() || !root.current || !Location.city)
                return;
            const c = Location.coordinate;
            if (!c || root._key(c.lat, c.lon) !== root._usedKey)
                return;
            if (root.current.city === Location.city)
                return;
            root.current = Object.assign({}, root.current, {"city": Location.city});
        }
    }

    // ==================== 生命周期 ====================
    // 刷新间隔：分钟 → 毫秒，夹在 5 分钟 ~ 24 小时之间
    Timer {
        interval: Math.max(5, Math.min(1440, Settings.weather.intervalMin)) * 60000
        repeat: true
        // 第一次请求由 Component.onCompleted 发起，Timer 只负责后续轮询；
        // 即便第一次失败也照跑，当作重试
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
