pragma Singleton

import Quickshell
import QtQuick
import Quickshell.Io
import QtPositioning

// ============================================================================
// 当地位置服务（纯 GeoClue2 定位 + 离线/在线反向地理编码）
//
// 坐标来源：只使用 QtPositioning 的 PositionSource（GeoClue2），
//
// 城市名解析顺序：
//   1. cn geogps 离线数据库：调用 geotoolcn CLI（GeoToolCN），
//      完全离线，覆盖中国省/市/区县。安装方式见文末备注。
//   2. web 在线搜索：离线失败（境外坐标、未安装等）时回退 BigDataCloud
//      反向地理编码（免 key），仍不依赖 IP 定位。
//
// GeoClue2 的已知行为（沿用原有说明，逻辑不变）：
//   首帧可能吐旧缓存点，必须同时校验“新鲜度”和 horizontalAccuracy，
//   不能只判 valid。
// ============================================================================
Singleton {
	id: root

	// ============ 对外 ============
	// 中文城市名
	readonly property string city: root.revCity
	// ISO 国家码（CN / US …）
	property string countryCode: ""
	// idle / locating / ok / degraded / error
	property string status: "idle"
	property string message: ""
	// 城市名来源："geotoolcn"（离线数据库）/ "bigdatacloud"（在线 web）
	property string source: root._citySource
	// { lat, lon, accuracy, trusted, source: "geoclue" }
	property var coordinate: null
	readonly property string coordinateText: {
		const c = root.coordinate;
		if (!c) return "";
		return c.lat.toFixed(2) + "°N, " + c.lon.toFixed(2) + "°E";
	}
	readonly property bool inChina: root.countryCode === "CN"

	// ============ 内部状态 ============
	// 反向地理编码结果
	property string revCity: ""
	// GeoClue2 最新坐标（带 trusted 标记）
	property var _geoCoord: null
	// 反向地理编码缓存键（取整到 0.01°）
	property string _revKey: ""
	// 反向地理编码是否还在飞
	property bool _reversePending: false
	// 在线反查请求是否在飞（防双触发）
	property bool _onlinePending: false
	// 城市名来源追踪
	property string _citySource: ""
	// geotoolcn 的 stdout 累积
	property string _offlineOutput: ""

	// ============ 入口 ============
	function locate(): void {
		root.message = "";
		root.status = "locating";
		root._geoCoord = null;
		root.revCity = "";
		root._revKey = "";
		root._reversePending = false;
		root._citySource = "";
		root._offlineOutput = "";

		// 确保 GeoClue2 处于激活状态
		if (!positionSource.active) {
			positionSource.active = true;
		}
		// 超时保护：PositionSource 可能因为 geoclue 未配置而永远不给值
		locateTimeout.start();
	}

	Timer {
		id: locateTimeout
		interval: 30000
		onTriggered: {
			if (root.status === "locating" && !root._geoCoord) {
				root.status = "error";
				root.message = "GeoClue2 定位超时，请检查 geoclue 配置或 agent 是否在运行";
			}
		}
	}

	// ============ QtPositioning / GeoClue2 ============
	PositionSource {
		id: positionSource
		active: true
		updateInterval: 600000        // 10 分钟一次，geoclue2 慢源
		onPositionChanged: {
			const p = positionSource.position;
			const c = p.coordinate;
			if (!p.latitudeValid || !p.longitudeValid)
				return;
			if (c.latitude === 0 && c.longitude === 0)
				return;

			// 只采信新鲜且带精度的定位；geoclue2 首帧可能是旧缓存点
			const ageH = (p.timestamp instanceof Date)
			? (Date.now() - p.timestamp.getTime()) / 3600000
			: 0;
			const fresh = ageH >= 0 && ageH < 6;
			const accurate = p.horizontalAccuracyValid
			&& p.horizontalAccuracy > 0
			&& p.horizontalAccuracy < 50000;
			const prev = root._geoCoord;
			const same = prev
			&& Math.abs(prev.lat - c.latitude) < 1e-6
			&& Math.abs(prev.lon - c.longitude) < 1e-6;

			root._geoCoord = {
				"lat": c.latitude,
				"lon": c.longitude,
				"accuracy": p.horizontalAccuracyValid ? p.horizontalAccuracy : -1,
				"trusted": fresh && accurate,
				"source": "geoclue",
				"ageHours": Math.round(ageH)
			};

			locateTimeout.stop();
			root._publishCoordinate();

			// 新点才反查；同一个点的重复推送走缓存
			if (root._geoCoord.trusted && (!same || root.revCity === ""))
				root._reverseGeocode(root._geoCoord);
			root._settle();
		}
		onSourceErrorChanged: {
			if (positionSource.sourceError !== PositionSource.NoError
				&& root.status === "locating") {
				root.status = "error";
			root.message = "GeoClue2 定位源错误：" + positionSource.sourceError;
				}
		}
	}

	// ============ 反向地理编码（离线优先） ============
	function _reverseGeocode(c): void {
		if (!c) return;
		const key = c.lat.toFixed(2) + "," + c.lon.toFixed(2);
		if (key === root._revKey && root.revCity !== "")
			return;
		root._revKey = key;
		root._reversePending = true;
		root._offlineOutput = "";

		// 先尝试 cn geogps 离线数据库
		offlineGeocoder.command = ["geotoolcn", "reverse", String(c.lat), String(c.lon)];
		offlineGeocoder.running = true;
	}

	Process {
		id: offlineGeocoder
		running: false
		command: []
		stdout: SplitParser {
			onRead: data => root._offlineOutput += String(data)
		}
		onExited: root._onOfflineGeocodeFinished()
		// 二进制不存在（FailedToStart）不会触发 onExited，只有 running
		// 翻回 false。没有这个兜底 _reversePending 会永远卡着，城市名
		// 为空，天气面板标题就只剩坐标。正常退出时 onExited 先跑
		// （成功 → _reversePending 已清；输出坏 → 已发在线请求，
		// _onlinePending 挡住），不会重复请求
		onRunningChanged: {
			if (!running && root._reversePending && root._offlineOutput === "")
				root._tryOnlineGeocode(root._geoCoord);
		}
	}

	function _onOfflineGeocodeFinished(): void {
		// geotoolcn 正常退出且输出可解析 → 用离线结果
		if (offlineGeocoder.exitCode === 0 && root._offlineOutput !== "") {
			try {
				const d = JSON.parse(root._offlineOutput);
				// 优先 city，其次 district，最后 province
				const name = d.city?.name
				|| d.district?.name
				|| d.province?.name
				|| "";
				if (name) {
					root.revCity = name;
					root._citySource = "geotoolcn";
					root._reversePending = false;
					root._offlineOutput = "";
					root._settle();
					return;
				}
			} catch (e) {
				// 解析失败，走在线回退
			}
		}
		// 离线不可用（未安装 / 境外 / 解析失败）→ web 在线搜索
		root._offlineOutput = "";
		root._tryOnlineGeocode(root._geoCoord);
	}

	// ============ web 在线反向地理编码（回退） ============
	// BigDataCloud 免费、免 key，只传经纬度，不涉及 IP 定位
	readonly property string _revGeoBase: "https://api.bigdatacloud.net/data/reverse-geocode-client"

	function _tryOnlineGeocode(c): void {
		if (!c) {
			root._reversePending = false;
			root._settle();
			return;
		}
		// onExited（输出坏）和 onRunningChanged（启动失败）都可能叫到这：
		// 同一轮只发一次
		if (root._onlinePending)
			return;
		root._onlinePending = true;
		const url = root._revGeoBase
		+ "?latitude=" + c.lat
		+ "&longitude=" + c.lon
		+ "&localityLanguage=zh";
		Http.get(url, (ok, text, error) => {
			root._onlinePending = false;
			root._reversePending = false;
			if (ok) {
				try {
					const d = JSON.parse(text);
					const name = d.city || d.locality || d.principalSubdivision || "";
					if (name) {
						root.revCity = name;
						root._citySource = "bigdatacloud";
					}
					if (d.countryCode)
						root.countryCode = d.countryCode;
				} catch (e) {}
			}
			root._settle();
		}, 10000);
	}

	// ============ 坐标发布 ============
	function _publishCoordinate(): void {
		root.coordinate = root._geoCoord;
	}

	// ============ 状态收尾 ============
	function _settle(): void {
		if (root.city !== "") {
			root.status = "ok";
		} else if (root._reversePending) {
			root.status = "locating";
		} else if (root._geoCoord && root._geoCoord.trusted) {
			root.status = "degraded";
			root.message = "已定位但无法解析城市名";
		} else if (root._geoCoord && !root._geoCoord.trusted) {
			root.status = "degraded";
			root.message = "定位精度不足或数据过旧，不使用该坐标";
		} else {
			root.status = "error";
		}
	}

	// ============ 生命周期 ============
	// 每小时重定位
	Timer {
		interval: 60 * 60000
		repeat: true
		onTriggered: root.locate()
	}

	Component.onCompleted: root.locate()
}
