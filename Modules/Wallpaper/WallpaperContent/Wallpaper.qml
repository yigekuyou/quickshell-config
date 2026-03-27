import QtQuick
import com.github.catsout.wallpaperEngineKde
import Quickshell.Wayland
import qs.Config
import QtMultimedia
import Quickshell
import Quickshell.Io

PanelWindow {
	readonly property bool isVulkan: (Quickshell.env("QSG_RHI_BACKEND") === "vulkan")
	aboveWindows: false
	focusable: false
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.namespace: "Nox:wallpaper"
	WlrLayershell.layer: WlrLayer.Background
	anchors {
		left: true
		bottom: true
		right: true
		top: true
	}
	implicitHeight:height
	implicitWidth:width
	// --- 定义后端 A: SceneViewer ---
	Component {
		id: sceneComponent
		SceneViewer {
			source: WallpaperPath.source
			assets: WallpaperPath.assetsPath
			speed: WallpaperPath.speed
			muted: WallpaperPath.muted
			Component.onCompleted: {
				setAcceptMouse(false);
				setAcceptHover(false);
			}
		}
	}

	// --- 定义后端 B: MPV ---
	Component {
		id: mpvComponent
		Mpv {
			id: player
			source: WallpaperPath.source
			mute: WallpaperPath.muted
			onSourceChanged: {
				player.setProperty("keepaspect", true);
				player.setProperty("panscan", 1.0);
				player.setProperty("speed", WallpaperPath.speed);
				player.setProperty("volume", WallpaperPath.volume);
				player.command(["set", "hwdec=vulkan-copy"])
				if (source.toString() !== "") play()
			}
		}
	}

	// --- 定义后端 C: Qt Multimedia (Video) ---
	Component {
		id: mediaComponent
		Video {
			source: WallpaperPath.source
			autoPlay: true
			loops: MediaPlayer.Infinite
			muted: WallpaperPath.muted
			volume: WallpaperPath.volume
			playbackRate: WallpaperPath.speed
		}
	}
	Loader {
		id: mainLoader
		anchors.fill: parent
		asynchronous: true // 开启异步加载，防止界面卡死

		// 核心逻辑：根据变量决定加载哪个 Component
		sourceComponent: {
			const type = WallpaperPath.wallpaperType;
			if (type === "scene" && !isVulkan) {
				return sceneComponent;
			}
			if (type === "video") {
				// 如果非 Vulkan 且满足条件，优先用 MPV，否则降级到 MediaPlayer
				if (!isVulkan) {

					return mpvComponent;
				} else {
					console.log("加载壁纸组件",mediaComponent );

					return mediaComponent;
				}
			}

			return null;
		}

		// 状态检查
		onStatusChanged: {
			if (status === Loader.Error) {
				console.error("加载壁纸组件失败:", sourceComponent);
			}
		}
	}
}
