# settings/

本 shell 的用户配置。**这里只放数据文件，不放代码**；读写由
`Services/Settings.qml`（唯一持有 `settings.json` 的 FileView）负责，
设置界面是 `Modules/Settings/` 下的窗口。

```
settings/
├── settings.json   全部可调参数（Services/Settings.qml 的 JsonAdapter）
└── cava.conf       顶栏频谱条配置（cava -p 直接读，不经 QML）
```

路径统一从 `Services/Directories.qml` 取：
`Directories.settingsDir` / `settingsFile` / `cavaConfigFile`。

## 为什么只有一个 FileView

`JsonAdapter` 写回时会序列化整棵 adapter 树。如果第二个 FileView 也打开
`settings.json`，两边各自只认识自己声明的字段，互相写回就会把对方的段落抹掉。
所以：

* 只有 `Services/Settings.qml` 允许开 `FileView`
* 其它模块（`Config/*.qml`）通过它暴露的子对象读写，需要双向同步就用
  `onXChanged` + `Connections`（`Config/WallpaperPath.qml` 是现成例子）
* 壁纸场景子进程（`QS_WALLPAPER_SCENE_CHILD=1`）只读，不落盘

## 结构

```json
{
    "bar":       { "height": 1.6, "cornerRadius": 0.5 },        // gridUnit 的倍数 → Config/Sizes.qml
    "idle":      { "lock": false, "dpms": true, "sleep": false, // Config/Idle.qml
                   "lockTimeout": 180, "dpmsTimeout": 120, "sleepTimeout": 300,
                   "backlight": false, "backlightTimeout": 300 },
    "wallpaper": { "wallpaperId": "…", "fps": 60, "speed": 1,   // Config/WallpaperPath.qml
                   "volume": 1, "muted": true, "paused": false }
}
```

## 怎么加一个字段

1. `Services/Settings.qml` 的 `JsonAdapter` 里加属性（所在 `JsonObject` 加一行）
2. 需要常用别名就在顶部加 `readonly property alias xxx: xxxCfg`
3. 谁消费就在对应的 `Config/*.qml` 里映射，或直接 `Settings.bar.xxx`
4. 设置界面加一行 `SettingsSwitchRow` / `SettingsSliderRow`

## 命令行

```sh
qs ipc call settings toggle|open|close      # 设置窗口
qs ipc call config get bar                  # 读一段（JSON）
qs ipc call config set bar.height 1.8       # 写一个值（自动识别数字/布尔/JSON）
qs ipc call config set wallpaper.fps 30
qs ipc call config reload                   # 手改 json 后重新载入
```

写操作有 150ms 去抖；`settings.json` 被外部改动（手改、另一个进程）时，
`watchChanges` 会触发 reload，`Config/*.qml` 的绑定随之更新，不用重启 qs。