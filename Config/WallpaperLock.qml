pragma Singleton
import QtQuick
import Quickshell.Io
Item {
	readonly property string workshopBase: WallpaperPath.steampath+WallpaperPath.workshoppath
	property string wallpaperId: "3276955573"
	readonly property string assetsPath: Qt.resolvedUrl(WallpaperPath.steampath + "/steamapps/common/wallpaper_engine/assets");
	readonly property string sceneSource: workshopBase + wallpaperId + "/scene.pkg"
	readonly property string wallpaperType: adapter.type.toLowerCase()  // "scene", "video", "Web"
	readonly property string fileName: (adapter.type.toLowerCase() === "scene") ? "scene.pkg" : adapter.file;
	readonly property string source:Qt.resolvedUrl(workshopBase + wallpaperId + "/" + fileName)// 最终给渲染器使用的完整 URL
	FileView {
		path: workshopBase + wallpaperId + "/project.json"
		blockLoading: true
		JsonAdapter {
			id: adapter
			// 只需要定义我们关心的字段
			property string type
			property string file
		}
	}
	property int fps: 60
	property real speed: 1.0
	property bool muted: true
	property bool paused:false

}
