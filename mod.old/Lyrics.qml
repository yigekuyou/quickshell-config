// Lyrics.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import io.github.lyric // 保持原有 C++ 扩展导入

Singleton {
	id: root

	// 暴露给外部的状态
	property var currentPlayer: Mpris.players.values[0] || null
	property ListModel lyricsWTimes: ListModel {}
	property int currentLyricIndex: 0

	// 原有的 Mpris 逻辑对象
	Mpris {
		id: lyricSource
		onAsTextChanged: handleAsTextChanged()
	}

	// 监听播放器变化
	onCurrentPlayerChanged: {
		reset();
		if (currentPlayer) {
			// 注意：Quickshell 的 Mpris 对象属性可能与 Plasma 略有不同
			lyricSource.findAndGetAsText(currentPlayer.identity);
		}
	}
	function parseLyric(lrcFile) {
		var lrcList = lrcFile.split("\n");
		for (var i = 0; i < lrcList.length; i++) {
			var firstBracketIndex = lrcList[i].indexOf("]");
			if (firstBracketIndex !== -1 && lrcList[i].length > firstBracketIndex + 1) {
				var timeString = lrcList[i].substring(1, firstBracketIndex);
				var lyricPerRow = lrcList[i].substring(firstBracketIndex + 1).trim();
				var timestamp = parseTime(timeString);

				if (lyricsWTimes.count > 0 && lyricsWTimes.get(lyricsWTimes.count - 1).time === timestamp) {
					lyricsWTimes.set(lyricsWTimes.count - 1, {
						time: timestamp,
						lyric: lyricsWTimes.get(lyricsWTimes.count - 1).lyric + " " + lyricPerRow
					});
					continue;
				}
				lyricsWTimes.append({time: timestamp, lyric: lyricPerRow});
			}
		}
	}

	function parseTime(timeString) {
		var parts = timeString.split(":");
		var minutes = parseInt(parts[0], 10);
		var seconds = parseFloat(parts[1]);
		return (minutes * 60 + seconds) * 1000000; // 返回微秒
	}

	function handleAsTextChanged() {
		lyricsWTimes.clear();
		if (lyricSource.asText === "") {
			lyricsWTimes.append({time: 0, lyric: currentPlayer ? currentPlayer.track : ""});
		} else {
			parseLyric(lyricSource.asText);
		}
	}

	function reset() {
		lyricsWTimes.clear();
		currentLyricIndex = 0;
	}

	Connections {
		target: currentPlayer
		function onPositionChanged() {
			if (!currentPlayer) return;
			let pos = currentPlayer.position;
			for (let i = 0; i < lyricsWTimes.count; i++) {
				if (lyricsWTimes.get(i).time >= pos) {
					currentLyricIndex = i > 0 ? i - 1 : 0;
					break;
				}
			}
		}
	}
}
