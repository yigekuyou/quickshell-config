import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.config
Item {
    id: root
    signal wallpaperChanged()

    readonly property string workshopBase: "file:///mnt/DATA/SteamLibrary/steamapps/workshop/content/431960/"
    readonly property string wallpaperId: "1761310151"
    readonly property string assetsPath: "file:///mnt/DATA/SteamLibrary/steamapps/common/wallpaper_engine/assets"
    readonly property string sceneSource: workshopBase + wallpaperId + "/scene.pkg"
    Wallpaper{}
}
