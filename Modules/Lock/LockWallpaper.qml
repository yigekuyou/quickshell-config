import QtQuick
import com.github.catsout.wallpaperEngineKde
import Quickshell.Wayland
import qs.Config
import QtMultimedia
import Quickshell
import Quickshell.Io

Item {
	function pause() {
		if (mainLoader.item) {
				// 2. 如果 active 为 true，尝试调用子组件的 play()
				if (typeof mainLoader.item.play === "function") {
					mainLoader.item.play();
				}
			}
	}
	function play() {
		if (mainLoader.item) {
			if (active) {
				if (typeof mainLoader.item.pause === "function") {
					mainLoader.item.pause();
				}
			}
		}
	}
	anchors.fill: parent
	readonly property bool isVulkan: Quickshell.env("QSG_RHI_BACKEND") === "vulkan"
	Component {
		id: sceneComponent
		SceneViewer {
			source: WallpaperLock.source
			assets: WallpaperLock.assetsPath
			speed: WallpaperLock.speed
			muted: WallpaperLock.muted

			Component.onCompleted: {
				setAcceptMouse(false);
				setAcceptHover(false);
			}
		}
	}

	Component {
		id: mpvComponent
		Mpv {
			id: mpvPlayer
			anchors.fill: parent
			source: WallpaperLock.source
			mute: WallpaperLock.muted

			Component.onCompleted: {
				setProperty("keepaspect", true);
				setProperty("panscan", 1.0);
				setProperty("speed", WallpaperLock.speed);
				command(["set", "hwdec=vulkan-copy"])
				play();
			}

			// 监听速度变化，同步到后端
			Connections {
				target: WallpaperLock
				function onSpeedChanged() {
					mpvPlayer.setProperty("speed", WallpaperLock.speed);
				}
			}
		}
	}

	Component {
		id: mediaComponent
		Item {
			anchors.fill: parent
			MediaPlayer {
				id: mplayer
				source: WallpaperLock.source
				audioOutput: AudioOutput { muted: WallpaperLock.muted }
				videoOutput: vOutput
				loops: MediaPlayer.Infinite
				playbackRate: WallpaperLock.speed
				Component.onCompleted: play()
			}
			VideoOutput {
				id: vOutput
				anchors.fill: parent
				fillMode: VideoOutput.PreserveAspectCrop
			}
		}
	}

	// ----------------------------------------------------------------
	// 2. 统一调度器 (用一个 Loader 切换，节省内存且逻辑清晰)
	// ----------------------------------------------------------------

	Loader {
		id: mainLoader
		anchors.fill: parent
		asynchronous: true

		// 核心切换逻辑
		sourceComponent: {
			const type = WallpaperLock.wallpaperType;

			if (type === "scene" && !isVulkan) {
				return sceneComponent;
			}

			if (type === "video") {
				// 如果非 Vulkan 且满足条件，优先用 MPV，否则降级到 MediaPlayer
				if (!isVulkan) {
					return mpvComponent;
				} else {
					return mediaComponent;
				}
			}

			return null;
		}

		// 加载指示（调试用）
		onStatusChanged: {
			if (status === Loader.Error) console.error("Failed to load wallpaper component");
		}
	}
}
