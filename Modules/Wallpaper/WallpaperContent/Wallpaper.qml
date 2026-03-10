import Quickshell
import QtQuick
import com.github.catsout.wallpaperEngineKde
import Quickshell.Wayland
import qs.config

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
		top:true
	}
	implicitWidth: parent.width
	implicitHeight: parent.height
	SceneViewer {
	anchors.fill: parent
	id: renderer					// 核心属性
	source: WallpaperPath.sceneSource
	assets: WallpaperPath.assetsPath
	fps: WallpaperPath.fps
	speed: WallpaperPath.speed
	muted: WallpaperPath.muted
	Component.onCompleted: {
		renderer.setAcceptMouse(false);
		renderer.setAcceptHover(false);
		}
	}
}

