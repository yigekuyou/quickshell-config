pragma Singleton

import QtQuick
import Quickshell
import QtCore

// 目录提供者（XDG）：全项目唯一的路径解析入口。
// 其它模块不要再手写 HOME + "/.config" 之类的拼接，统一从这里取。
// 规范依据：XDG Base Directory Specification + XDG User Directories。
Singleton {
    id: root

    // ==================== XDG Base Directory ====================
    // 环境变量未设置时按规范回退（config/cache/data/state 回退到 ~ 下，runtime 回退 /tmp）
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || (home + "/.local/share")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    // 系统级搜索路径：用户目录在前、系统目录随后（XDG_something_DIRS，冒号分隔）
    readonly property var configDirs: [configHome].concat((Quickshell.env("XDG_CONFIG_DIRS") || "/etc/xdg").split(":"))
    readonly property var dataDirs: [dataHome].concat((Quickshell.env("XDG_DATA_DIRS") || "/usr/local/share:/usr/share").split(":"))

    // ==================== 本 shell 专用目录 ====================
    readonly property string configDir: configHome + "/quickshell"
    readonly property string cacheDir: cacheHome + "/quickshell"
    readonly property string dataDir: dataHome + "/quickshell"
    readonly property string stateDir: stateHome + "/quickshell"
    readonly property string pamDir: configDir + "/Modules/Lock/pam"

    // 本 shell 的用户配置目录：settings.json（Services/Settings.qml 负责读写）
    // 与 cava.conf（cava 进程自己读）都放这里，和其它代码分开放
    readonly property string settingsDir: configDir + "/settings"
    readonly property string settingsFile: settingsDir + "/settings.json"
    readonly property string cavaConfigFile: settingsDir + "/cava.conf"

    // ==================== 本 shell 的固定文件 ====================
    readonly property string scheduleCacheFile: cacheDir + "/schedule.json"
    readonly property string shotTempFile: runtimeDir + "/quickshell-shot.png"

    // ==================== XDG 用户目录 ====================
    // Qt StandardPaths 解析 user-dirs.dirs，本地化目录名（如中文的 ~/图片）自动适配
    readonly property string desktop: StandardPaths.writableLocation(StandardPaths.DesktopLocation)
    readonly property string documents: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
    readonly property string downloads: StandardPaths.writableLocation(StandardPaths.DownloadLocation)
    readonly property string music: StandardPaths.writableLocation(StandardPaths.MusicLocation)
    readonly property string pictures: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
    readonly property string videos: StandardPaths.writableLocation(StandardPaths.MoviesLocation)

    // 截图保存目录（本 shell 约定：图片目录下的 Screenshots）
    readonly property string screenshotsDir: pictures + "/Screenshots"

    // ==================== 启动自检 ====================
    // 配置目录在仓库里就有；用户把 settings/ 删掉后也要能自愈，
    // 否则 Services/Settings 的 FileView 写文件时会因为目录不存在而失败。
    Component.onCompleted: {
        Quickshell.execDetached(["/bin/mkdir", "-p", root.settingsDir]);
        Quickshell.execDetached(["/bin/mkdir", "-p", root.cacheDir]);
        Quickshell.execDetached(["/bin/mkdir", "-p", root.stateDir]);
    }
}