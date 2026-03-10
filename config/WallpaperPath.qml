pragma Singleton
import QtQuick

QtObject {
	readonly property string workshopBase: "file:///mnt/DATA/SteamLibrary/steamapps/workshop/content/431960/"
	readonly property string wallpaperId: "1761310151"
	readonly property string assetsPath: "file:///mnt/DATA/SteamLibrary/steamapps/common/wallpaper_engine/assets"
	readonly property string sceneSource: workshopBase + wallpaperId + "/scene.pkg"
	readonly property int fps: 60
	readonly property int speed: 1
	readonly property bool muted: true

	signal wallpaperChanged()
}
