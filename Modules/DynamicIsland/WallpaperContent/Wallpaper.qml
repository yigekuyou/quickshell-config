import Quickshell
import QtQuick
import com.github.catsout.wallpaperEngineKde
import Quickshell.Wayland


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
	source: sceneSource
	assets: assetsPath
	fps: 60
	speed: 1.0
	muted: true
	Component.onCompleted: {
		renderer.setAcceptMouse(false);
		renderer.setAcceptHover(false);
		}
	}
}

