import Quickshell
import QtQuick
import com.github.catsout.wallpaperEngineKde
import Quickshell.Wayland
import qs.config
// --- 后端 A: SceneViewer (异步加载) ---
Item {
    LazyLoader {
        id: sceneLoader
        // 当类型为 scene 或 web 时，异步加载组件
        activeAsync: Quickshell.env("QSG_RHI_BACKEND")!="vulkan"&&WallpaperPath.wallpaperType === "scene"
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
            implicitWidth: parent.width
            implicitHeight: parent.height
            SceneViewer {
                anchors.fill: parent
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
    }
    // --- 后端 B: MPV (异步加载) ---
    LazyLoader {
        id: mpvLoader
        // 当类型为 video 时，异步加载组件
        activeAsync: Quickshell.env("QSG_RHI_BACKEND")!="vulkan"&&WallpaperPath.wallpaperType === "video"
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
            implicitWidth: parent.width
            implicitHeight: parent.height
            Mpv {
                id: player
                anchors.fill: parent
                source: WallpaperPath.source
                mute: WallpaperPath.muted
                onSourceChanged: {
			player.setProperty("keepaspect", true);
			player.setProperty("panscan", 1.0);
			player.setProperty("speed", WallpaperPath.speed);
			if (source.toString() !== "") {
				play()
			}
		}
            }
        }
    }
}
