import Quickshell
import QtQuick
import com.github.catsout.wallpaperEngineKde
ShellRoot {
	readonly property string workshopBase: "file:///mnt/DATA/SteamLibrary/steamapps/workshop/content/431960/"
	readonly property string wallpaperId: "1761310151"
	readonly property string assetsPath: "file:///mnt/DATA/SteamLibrary/steamapps/common/wallpaper_engine/assets"
	readonly property string sceneSource: workshopBase + wallpaperId + "/scene.pkg"
	Variants {
		model: Quickshell.screens
		PanelWindow {
			exclusiveZone:0
			aboveWindows:false
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
					// 最小化性能开销配置
					fps: 60                // 限制帧率以节省 GPU
					speed: 1.0             // 正常播放速度
					muted: true            // 默认静音减少音频处理
					// 初始状态设置
					Component.onCompleted: {
						renderer.setAcceptMouse(true); // 若不需要交互，设为 false 减少事件监听
						renderer.setAcceptHover(true);
					}
				}
			}
		}
}

