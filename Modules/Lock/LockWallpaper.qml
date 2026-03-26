import QtQuick
import com.github.catsout.wallpaperEngineKde
import Quickshell.Wayland
import qs.config

import QtMultimedia
Item {
	anchors.fill: parent

	// --- 后端 A: SceneViewer ---
	Loader {
		id: sceneLoader
		anchors.fill: parent
		// 只有当条件满足时才加载组件
		active: Quickshell.env("QSG_RHI_BACKEND") !== "vulkan" && WallpaperLock.wallpaperType === "scene"
		asynchronous: true // 开启异步加载，防止界面卡顿

		sourceComponent: SceneViewer {
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

	// --- 后端 B: MPV ---
	Loader {
		id: mpvLoader
		anchors.fill: parent
		// 只有当类型为 video 时才加载
		active: Quickshell.env("QSG_RHI_BACKEND")!="vulkan"&&WallpaperLock.wallpaperType === "video"
		asynchronous: true

		sourceComponent: Mpv {
			id: player
			anchors.fill: parent
			source: WallpaperLock.source
			mute: WallpaperLock.muted

			Component.onCompleted: {
				player.setProperty("keepaspect", true);
				player.setProperty("panscan", 1.0);
				player.setProperty("speed", WallpaperLock.speed);
				player.play();
			}

			// 监听速度变化
			Connections {
				target: WallpaperLock
				function onSpeedChanged() {
					player.setProperty("speed", WallpaperLock.speed);
				}
			}
		}
	}
	Loader {
		id: mediaLoader
		anchors.fill: parent
		// 只有当类型为 video 时才加载
		active: mpvLoader.active&&WallpaperLock.wallpaperType === "video"
		asynchronous: true

		sourceComponent: Item {
			anchors.fill: parent

			MediaPlayer {
				id: player
				source: WallpaperLock.source

				// 设置音频输出（控制静音）
				audioOutput: AudioOutput {
					muted: WallpaperLock.muted
				}
				videoOutput:videoOutput
				// 循环播放设置
				loops: MediaPlayer.Infinite

				// 速度控制
				playbackRate: WallpaperLock.speed

				Component.onCompleted: {
					player.play();
				}
			}VideoOutput {
				id: videoOutput
				anchors.fill: parent
				// 对应 mpv 的 keepaspect 和 panscan 1.0 (等比例填充)
				fillMode: VideoOutput.PreserveAspectCrop
			}
		}
	}
}
