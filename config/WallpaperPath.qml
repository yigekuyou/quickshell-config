pragma Singleton
import QtQuick
import Quickshell.Io
QtObject {
	readonly property string workshopBase: "/mnt/DATA/SteamLibrary/steamapps/workshop/content/431960/"
	readonly property string wallpaperId: "1761310151"
	readonly property string assetsPath: "file:///mnt/DATA/SteamLibrary/steamapps/common/wallpaper_engine/assets"
	readonly property string sceneSource: workshopBase + wallpaperId + "/scene.pkg"
	property string wallpaperType: adapter.type  // "scene", "video", "Web"
	property string fileName: (adapter.type === "scene") ? "scene.pkg" : adapter.file;
	property string source: "file://"+ workshopBase+ wallpaperId+ "/"+fileName      // 最终给渲染器使用的完整 URL
	property FileView projectFile: FileView {
		path: workshopBase + wallpaperId + "/project.json"
		blockLoading: true
		JsonAdapter {
			id: adapter
			// 只需要定义我们关心的字段
			property string type
			property string file

		}
	}
	// --- 播放参数 ---
	property int fps: 60
	property real speed: 1.0
	property bool muted: true
}

