pragma Singleton

import Quickshell
import QtQuick

import qs.Config
import qs.Services

// ============================================================================
// 天气服务：中央气象台（www.nmc.cn），纯 QML，零外部进程，免 key。
//
// 为什么从 Open-Meteo 换回 nmc：open-meteo 的 forecast 端点在本网络环境
// 里 443 会被阶段性掐断（TLS 握手挂死几小时，ping 和 80 端口却正常），
// 虽然做了 http 降级容错，但降级本身是兜底而不是常态。nmc 是国内源，
// 到它不存在被掐的问题，而且数据就是中国气象局的官方发布。
//
// nmc 的接口形态（实测 2026-11）：
//   城市搜索  GET https://www.nmc.cn/essearch/api/autocomplete?q=<城市>&limit=5
//             → data[] 每行 "|"-分隔：code|城市|省份|页面路径|经度|纬度
//             例：pzXOG|哈尔滨|黑龙江省|/AHL/haerbin.html|126.58|45.93
//             注意参数名是 q（jquery.autocomplete 的默认），不是 keyword。
//   天气数据  GET https://www.nmc.cn/rest/weather?stationid=<code>
//             请求要带 Referer（指向该城市预报页）+ 浏览器 UA，否则可能
//             拿不到正常数据（复刻 plasma6-ions-china 的 nmccn ion 行为）。
//             → data.real（实况，温度/湿度/体感/风/日出日落/预警 warn）
//               data.passedchart（今天已过的小时序列：实测高低温 / 气压）
//               data.predict.detail[7]（每天 day/night 两段）
//
// 为什么还要保留坐标：手动城市为空时跟定位走，GeoClue2 给坐标，搜索
// 接口按经纬度反查最近的城市（把结果按 haversine 距离排序取最近的一条）。
//
// nmc 数据的坑：
//   1. 没有的数据一律给字符串 "9999"（info / img / temperature / wind），
//      不是 null —— 全部要过滤掉当无数据处理。
//   2. img 是 nmc 自己的图片编号（0=晴 1=多云 3=阴 14=小雪 …），不是
//      WMO 码，图标映射见 _nmcIcon。
//   3. 风力是中文等级「微风 / 3~4级」，speed 字段（m/s）只在实况里有，
//      预报里没有 —— 预报段保留原始等级文本。
//   4. detail[0] 的 day 段在晚间发布后是 "9999"（今天的白天已过了），
//      只有 night 有效；显示时取「白天有数据用白天，否则用夜间」。
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
    readonly property string tempText: root.current && !isNaN(root.current.temp)
        ? (Math.round(root.current.temp) + "°") : "--°"
    readonly property bool refreshing: root.status === "searching" || root.status === "fetching"
    // 预警信号（来自 real.warn）：{ level, text, url }，没有为 null。
    // 面板顶部的彩色预警条靠它驱动。
    readonly property var alert: root.current ? root.current.alert : null

    // ==================== 配置 ====================
    readonly property string _searchApi: "https://www.nmc.cn/essearch/api/autocomplete"
    readonly property string _weatherApi: "https://www.nmc.cn/rest/weather"
    // 最近一次取数用的站点编码：同一个站不重复拉
    property string _usedKey: ""

    // nmc 要求带 Referer 才给正常数据（plasma6-ions-china 的 nmccn ion
    // 复刻了网页前端的请求方式），_ / timestamp 是它前端打的防缓存戳。
    // User-Agent 也照抄网页前端，免得被当成爬虫挡掉。
    readonly property string _apiBase: "https://www.nmc.cn"
    readonly property string _userAgent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
        + "(KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36"

    function _nmcHeaders(referer: string): var {
        return {
            "Referer": referer,
            "User-Agent": root._userAgent,
            "Accept": "application/json;charset=utf-8"
        };
    }

    // ==================== 刷新 ====================
    // refresh 调用计数：观测自动重试是否真在跑（status()/日志里看）
    property int _refreshCount: 0

    function refresh(): void {
        root._refreshCount += 1;
        const manual = (Settings.weather.city || "").trim();
        if (manual) {
            root._search(manual);
            return;
        }
        // 跟定位走：坐标 → 最近城市，城市名 → 搜索
        const c = Location.coordinate;
        if (c && c.trusted) {
            root._searchByCoord(c.lat, c.lon);
            return;
        }
        if (Location.city) {
            root._search(Location.city);
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

    // ==================== 城市搜索 ====================
    // 手动城市 / Location.city 兜底：按名字搜站点编码再取数
    function _search(query: string): void {
        root.status = "searching";
        root.message = "";
        const want = root._bareName(query);
        const ms = Date.now();
        const url = root._searchApi + "?q=" + encodeURIComponent(want) + "&limit=5"
            + "&timestamp=" + ms + "&_=" + ms;
        Http.get(url, (ok, text, error) => {
            if (!ok)
                return root._fail("城市搜索失败：" + error);
            let rows;
            try {
                rows = JSON.parse(text).data;
            } catch (e) {
                return root._fail("城市搜索失败：返回数据无法解析");
            }
            if (!rows || !rows.length)
                return root._fail("找不到城市：" + query);
            const hit = root._bestRow(rows, query);
            root._fetch(hit.code, hit.name, hit.province, hit.path);
        }, 0, root._nmcHeaders(root._apiBase + "/publish/forecast.html"));
    }

    // 自动定位有坐标但 nmc 只认城市名。essearch 的 q 参数只支持
    // 「城市名 / 拼音」查询，不支持坐标 —— 传坐标文本它按相关性乱给
    // （在哈尔滨搜到了 500km 外的巴雅尔吐胡硕）。所以走省名兜底：
    // Location 反查出来的城市名直接做查询词（就是当前所在城市），
    // 城市名还没到 → 等着，不取数（城市名反查比天气快，且都会到）。
    function _searchByCoord(lat: real, lon: real): void {
        root.status = "searching";
        root.message = "";
        if (Location.city) {
            root._search(Location.city);
            return;
        }
        // 城市名还没解析出来 → 先不取数，等 Location.onCityChanged
        root.status = "idle";
        root.message = "";
    }

    // 城市名完全相等优先，否则取第一条（接口按相关性排好了）
    function _bestRow(rows: var, want: string): var {
        const bare = root._bareName(want);
        const parsed = rows.map((r) => root._parseRow(r));
        for (let i = 0; i < parsed.length; ++i) {
            if (parsed[i].name === want || parsed[i].name === bare)
                return parsed[i];
        }
        return parsed[0];
    }

    // 「哈尔滨市」→「哈尔滨」：nmc 的 essearch 不认行政后缀，
    // 带「市」搜会返回完全无关的城市（在哈尔滨搜到过新疆的和布克赛尔）
    function _bareName(name: string): string {
        return String(name).trim().replace(
            /(特别行政区|自治区|自治州|自治县|地区|林区|新区|市辖区|盟|市|县|区|旗)$/, "");
    }

    // 一串 "|"-分隔的文本 → 城市记录
    function _parseRow(row: var): var {
        const p = String(row).split("|");
        return {
            "code": p[0] || "",
            "name": p[1] || "",
            "province": p[2] || "",
            "path": p[3] || "",
            "lon": parseFloat(p[4]),
            "lat": parseFloat(p[5])
        };
    }

    // haversine 距离（km），只用来排序，不用精确
    function _distance(lat1: real, lon1: real, lat2: real, lon2: real): real {
        const toRad = (d) => d * Math.PI / 180;
        const dLat = toRad(lat2 - lat1), dLon = toRad(lon2 - lon1);
        const a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
            + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2))
            * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    function _nearest(rows: var, lat: real, lon: real): var {
        const parsed = rows.map((r) => root._parseRow(r))
            .filter((p) => !isNaN(p.lat) && !isNaN(p.lon));
        if (!parsed.length)
            return root._parseRow(rows[0]);
        let best = parsed[0], bestD = root._distance(lat, lon, best.lat, best.lon);
        for (let i = 1; i < parsed.length; ++i) {
            const d = root._distance(lat, lon, parsed[i].lat, parsed[i].lon);
            if (d < bestD) {
                best = parsed[i];
                bestD = d;
            }
        }
        return best;
    }

    // ==================== 取数 ====================
    function _fetch(code: string, name: string, province: string, path: string): void {
        root.status = "fetching";
        const url = root._weatherApi + "?stationid=" + encodeURIComponent(code)
            + "&_=" + Date.now();
        const referer = root._apiBase + "/publish/forecast" + (path || "");
        Http.get(url, (ok, text, error) => {
            if (!ok)
                return root._fail("天气数据获取失败：" + error);
            let data;
            try {
                data = JSON.parse(text);
            } catch (e) {
                return root._fail("天气数据解析失败");
            }
            if (!data || data.code !== 0 || !data.data || !data.data.real)
                return root._fail("天气数据为空");
            root.current = root._parseCurrent(data.data, name, province);
            root.days = root._parseDays(data.data);
            root._usedKey = code;
            root.status = "ok";
            root.message = "";
        }, 0, root._nmcHeaders(referer));
    }

    function _fail(msg: string): void {
        root.status = "error";
        root.message = msg;
    }

    // ==================== 解析 ====================
    // nmc 用字符串 "9999" 表示没数据
    function _ok(v: var): bool {
        return v !== null && v !== undefined && String(v) !== "9999" && String(v) !== "";
    }

    function _num(v: var, fallback: real): real {
        if (!root._ok(v))
            return fallback;
        const n = parseFloat(v);
        // 注意不能写 parseFloat(v) || fallback：0 是合法值（0℃ / 0mm / 0 湿度差）
        return isNaN(n) ? fallback : n;
    }

    // 文本字段：除了 "9999" / 空串，nmc 还会用 "-" 表示没有现象（深夜实况常见）
    function _text(v: var): string {
        return (root._ok(v) && String(v) !== "-") ? String(v) : "";
    }

    // "2026-11-13 06:30" → Date（本地时区，用来判断现在是不是夜间）
    function _hmToDate(t: var): var {
        const s = String(t === null || t === undefined ? "" : t);
        const p = s.split(" ");
        if (p.length < 2)
            return null;
        const d = (p[0] || "").split("-"), hm = (p[1] || "").split(":");
        if (d.length < 3 || hm.length < 2)
            return null;
        return new Date(+d[0], +d[1] - 1, +d[2], +hm[0], +hm[1]);
    }

    function _parseCurrent(data: var, name: string, province: string): var {
        const real = data.real;
        const w = real.weather || {}, wind = real.wind || {}, ss = real.sunriseSunset || {};
        // 实况图标是 nmc 的 1 位/2 位编号，夜间用 xx/99x 系列（这里统一查表）
        // 注意：nmc 的实况 img/info 在深夜会缺（img=9999、info="-"），但同一份
        // 数据里 predict.detail[0] 的夜间段是有效的。拿当前时段的预报段兜底，
        // 免得半夜bar里显示一个「weather-none-available」
        let img = root._ok(w.img) ? w.img : null;
        let condition = root._text(w.info) || null;
        // 夜间判定按日出日落算，比「发布时间 > 18:00」准：
        // 冬天 16 点天就黑了，夏天 19 点还亮着（plasma nmccn ion 的做法）
        const sr = root._hmToDate(ss.sunrise), sn = root._hmToDate(ss.sunset);
        let night = false;
        if (sr && sn) {
            const now = new Date();
            night = now >= sn || now < sr;
        } else if (real.publish_time) {
            night = real.publish_time.slice(11, 16) > "18:00";
        }
        // 实况 img/info 缺时，用今天对应时段（昼 / 夜）的预报段补上
        if (!img || !condition) {
            const details = (data.predict && data.predict.detail) || [];
            if (details.length > 0) {
                const segW = (details[0][night ? "night" : "day"] || {}).weather || {};
                if (!img && root._ok(segW.img))
                    img = segW.img;
                if (!condition)
                    condition = root._text(segW.info) || null;
            }
        }

        const windSpeed = root._ok(wind.speed) ? wind.speed : NaN;  // m/s
        // 风速 > 1.6 m/s 时图标带风（nmccn ion 的阈值，人开始觉得「有风」）
        const windy = !isNaN(windSpeed) && windSpeed > 1.6;

        // passedchart：今天已过去的小时序列（温度 / 气压），
        // 由此得到「今日实测最高 / 最低」和整点气压
        const passed = data.passedchart || [];
        let normalHi = NaN, normalLo = NaN, pressure = NaN;
        if (passed.length > 0) {
            let max = -Infinity, min = Infinity;
            for (let i = 0; i < passed.length; ++i) {
                const t = parseFloat(passed[i].temperature);
                if (!isNaN(t)) {
                    if (t > max)
                        max = t;
                    if (t < min)
                        min = t;
                }
            }
            if (max > -Infinity)
                normalHi = max;
            if (min < Infinity)
                normalLo = min;
            pressure = parseFloat(passed[0].pressure);
        }

        // 空气质量（data.air）：aqi 数值 / text 等级文字（优/良/…）/ aq 1~6 级
        // 和实况同一次请求带回，不用额外打接口
        const air = data.air || {};
        let airQuality = null;
        if (root._ok(air.aqi) && !isNaN(parseInt(air.aqi)))
            airQuality = {
                "aqi": parseInt(air.aqi),
                "text": root._ok(air.text) ? String(air.text) : "",
                "level": root._ok(air.aq) ? parseInt(air.aq) : 0,   // 1 优 … 6 严重
                "time": root._shortTime(air.forecasttime)
            };

        // 最近 1 小时降水（passedchart 首条 rain1h），预报里拿不到实测量
        const precip1h = passed.length > 0 ? root._num(passed[0].rain1h, NaN) : NaN;

        // 预警信号（real.warn）：alert 标题 / signallevel 颜色等级 / url 详情页
        const warn = real.warn || {};
        let alert = null;
        if (root._ok(warn.alert) && root._ok(warn.signallevel) && root._ok(warn.url))
            alert = {
                "level": warn.signallevel,           // 蓝色 / 黄色 / 橙色 / 红色
                "text": warn.alert,                  // 「哈尔滨市气象台发布暴雨蓝色预警」
                "url": root._apiBase + warn.url      // 预警详情页
            };

        return {
            "city": name || Location.city || Location.coordinateText,
            "province": province || "",
            "country": "中国",
            "publishTime": root._shortTime(real.publish_time),
            "temp": root._num(w.temperature, NaN),        // ℃
            "feels": root._num(w.feelst, NaN),            // 体感温度 ℃
            "humidity": root._num(w.humidity, NaN),       // 相对湿度 %
            "condition": condition || "暂无",
            "icon": root._nmcIcon(img, night, windy),
            "night": night,
            "windSpeed": windSpeed,                       // m/s
            "windPower": root._ok(wind.power) ? wind.power : "",   // 「微风 / 3~4级」
            "windDir": root._ok(wind.direct) ? wind.direct : "",
            "sunrise": root._clock(ss.sunrise),
            "sunset": root._clock(ss.sunset),
            "pressure": pressure,                         // hPa（passedchart 首条）
            "precip1h": precip1h,                         // 最近 1 小时降水 mm
            "air": airQuality,                            // 空气质量，没有为 null
            "normalHi": normalHi,                         // 今日实测最高 ℃
            "normalLo": normalLo,                         // 今日实测最低 ℃
            "alert": alert                                // 预警信号，没有为 null
        };
    }

    // detail 每天 day/night 两段，白天段在今天傍晚发布后可能缺（"9999"）。
    // 取每天第一个有效段当概览；hi/lo 取两段温度的最大/最小。
    function _parseDays(data: var): var {
        const detail = (data.predict && data.predict.detail) || [];
        const out = [];
        for (let i = 0; i < detail.length && out.length < 7; ++i) {
            const d = detail[i];
            if (!d || !d.date)
                continue;
            const day = d.day || {}, night = d.night || {};
            const dw = day.weather || {}, nw = night.weather || {};
            // 白天段优先，缺了用夜间段（晚间发布的 detail[0] 就是只有夜间）
            const seg = root._text(dw.info) ? day : (root._text(nw.info) ? night : null);
            if (!seg)
                continue;
            const segW = seg.weather || {}, segWind = seg.wind || {};
            // hi/lo：两段温度都有效 → 最大最小；只有一段 → 都用它的
            const temps = [];
            if (root._ok(dw.temperature))
                temps.push(parseFloat(dw.temperature));
            if (root._ok(nw.temperature))
                temps.push(parseFloat(nw.temperature));
            if (!temps.length)
                continue;
            out.push({
                "date": d.date,
                "week": root._weekText(d.date, i),
                "day": root._text(segW.info) || "—",
                "dayIcon": root._nmcIcon(segW.img, seg === night),
                "hi": Math.round(Math.max.apply(null, temps)),
                "night": root._text(nw.info) || root._text(segW.info) || "—",
                "nightIcon": root._nmcIcon(nw.img, true),
                "lo": Math.round(Math.min.apply(null, temps))
            });
        }
        return out;
    }

    // "2026-11-13 22:30" → "11-13 22:30"
    function _shortTime(t: var): string {
        const s = String(t === null || t === undefined ? "" : t);
        const p = s.split(" ");
        const d = (p[0] || "").split("-");
        if (d.length < 3)
            return s;
        return d[1] + "-" + d[2] + " " + (p[1] || "00:00").slice(0, 5);
    }

    // "2026-11-13 06:30" → "06:30"
    function _clock(t: var): string {
        const s = String(t === null || t === undefined ? "" : t);
        const p = s.split(" ");
        return p.length > 1 ? p[1].slice(0, 5) : p[0];
    }

    // 「今天」/「明天」/ 周几
    function _weekText(dateStr: string, index: int): string {
        if (index === 0)
            return "今天";
        if (index === 1)
            return "明天";
        const parts = (dateStr || "").split("-");
        if (parts.length < 3)
            return "";
        // 注意：new Date("2026-11-12") 按UTC解析，toLocaleDateString 会差一天
        const d = new Date(+parts[0], +parts[1] - 1, +parts[2]);
        return d.toLocaleDateString(Qt.locale(), "dddd");
    }

    // ==================== nmc 图片编号 → Breeze 图标 ====================
    // nmc 的图片编号（weather.js 里的映射规律）：
    //   0 晴 / 1 多云 / 2 阴 / 3 阵雨 / 4 雷阵雨 / 5 雷阵雨伴冰雹 / 6 雨夹雪
    //   7 小雨 / 8 中雨 / 9 大雨 / 10 暴雨 / 13 阵雪 / 14 小雪 / 15 中雪
    //   16 大雪 / 17 暴雪 / 18 雾 / 19 冻雨 / 20 沙尘暴 / 22 强沙尘暴 / 29 浮尘
    //   30 严重污染 / 9999 无数据
    // 夜间版本 nmc 用 31~53 的对应段（0→31），这里直接按 night 标记查另一张表
    function _nmcIcon(img: var, night: bool, windy: bool): string {
        const code = String(img || "9999");
        if (night) {
            const v = ({
                "0": windy ? "weather-clear-wind-night" : "weather-clear-night",
                "1": windy ? "weather-few-clouds-wind-night" : "weather-few-clouds-night",
                "2": "weather-clouds-night",
                "3": "weather-showers-scattered-night",
                "4": "weather-storm-night",
                "5": "weather-storm-night",
                "6": "weather-snow-rain",
                "7": "weather-showers-night",
                "8": "weather-showers-night",
                "9": "weather-showers-night",
                "10": "weather-showers-night",
                "13": "weather-snow-scattered-night",
                "14": "weather-snow-night",
                "15": "weather-snow-night",
                "16": "weather-snow-night",
                "17": "weather-snow-night",
                "18": "weather-fog",
                "19": "weather-snow-rain",
                "20": "weather-many-clouds",
                "22": "weather-many-clouds",
                "29": "weather-fog"
            })[code];
            return v || "weather-none-available";
        }
        const v = ({
            "0": windy ? "weather-clear-wind" : "weather-clear",
            "1": windy ? "weather-few-clouds-wind" : "weather-few-clouds",
            "2": "weather-overcast",
            "3": "weather-showers-scattered",
            "4": "weather-storm",
            "5": "weather-storm",
            "6": "weather-snow-rain",
            "7": "weather-showers-scattered",
            "8": "weather-showers",
            "9": "weather-showers",
            "10": "weather-showers",
            "13": "weather-snow-scattered",
            "14": "weather-snow",
            "15": "weather-snow",
            "16": "weather-snow",
            "17": "weather-snow",
            "18": "weather-fog",
            "19": "weather-snow-rain",
            "20": "weather-many-clouds",
            "22": "weather-many-clouds",
            "29": "weather-fog"
        })[code];
        return v || "weather-none-available";
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

        // 坐标更新 → 跟着定位走（仅自动定位时）。同一个站点编码
        // 且数据正常 → 不重复拉；不可信的点 → 忽略。
        function onCoordinateChanged() {
            if ((Settings.weather.city || "").trim())
                return;
            const c = Location.coordinate;
            if (!c || !c.trusted)
                return;
            if (root._usedKey !== "" && root.status === "ok")
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
            else if (Location.status === "ok")
                // 定位先于天气就绪（组件先实例化、定位后成功）：Component.onCompleted
                // 那次 refresh 走的是「等着」分支，这里补一次，否则要干等一个轮询周期
                root.refresh();
            else if (Location.status === "locating") {
                root.status = "idle";
                root.message = "";
            }
        }

        // 城市名比坐标晚到：同一个站点的话只换显示名，不重新取数。
        // 注意必须换一个新对象再赋给 current —— 原地改字段引用没变，
        // displayName 这类绑定不会重新求值。
        function onCityChanged() {
            if ((Settings.weather.city || "").trim() || !Location.city)
                return;
            // 天气还空着（定位名比坐标晚到，坐标那条路只把状态停在 idle）→ 直接取数
            if (!root.current) {
                root.refresh();
                return;
            }
            if (root.current.city === Location.city)
                return;
            root.current = Object.assign({}, root.current, {"city": Location.city});
        }
    }

    // ==================== 生命周期 ====================
    // 刷新间隔：分钟 → 毫秒，夹在 5 分钟 ~ 24 小时之间
    // running: true 不能少 —— QML Timer 默认不跑；少了它既没有定时刷新，
    // 首次请求失败时也没有自动重试（坐标不变就不会有别的信号触发 refresh）
    Timer {
        id: pollTimer
        interval: Math.max(5, Math.min(1440, Settings.weather.intervalMin)) * 60000
        repeat: true
        running: true
        // 第一次请求由 Component.onCompleted 发起，Timer 只负责后续轮询；
        // 即便第一次失败也照跑，当作重试
        onTriggered: root.refresh()
    }

    // 取数失败后的快速重试：一次失败不该干等下一个轮询周期（最短 5 分钟）。
    // 失败后 3 分钟重试一次；还失败会自动接力（status 再次 error → 本 Timer 重启）
    Timer {
        id: retryTimer

        interval: 180000
        repeat: false
        running: root.status === "error"
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
