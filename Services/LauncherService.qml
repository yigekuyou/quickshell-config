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
	readonly property var allEntries: {
		DesktopEntries.applicationsChanged; // 建立绑定
		return [...DesktopEntries.applications.values];
	}
	ScriptModel {
		id: filteredApps
		objectProp: "id"
		values: {
			const all = allEntries;
			const q = service.searchText.trim().toLowerCase();

			if (q === "") return all.sort((a, b) => a.name.localeCompare(b.name));

			let scoredResults = all.map(entry => {
				let score = 0;
				const qLower = q.toLowerCase();

				// 数据准备
				const keywords = entry.keywords || [];
				const cmdList = entry.command || [];
				const exeName = cmdList.length > 0 ? cmdList[0].split('/').pop().toLowerCase() : "";
				const name = (entry.name || "").toLowerCase();
				const gName = (entry.genericName || "").toLowerCase();
				const words = name.split(/\s+/); // 拆分单词
				//单词首字母匹配 (例如: "Visual Studio Code" -> vsc)
				const initials = words.map(w => w[0]).join("");
				if (initials.includes(qLower)) score += 50;
				//单词前缀匹配 (更符合直觉)
				if (words.some(w => w.startsWith(qLower))) score += 40;
				// 完全匹配最高
				if (name === qLower) score += 100;
				else if (name.startsWith(qLower)) score += 70;
				else if (name.includes(qLower)) score += 5;

				// --- Command (执行文件名: 80+) ---
				if (exeName === qLower) score += 80;
				else if (exeName.startsWith(qLower)) score += 40;
				else if (exeName.includes(qLower)) score += 10;


				// --- 优先级 4: GenericName (通用描述: 20+) ---
				if (gName.includes(qLower)) score += 20;

				// 附加：Comment 作为保底搜索
				if (score === 0 && (entry.comment || "").toLowerCase().includes(qLower)) {
					score += 1;
				}

				return { data: entry, score: score };
			}).filter(item => item.score > 0);

			// 排序逻辑
			scoredResults.sort((a, b) => {
				// 1. 按分数从高到低
				if (b.score !== a.score) return b.score - a.score;
				// 2. 分数相同时，按名字长度（越短越精准）
				if (a.data.name.length !== b.data.name.length) {
					return a.data.name.length - b.data.name.length;
				}
				// 3. 最后按字母序
				return a.data.name.localeCompare(b.data.name);
			});

			return scoredResults.map(item => item.data);
		}
	}
	function launch(index) {
		const entry = filteredApps.values[index];
		if (entry) {
			if (entry.runInTerminal) {
				const terminal = "xdg-terminal-exec";
				const fullCommand = [terminal, "-e"].concat(entry.command);
				Quickshell.execDetached({
					command: fullCommand,
					workingDirectory: entry.workingDirectory,
					// 如果需要继承当前环境变量，通常不需要设置 environment
				});
				} else {
			entry.execute();
			active = false;
				}
		}
	}
}
