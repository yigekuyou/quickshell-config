pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import QtCore

Singleton {
    id: service

    property string searchText: ""

    // 搜索模型
    property alias model: filteredApps
    readonly property var allEntries: {
        DesktopEntries.applicationsChanged; // 建立绑定
        return [...DesktopEntries.applications.values];
    }
    readonly property var allCategories: {
        const entries = allEntries;
        let cats = new Set();
        entries.forEach(entry => {
            if (entry.categories) {
                entry.categories.forEach(c => cats.add(c));
            }
        });
        // 返回排序后的类别列表，并在开头加上 "All"
        return ["All", ...Array.from(cats).sort()];
    }
    property alias categories: categorizedApps

    ScriptModel {
        id: categorizedApps
        objectProp: "name" // 这里的 name 指的是类别名称 (如 "Development", "Office")
        values: {
            const entries = allEntries;
            const cats = allCategories; // 获取已有的 ["All", "Category1", ...]

            return cats.map(cat => {
                // 为每个类别过滤应用
                const appsInCategory = entries.filter(entry => {
                    if (cat === "All")
                        return true;

                    return entry.categories && entry.categories.includes(cat);
                }).sort((a, b) => a.name.localeCompare(b.name));

                // 返回一个包含类别名和该线下所有应用的数组的对象
                return {
                    name: cat,
                    apps: appsInCategory
                };
            });
        }
    }
    ScriptModel {
        id: filteredApps
        objectProp: "id"
        values: {
            const all = allEntries;
            const q = service.searchText.trim().toLowerCase();
            const bestGuess = DesktopEntries.heuristicLookup(q);
            const bestGuessId = bestGuess ? bestGuess.id : null;
            if (q === "")
                return all.sort((a, b) => a.name.localeCompare(b.name));

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
                if (bestGuessId && entry.id === bestGuessId) {
                    score += 120;
                }
                //单词首字母匹配 (例如: "Visual Studio Code" -> vsc)
                const initials = words.map(w => w[0]).join("");
                if (initials.includes(qLower))
                    score += 50;
                //单词前缀匹配 (更符合直觉)
                if (words.some(w => w.startsWith(qLower)))
                    score += 40;
                // 完全匹配最高
                if (name === qLower)
                    score += 100;
                else if (name.startsWith(qLower))
                    score += 70;
                else if (name.includes(qLower))
                    score += 5;

                // --- Command (执行文件名: 80+) ---
                if (exeName === qLower)
                    score += 80;
                else if (exeName.startsWith(qLower))
                    score += 40;
                else if (exeName.includes(qLower))
                    score += 10;

                // --- 优先级 4: GenericName (通用描述: 20+) ---
                if (gName.includes(qLower))
                    score += 20;

                // 附加：Comment 作为保底搜索
                if (score === 0) {
                    const fuzzyPattern = qLower.split("").join(".*");
                    if (new RegExp(fuzzyPattern).test(name)) {
                        score += 5; // 给个低分保底，保证它能显示出来
                    }
                }
                if (score === 0 && (entry.comment || "").toLowerCase().includes(qLower)) {
                    score += 1;
                }

                return {
                    data: entry,
                    score: score
                };
            }).filter(item => item.score > 0);

            // 排序逻辑
            scoredResults.sort((a, b) => {
                // 1. 按分数从高到低
                if (b.score !== a.score)
                    return b.score - a.score;
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
    function exportAllEntriesInfo() {
        const entries = [...DesktopEntries.applications.values];
        const exportData = entries.map(entry => ({
                    id: entry.id,
                    name: entry.name,
                    genericName: entry.genericName,
                    comment: entry.comment,
                    command: entry.command,
                    execString: entry.execString,
                    categories: entry.categories,
                    keywords: entry.keywords,
                    runInTerminal: entry.runInTerminal,
                    workingDirectory: entry.workingDirectory
                }));

        const jsonString = JSON.stringify(exportData, null, 4);

        // 1. 在控制台打印出来
        console.log(jsonString);

        return jsonString;
    }
    // 直接按 DesktopEntry 启动：分页/分类视图里的下标跟搜索结果的下标并不一致，
    // 用下标启动会打开错的应用，所以统一走 entry。
    function launchEntry(entry) {
        if (!entry)
            return;

        const desktopFileName = entry.id + ".desktop";
        const desktopFilePath = StandardPaths.locate(StandardPaths.ApplicationsLocation, desktopFileName);

        // 有 .desktop 就走 kioclient：它会处理 Terminal=true、环境变量和启动通知
        if (desktopFilePath !== "") {
            Quickshell.execDetached({
                command: ["kioclient", "exec", desktopFilePath],
                workingDirectory: entry.workingDirectory
            });
            return;
        }

        // 没有 .desktop 的应用（例如 steam 游戏）直接跑它的命令行
        if (entry.command && entry.command.length > 0) {
            Quickshell.execDetached({
                command: entry.command,
                workingDirectory: entry.workingDirectory
            });
        } else {
            console.warn("[launcher] 无法启动 " + entry.id + "：没有可用的启动方式");
        }
    }

    // 兼容旧的下标式调用
    function launch(index) {
        launchEntry(filteredApps.values[index]);
    }
}
