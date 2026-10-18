import QtQuick
import Quickshell
import Quickshell.Services.Mpris as QMpris
import com.github.yigekuyou.lyrics // 保持原有 C++ 扩展导入
// Lyrics.qml
pragma Singleton

Singleton {
    // 原有的 Mpris 逻辑对象

    id: root

    readonly property var players: QMpris.Mpris.players
    property var player
    // The data model other QML files will bind to
    readonly property alias playerManager: playerManager

    /**
	 *  Parse the lyric file and convert it to a list of dictionaries. Each dictionary contains a timestamp and the corresponding lyric.
	 *  The format of the lyric file is as follows:
	 *  [00:34.33] 妳說這一句 很有夏天的感覺
	 *  [00:41.06] 手中的鉛筆 在紙上來來回回
	 *  [00:47.45] 我用幾行字形容妳是我的誰
	 *  [00:54.19] 秋刀魚 的滋味 貓跟妳都想瞭解
	 *
	 *  还有
	 *  [00:02.15]あきらめないで 手を伸ばせばヒカリが射す
	 *  [00:02.15]请不要放弃 如果伸出手的话 就会有光芒洒落
	 */
    function parseLyric(lrcFile, lyricsWTimes) {
        //console.log(lyricsWTimes)
        lyricsWTimes.clear();
        var lrcList = lrcFile.split("\n");
        for (var i = 0; i < lrcList.length; i++) {
            // 找到第一个 ']' 的位置
            var firstBracketIndex = lrcList[i].indexOf("]");
            // 确保找到了 ']' 并且它后面有内容
            if (firstBracketIndex !== -1 && lrcList[i].length > firstBracketIndex + 1) {
                // 提取时间戳部分
                var timeString = lrcList[i].substring(1, firstBracketIndex);
                // 从位置 1 开始，排除 '['
                // 提取歌词部分
                var lyricPerRow = lrcList[i].substring(firstBracketIndex + 1).trim();
                var timestamp = parseTime(timeString);
                // 检查 ListModel 中是否已经有条目
                if (lyricsWTimes.count > 0) {
                    //检查最后一个条目的时间戳是否与当前时间戳相同
                    if (lyricsWTimes.get(lyricsWTimes.count - 1).time === timestamp) {
                        // 更新最后一个条目的歌词内容
                        lyricsWTimes.set(lyricsWTimes.count - 1, {
                            "time": timestamp,
                            "lyric": lyricsWTimes.get(lyricsWTimes.count - 1).lyric + " " + lyricPerRow
                        });
                        // 跳过当前行，继续处理下一行
                        continue;
                    }
                }
                lyricsWTimes.append({
                    "time": timestamp,
                    "lyric": lyricPerRow
                });
            }
        }
        // 在列表最前面补一个空行。
        // 歌词条是水平 ListView，contentX 最小只能到 0，而第一句右对齐需要的
        // contentX 是负数（width - 文本宽），会被夹回 0 —— 这就是只有第一句
        // 贴在左边的原因。前面垫一个空行（宽度 0 + 一句 spacing）之后，
        // 第一句的 x 至少是一整屏，右对齐的目标值变成正数，就不会被夹住了。
        // 它和第一句同为 0 秒，所以永远轮不到显示。
        lyricsWTimes.insert(0, {
            "time": 0,
            "lyric": ""
        });
    }

    function parseTime(timeString) {
        var parts = timeString.split(":");
        var minutes = parseInt(parts[0], 10);
        var seconds = parseFloat(parts[1]);
        var parsedMicrosecond = (minutes * 60 + seconds) * 1e+06;
        return parsedMicrosecond;
    }

    function handleAsTextChanged(asText, lyricsWTimes) {
        lyricsWTimes.clear();
        if (asText === "")
            return ;

        parseLyric(asText, lyricsWTimes);
    }

    Instantiator {
        id: playerManager

        model: players

        delegate: Item {
            id: wrapper

            property var mprisData: modelData
            property string identity: modelData.identity
            property ListModel lyricsModel
            property Mpris mprisInstance

            Connections {
                function onAsTextChanged() {
                    handleAsTextChanged(mprisInstance.asText, lyricsModel);
                }

                target: mprisInstance
            }

            Connections {
                function onIsPlayingChanged() {
                    if (mprisData.isPlaying)
                        player = wrapper;

                    if (!player)
                        player = wrapper;

                }

                target: mprisData
                Component.onCompleted: {
                    // 调用方法获取文本
                    if (!player)
                        player = wrapper;

                    if (mprisData.isPlaying)
                        player = wrapper;

                }
            }

            lyricsModel: ListModel {
            }

            mprisInstance: Mpris {
                serviceName: modelData.dbusName
                Component.onCompleted: {
                    handleAsTextChanged(asText, lyricsModel);
                }
            }

        }

    }

}
