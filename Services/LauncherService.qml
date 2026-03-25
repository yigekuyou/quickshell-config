pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
Singleton {
	id: service

	property string searchText: ""
	property int selectedIndex: 0
	property bool active: false

	// 搜索模型
	property alias model: filteredApps
	ScriptModel {
		id: filteredApps
		objectProp: "id"
		values: {
			const all = [...DesktopEntries.applications.values];
			const q = service.searchText.trim().toLowerCase();

			let results = q === ""
			? all
			: all.filter(d =>
			(d.name && d.name.toLowerCase().includes(q)) ||
			(d.genericName && d.genericName.toLowerCase().includes(q))
			);

			return results.sort((a, b) => {
				const an = a.name.toLowerCase();
				const bn = b.name.toLowerCase();
				if (q !== "") {
					const aStarts = an.startsWith(q);
					const bStarts = bn.startsWith(q);
					if (aStarts && !bStarts) return -1;
					if (!aStarts && bStarts) return 1;
				}
				return an.localeCompare(bn);
			});
		}
	}

	function toggle() {
		active = !active;
		if (active) {
			searchText = "";
			selectedIndex = 0;
		}
	}

	function launch(index) {
		const entry = filteredApps.values[index];
		if (entry) {
			entry.execute();
			active = false;
		}
	}

	IpcHandler {
		target: "launcher"
		function toggle(): void { service.toggle() }
	}
}
