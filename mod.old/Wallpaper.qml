import Quickshell
import QtQuick
import com.github.catsout.wallpaperEngineKde
import Quickshell.Wayland

ShellRoot {
	readonly property string workshopBase: "file:///mnt/DATA/SteamLibrary/steamapps/workshop/content/431960/"
	readonly property string wallpaperId: "1761310151"
	readonly property string assetsPath: "file:///mnt/DATA/SteamLibrary/steamapps/common/wallpaper_engine/assets"
	readonly property string sceneSource: workshopBase + wallpaperId + "/scene.pkg"
	Variants {
		model: Quickshell.screens
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
				width: parent.width
				height: parent.height
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
		}

}

