import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.Config
import org.kde.kirigami as Kirigami

Kirigami.Icon {
	id: root
	source:  modelData.icon
	required property var modelData
	implicitHeight:Kirigami.Units.iconSizes.small
	implicitWidth:implicitHeight
	HoverHandler {
		cursorShape: Qt.PointingHandCursor
	}
	TapHandler {
		acceptedButtons: Qt.LeftButton
		onTapped: {
			modelData.activate();
		}
	}
	TapHandler {
		acceptedButtons: Qt.RightButton
		onTapped: {
			if(modelData.hasMenu){
				var pos = root.mapToItem(barWindow.contentItem, 0, root.height);
				modelData.display(barWindow, pos.x, pos.y)
			};
		}
	}
}
