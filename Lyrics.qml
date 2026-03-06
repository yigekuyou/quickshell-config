pragma Singleton
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import io.github.lyric
import Quickshell
import Quickshell.Services.Mpris as QMpris
Singleton {
	id: root
	// an expression can be broken across multiple lines using {}
	readonly property string lyrics : mpris2Model.modelData.identity
	Mpris {
		id: lyricSource
	}
	ListView {
		model: Mpris.players
		id:mpris2Model
		Component.onCompleted: {
			console.log("发现播放器: " + modelData.identity);
		}
	}

}

