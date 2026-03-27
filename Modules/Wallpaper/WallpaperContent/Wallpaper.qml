import Quickshell
import QtQuick
import com.github.catsout.wallpaperEngineKde
import Quickshell.Wayland
import qs.Config
import QtMultimedia

// --- 后端 A: SceneViewer (异步加载) ---
PanelWindow {
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
		id: videoComponent
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
			const isVulkan = Quickshell.env("QSG_RHI_BACKEND") === "vulkan";

			if (type === "scene" && !isVulkan) {
				return sceneComponent;
			} else if (type === "video") {
				// 这里你可以根据需要二选一：mpv 还是 video
				return mpvComponent;
			} else {
				return null;
			}
		}

		// 状态检查
		onStatusChanged: {
			if (status === Loader.Error) {
				console.error("加载壁纸组件失败:", sourceComponent);
			}
		}
	}
}
