import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import "./components"

PluginComponent {
    id: root

    function parseAliases(value) {
        try {
            var parsed = JSON.parse(String(value || "{}"));
            return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
        } catch (e) { return {}; }
    }

    function parseServers(value, aliases, discovered) {
        var servers = [];
        var entries = String(value || "").split(",");
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i].trim().replace(/\/+$/, "");
            if (!entry) continue;
            var match = /^(https?):\/\/([a-zA-Z0-9.-]+|\[[0-9a-fA-F:]+\])(?::([0-9]{1,5}))?$/.exec(entry);
            if (!match) continue;
            var port = match[3] ? Number(match[3]) : 61208;
            if (port < 1 || port > 65535) continue;
            var origin = match[1] + "://" + match[2] + ":" + port;
            servers.push({ name: aliases[origin] || discovered[origin] || match[2], host: match[2], port: String(port), origin: origin,
                           baseUrl: origin + "/api/widget" });
        }
        return servers;
    }


    layerNamespacePlugin: "vmonitor-srv"
    popoutWidth: 520
    popoutHeight: 650

    property bool enableGraphs: pluginData.enableGraphs !== false
    property string barDisplayMode: pluginData.barDisplayMode || "alerts"
    property bool barShowIcon: pluginData.barShowIcon !== false
    property bool barCompact: pluginData.barCompact === true
    property string barAccent: pluginData.barAccent || "primary"
    readonly property color pillAccentColor: barAccent === "secondary" ? Theme.secondary : barAccent === "neutral" ? Theme.surfaceVariantText : Theme.primary
    property string panelDefaultPage: pluginData.panelDefaultPage || "overview"
    property bool showSystemInfo: pluginData.showSystemInfo !== false
    property bool showCpuTemperature: pluginData.showCpuTemperature !== false
    property int fastIntervalSecs: Math.max(1, pluginData.fastRefreshInterval || pluginData.refreshInterval || 2)
    property int slowIntervalSecs: Math.max(5, pluginData.slowRefreshInterval || 20)
    property int detailIntervalSecs: Math.max(1, pluginData.detailRefreshInterval || 2)

    property string serverUrls: pluginData.serverUrls || ""
    property var serverAliases: parseAliases(pluginData.serverAliases || "{}")
    property var discoveredNames: ({})
    property var serversList: parseServers(serverUrls, serverAliases, discoveredNames)
    onServerAliasesChanged: {
        if (!Array.isArray(crossServerAlerts)) return;
        crossServerAlerts = crossServerAlerts.map(function(item) {
            return Object.assign({}, item, { serverName: serverAliases[item.origin] || discoveredNames[item.origin] || item.host });
        });
    }
    property int activeServerIndex: 0
    property var currentServerObj: serversList.length > 0 ? serversList[Math.min(activeServerIndex, serversList.length - 1)] : ({ name: "No server configured", host: "", port: "" })
    property string baseUrl: currentServerObj.baseUrl || ""
    readonly property bool popoutActive: interactionActive

    onPopoutActiveChanged: {
        if (popoutActive) {
            currentPage = panelDefaultPage;
            fetchAllData();
        }
    }

    onServerUrlsChanged: {
        currentReqSeq++;
        activeServerIndex = 0;
        resetServerData();
        discoveredNames = ({});
        if (serverUrls) {
            Qt.callLater(function() { root.discoverServerNames(); });
            checkCrossServerAlerts();
            if (popoutActive) fetchAllData();
        }
    }

    function rememberServerName(origin, hostname) {
        var name = String(hostname || "").trim();
        if (!name || name === "Unknown" || discoveredNames[origin] === name) return;
        var next = Object.assign({}, discoveredNames);
        next[origin] = name;
        discoveredNames = next;
        crossServerAlerts = crossServerAlerts.map(function(item) {
            if (item.origin !== origin) return item;
            return Object.assign({}, item, { serverName: serverAliases[origin] || name });
        });
    }

    function discoverServerNames() {
        var generation = currentReqSeq;
        for (var i = 0; i < serversList.length; i++) {
            (function(server) {
                var xhr = new XMLHttpRequest();
                xhr.open("GET", server.baseUrl + "/information", true);
                xhr.timeout = 3000;
                xhr.onreadystatechange = function() {
                    if (xhr.readyState !== XMLHttpRequest.DONE || generation !== root.currentReqSeq || xhr.status < 200 || xhr.status >= 300) return;
                    try { root.rememberServerName(server.origin, JSON.parse(xhr.responseText).hostname); } catch (e) {}
                };
                xhr.send();
            })(serversList[i]);
        }
    }

    function resetServerData() {
        sysInfo = {};
        sysResources = { cpu: {}, memory: {}, disk_root: {}, alerts_count: 0 };
        containerStats = { total: 0, running: 0, stopped: 0, problems: 0 };
        containerList = [];
        subvolumesList = [];
        mainDisks = [];
        alertDetails = [];
        physicalNets = [];
        virtualNets = [];
        selectedNetId = "";
        selectedNetData = {};
        expandedContainerId = "";
        crossServerAlerts = [];
        isOffline = false;
        lastSuccessfulPingTime = 0;
        offlineConsecutiveFailures = 0;
    }

    property int currentReqSeq: 0
    property int offlineConsecutiveFailures: 0
    property double lastSuccessfulPingTime: 0

    property bool isOffline: false
    property bool showServerDropdown: false
    property string currentPage: "overview"
    onCurrentPageChanged: {
        if (!popoutActive) return;
        if (currentPage === "network" && selectedNetId) fetchSelectedNetDetail(selectedNetId);
        if (currentPage === "containers" && expandedContainerId) fetchContainerCpu(expandedContainerId);
        if (currentPage === "alerts") fetchAlertDetails();
    }

    property var sysInfo: ({})
    property var sysResources: ({ cpu: {}, memory: {}, disk_root: {}, alerts_count: 0 })
    property var containerStats: ({ "total": 0, "running": 0, "stopped": 0, "problems": 0 })
    property var containerList: []
    property var subvolumesList: []
    property var mainDisks: []
    property var alertDetails: []
    property var physicalNets: []
    property var virtualNets: []
    property int virtualNetCount: 0

    property var crossServerAlerts: []

    property var cpuHistory: [0, 0, 0, 0, 0]
    property var ramHistory: [0, 0, 0, 0, 0]
    property var netRxHistory: [0, 0, 0, 0, 0]
    property var netTxHistory: [0, 0, 0, 0, 0]

    property string selectedNetId: ""
    property var selectedNetData: ({})

    property string expandedContainerId: ""
    property real expandedContainerCpu: 0
    property var expandedContainerHistory: [0, 0, 0, 0, 0]

    property string selectedSubvolName: ""
    property var selectedSubvolData: ({})
    property string virtualNetQuery: ""

    Timer {
        id: fastMetricsTimer
        interval: root.fastIntervalSecs * 1000
        running: root.baseUrl !== "" && (root.popoutActive || ["cpu_ram", "cpu", "memory", "disk"].indexOf(root.barDisplayMode) !== -1)
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchFastMetrics()
    }

    Timer {
        id: slowMetricsTimer
        interval: root.slowIntervalSecs * 1000
        running: root.serversList.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.popoutActive) root.fetchSlowMetrics();
            root.checkCrossServerAlerts();
        }
    }

    Timer {
        id: containerCpuTimer
        interval: root.detailIntervalSecs * 1000
        running: root.popoutActive && root.currentPage === "containers" && root.expandedContainerId !== "" && !root.isOffline
        repeat: true
        onTriggered: root.fetchContainerCpu(root.expandedContainerId)
    }

    Timer {
        id: netDetailTimer
        interval: root.detailIntervalSecs * 1000
        running: root.popoutActive && root.currentPage === "network" && root.selectedNetId !== "" && !root.isOffline
        repeat: true
        onTriggered: root.fetchSelectedNetDetail(root.selectedNetId)
    }

    function getBarPillText() {
        if (!root.baseUrl) return "Configure server";
        if (root.isOffline) return "Unavailable";
        if (root.barDisplayMode === "status") return root.lastSuccessfulPingTime ? "Connected" : "Checking";
        if (root.barDisplayMode === "hostname") return root.currentServerObj.name || root.currentServerObj.host;
        var cpu = root.sysResources.cpu.usage_percent;
        var ram = root.sysResources.memory.usage_percent;
        var disk = root.sysResources.disk_root.usage_percent;
        var cpuText = cpu === undefined ? "N/A" : Math.round(cpu) + "%";
        var ramText = ram === undefined ? "N/A" : Math.round(ram) + "%";
        var diskText = disk === undefined ? "N/A" : Math.round(disk) + "%";
        if (root.barDisplayMode === "cpu_ram") return root.barCompact ? cpuText + " · " + ramText : "CPU " + cpuText + " · RAM " + ramText;
        if (root.barDisplayMode === "cpu") return root.barCompact ? cpuText : "CPU " + cpuText;
        if (root.barDisplayMode === "memory") return root.barCompact ? ramText : "RAM " + ramText;
        if (root.barDisplayMode === "disk") return root.barCompact ? diskText : "Disk " + diskText;
        var totalAlerts = root.crossServerAlerts.reduce(function(sum, alert) { return sum + alert.count; }, 0);
        if (totalAlerts > 0) return totalAlerts + (root.barCompact ? "" : " alerts");
        return root.barCompact ? "0" : "No alerts";
    }

    function fetchAllData() {
        if (!root.baseUrl) return;
        fetchFastMetrics();
        fetchSlowMetrics();
        checkCrossServerAlerts();
        if (root.popoutActive && root.currentPage === "containers" && root.expandedContainerId !== "") fetchContainerCpu(root.expandedContainerId);
        if (root.popoutActive && root.currentPage === "network" && root.selectedNetId !== "") fetchSelectedNetDetail(root.selectedNetId);
        if (root.popoutActive && root.currentPage === "alerts") fetchAlertDetails();
    }

    function pushHistory(arr, val, maxLen) {
        var newArr = (arr || []).slice();
        newArr.push(val);
        if (newArr.length > (maxLen || 20)) newArr.shift();
        return newArr;
    }

    function formatBytesRate(bytesSec) {
        if (!bytesSec || isNaN(bytesSec)) return "0 B/s";
        if (bytesSec >= 1024 * 1024) return (bytesSec / (1024 * 1024)).toFixed(1) + " MB/s";
        if (bytesSec >= 1024) return (bytesSec / 1024).toFixed(1) + " KB/s";
        return Math.round(bytesSec) + " B/s";
    }

    function getRxRateString(data) {
        if (!data || !data.traffic) return "N/A";
        if (data.traffic && data.traffic.rx_bytes_sec !== undefined) return formatBytesRate(data.traffic.rx_bytes_sec);
        if (data.rx_rate) return data.rx_rate;
        if (data.rx_bytes) return formatBytesRate(data.rx_bytes);
        return "0 B/s";
    }

    function getTxRateString(data) {
        if (!data || !data.traffic) return "N/A";
        if (data.traffic && data.traffic.tx_bytes_sec !== undefined) return formatBytesRate(data.traffic.tx_bytes_sec);
        if (data.tx_rate) return data.tx_rate;
        if (data.tx_bytes) return formatBytesRate(data.tx_bytes);
        return "0 B/s";
    }

    function getRxKbsec(data) {
        if (!data) return 0;
        if (data.traffic && data.traffic.rx_bytes_sec !== undefined) return data.traffic.rx_bytes_sec / 1024;
        var rStr = getRxRateString(data);
        var parts = rStr.trim().split(" ");
        var num = parseFloat(parts[0]) || 0;
        var unit = (parts[1] || "B/s").toUpperCase();
        if (unit.startsWith("M")) return num * 1024;
        if (unit.startsWith("K")) return num;
        return num / 1024;
    }

    function getIpString(data) {
        if (!data) return "N/A";
        if (Array.isArray(data.ipv4) && data.ipv4.length > 0) return data.ipv4[0];
        if (data.ip) return data.ip;
        return "N/A";
    }

    function getMetricColor(value) {
        if (value < 50) return Theme.primary;
        if (value < 75) return Theme.warning;
        return Theme.error;
    }

    function getStorageColor(value) {
        if (value >= 75) return Theme.error;
        if (value >= 50) return Theme.warning;
        return Theme.primary;
    }

    function fetchFastMetrics() {
        if (!root.baseUrl) return;
        httpGet(root.baseUrl + "/resources", function(data) {
            if (data) {
                root.sysResources = { cpu: data.cpu || {}, memory: data.memory || {},
                                      disk_root: data.disk_root || {}, alerts_count: data.alerts_count || 0 };
                if (data.cpu && data.cpu.usage_percent !== undefined) {
                    root.cpuHistory = pushHistory(root.cpuHistory, data.cpu.usage_percent, 20);
                }
                if (data.memory && data.memory.usage_percent !== undefined) {
                    root.ramHistory = pushHistory(root.ramHistory, data.memory.usage_percent, 20);
                }
            }
        }, true);
    }

    function fetchSlowMetrics() {
        if (!root.baseUrl) return;
        var origin = root.currentServerObj.origin;
        httpGet(root.baseUrl + "/information", function(data) {
            if (data) {
                root.sysInfo = data;
                root.rememberServerName(origin, data.hostname);
            }
        });
        httpGet(root.baseUrl + "/containers/count", function(data) {
            if (data) root.containerStats = data;
        });
        httpGet(root.baseUrl + "/containers", function(data) {
            if (data && data.containers) root.containerList = data.containers;
        });
        httpGet(root.baseUrl + "/storage/main", function(data) {
            root.mainDisks = data && Array.isArray(data.disks) ? data.disks : [];
        });
        httpGet(root.baseUrl + "/storage/subvolumes", function(data) {
            var subs = (data && Array.isArray(data.subvolumes)) ? data.subvolumes : [];
            root.subvolumesList = subs;
            if (subs.length > 0) {
                var selected = subs.find(function(item) { return item.name === root.selectedSubvolName; }) || subs[0];
                root.selectedSubvolName = selected.name || "";
                root.selectedSubvolData = selected;
            } else {
                root.selectedSubvolName = "";
                root.selectedSubvolData = ({});
            }
        });
        httpGet(root.baseUrl + "/network", function(data) {
            if (data) {
                if (Array.isArray(data)) root.physicalNets = data;
                else if (data.interfaces) root.physicalNets = data.interfaces;
                else root.physicalNets = [data];

                if (root.physicalNets.length > 0) {
                    var p0 = root.physicalNets[0];
                    var pName = typeof p0 === "string" ? p0 : (p0.id || p0.name || "");
                    if (!root.selectedNetId) {
                        root.selectedNetId = pName;
                        if (root.popoutActive && root.currentPage === "network") root.fetchSelectedNetDetail(pName);
                    }
                }
            }
        });
        httpGet(root.baseUrl + "/network/virtual", function(data) {
            if (data) {
                if (Array.isArray(data)) root.virtualNets = data;
                else if (data.interfaces) root.virtualNets = data.interfaces;
                else root.virtualNets = [];
                if (data.count !== undefined) root.virtualNetCount = data.count;
                else root.virtualNetCount = root.virtualNets.length;
            }
        });
    }

    function isVirtualInterface(netId) {
        if (!netId || !Array.isArray(root.virtualNets)) return false;
        for (var i = 0; i < root.virtualNets.length; i++) {
            var item = root.virtualNets[i];
            var name = typeof item === "string" ? item : (item.id || item.name || "");
            if (name === netId) return true;
        }
        return false;
    }

    function fetchSelectedNetDetail(netId) {
        if (!netId) return;
        var isVirt = isVirtualInterface(netId);
        var endpoint = isVirt ? (root.baseUrl + "/network/virtual/" + encodeURIComponent(netId)) : (root.baseUrl + "/network/" + encodeURIComponent(netId));
        httpGet(endpoint, function(data) {
            if (data && netId === root.selectedNetId) {
                root.selectedNetData = data;
                var rxKb = getRxKbsec(data);
                root.netRxHistory = pushHistory(root.netRxHistory, rxKb, 20);
            }
        });
    }

    function fetchContainerCpu(id) {
        if (!id) return;
        httpGet(root.baseUrl + "/containers/cpu/" + encodeURIComponent(id), function(data) {
            if (id === root.expandedContainerId && data && data.cpu_percent !== undefined) {
                root.expandedContainerCpu = Number(data.cpu_percent) || 0;
                root.expandedContainerHistory = pushHistory(root.expandedContainerHistory, root.expandedContainerCpu, 15);
            }
        });
    }

    function fetchAlertDetails() {
        if (!root.baseUrl) return;
        httpGet(root.baseUrl + "/alerts", function(data) {
            root.alertDetails = data && Array.isArray(data.alerts) ? data.alerts : [];
        });
    }

    function checkCrossServerAlerts() {
        if (root.serversList.length === 0) {
            root.crossServerAlerts = [];
            return;
        }
        var generation = root.currentReqSeq;
        var pending = root.serversList.length;
        var alerts = [];
        for (var i = 0; i < root.serversList.length; i++) {
            (function(index, server) {
                var xhr = new XMLHttpRequest();
                xhr.open("GET", server.baseUrl + "/resources", true);
                xhr.timeout = 3000;
                xhr.onreadystatechange = function() {
                    if (xhr.readyState !== XMLHttpRequest.DONE || generation !== root.currentReqSeq) return;
                    if (index === root.activeServerIndex) {
                        root.isOffline = xhr.status < 200 || xhr.status >= 300;
                        if (!root.isOffline) {
                            root.lastSuccessfulPingTime = Date.now();
                            root.offlineConsecutiveFailures = 0;
                        }
                    }
                    if (xhr.status >= 200 && xhr.status < 300) {
                        try {
                            var data = JSON.parse(xhr.responseText);
                            if (index === root.activeServerIndex && !root.popoutActive && root.barDisplayMode === "cpu_ram")
                                root.sysResources = { cpu: data.cpu || {}, memory: data.memory || {},
                                                      disk_root: data.disk_root || {}, alerts_count: data.alerts_count || 0 };
                            if (Number(data.alerts_count) > 0) alerts.push({
                                serverName: root.serverAliases[server.origin] || root.discoveredNames[server.origin] || server.host,
                                host: server.host, origin: server.origin,
                                count: Number(data.alerts_count),
                                log: String(data.alerts_count) + " active alert(s) on " + (root.serverAliases[server.origin] || root.discoveredNames[server.origin] || server.host)
                            });
                        } catch (e) {}
                    }
                    pending--;
                    if (pending === 0) root.crossServerAlerts = alerts;
                };
                xhr.send();
            })(i, root.serversList[i]);
        }
    }

    function httpGet(url, callback, affectsStatus) {
        if (!url) return;
        var reqSeq = root.currentReqSeq;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.timeout = 3000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (reqSeq !== root.currentReqSeq) {
                    return;
                }
                if (xhr.status >= 200 && xhr.status < 300) {
                    if (affectsStatus) {
                        root.offlineConsecutiveFailures = 0;
                        root.lastSuccessfulPingTime = Date.now();
                        root.isOffline = false;
                    }
                    try {
                        callback(JSON.parse(xhr.responseText));
                    } catch (e) {
                        callback(null);
                    }
                } else {
                    if (affectsStatus) {
                        root.offlineConsecutiveFailures++;
                        var elapsedMs = root.lastSuccessfulPingTime ? Date.now() - root.lastSuccessfulPingTime : 10001;
                        if (elapsedMs > 10000 && root.offlineConsecutiveFailures >= 3) root.isOffline = true;
                    }
                    callback(null);
                }
            }
        };
        xhr.send();
    }

    function copyContainerId(id) {
        Quickshell.clipboardText = id;
    }

    function bytesToGb(bytes) {
        if (bytes === undefined || bytes === null || isNaN(bytes)) return "N/A";
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB";
    }

    function getAllInterfacesList() {
        var list = [];
        for (var i = 0; i < root.physicalNets.length; i++) {
            var p = root.physicalNets[i];
            var pName = typeof p === "string" ? p : (p.id || p.name || "");
            if (pName) list.push({ "id": pName, "name": typeof p === "string" ? p : (p.name || pName), "isVirtual": false });
        }
        for (var j = 0; j < root.virtualNets.length; j++) {
            var v = root.virtualNets[j];
            var vName = typeof v === "string" ? v : (v.id || v.name || "");
            if (vName) list.push({ "id": vName, "name": typeof v === "string" ? v : (v.name || vName), "isVirtual": true });
        }
        if (root.virtualNetQuery) {
            var q = root.virtualNetQuery.toLowerCase();
            return list.filter(function(item) { return item.name.toLowerCase().includes(q) || item.id.toLowerCase().includes(q); });
        }
        return list;
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter

            DIcon {
                visible: root.barShowIcon
                name: "dns"
                size: root.iconSize
                color: root.isOffline ? Theme.error : root.pillAccentColor
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.getBarPillText()
                font.pixelSize: Theme.fontSizeMedium
                color: root.isOffline ? Theme.error : root.barAccent === "neutral" ? Theme.surfaceText : root.pillAccentColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            anchors.centerIn: parent

            DIcon {
                visible: root.barShowIcon
                name: "dns"
                size: root.iconSize
                color: root.isOffline ? Theme.error : root.pillAccentColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: !root.baseUrl ? "—" : root.isOffline ? "!" : root.barDisplayMode === "alerts" ? String(root.crossServerAlerts.reduce(function(sum, item) { return sum + item.count; }, 0)) : root.barDisplayMode === "hostname" ? (root.currentServerObj.name || "") : root.barDisplayMode === "status" ? "✓" : root.getBarPillText()
                font.pixelSize: Theme.fontSizeSmall
                color: root.isOffline ? Theme.error : root.barAccent === "neutral" ? Theme.surfaceText : root.pillAccentColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: "VMonitorSRV"
            showCloseButton: true

            Item {
                width: parent.width
                height: root.popoutHeight - popout.headerHeight

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingS

                    HeaderCard {
                        currentServerObj: root.currentServerObj
                        isOffline: root.isOffline
                        hasResponse: root.lastSuccessfulPingTime > 0
                        sysInfo: root.sysInfo
                        showServerDropdown: root.showServerDropdown
                        onToggleServerDropdown: root.showServerDropdown = !root.showServerDropdown
                        onRefreshClicked: root.fetchAllData()
                        onSettingsClicked: {
                            if (PopoutService && typeof PopoutService.openSettingsWithTab === "function")
                                PopoutService.openSettingsWithTab("plugins");
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXS
                        Repeater {
                            model: [
                                { id: "overview", label: "Overview" },
                                { id: "storage", label: "Storage" },
                                { id: "network", label: "Network" },
                                { id: "containers", label: "Containers" },
                                { id: "alerts", label: "Alerts" }
                            ]
                            delegate: DButton {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                minimumWidth: 0
                                horizontalPadding: Theme.spacingXS
                                text: modelData.label
                                backgroundColor: root.currentPage === modelData.id ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: root.currentPage === modelData.id ? Theme.onPrimary : Theme.surfaceText
                                onClicked: {
                                    root.currentPage = modelData.id;
                                    pageScroll.contentY = 0;
                                }
                            }
                        }
                    }

                    Flickable {
                        id: pageScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: pageContents.implicitHeight

                        ColumnLayout {
                            id: pageContents
                            width: parent.width
                            spacing: Theme.spacingS

                            ServerSelectorDrawer {
                                visible: root.showServerDropdown
                                serversList: root.serversList
                                activeServerIndex: root.activeServerIndex
                                onServerSelected: (index) => {
                                    root.currentReqSeq++;
                                    root.activeServerIndex = index;
                                    root.resetServerData();
                                    root.showServerDropdown = false;
                                    root.cpuHistory = [];
                                    root.ramHistory = [];
                                    root.netRxHistory = [];
                                    root.netTxHistory = [];
                                    root.fetchAllData();
                                }
                            }

                            ResourcesCard {
                                visible: root.currentPage === "overview"
                                sysResources: root.sysResources
                                showCpuTemperature: root.showCpuTemperature
                                enableGraphs: root.enableGraphs
                                cpuHistory: root.cpuHistory
                                getMetricColorFunc: root.getMetricColor
                                getStorageColorFunc: root.getStorageColor
                            }
                            InformationCard {
                                visible: root.currentPage === "overview" && root.showSystemInfo
                                sysInfo: root.sysInfo
                                currentServerObj: root.currentServerObj
                                isOffline: root.isOffline
                                hasResponse: root.lastSuccessfulPingTime > 0
                            }
                            StorageCard {
                                visible: root.currentPage === "storage"
                                sysResources: root.sysResources
                                mainDisks: root.mainDisks
                                subvolumesList: root.subvolumesList
                                selectedSubvolName: root.selectedSubvolName
                                selectedSubvolData: root.selectedSubvolData
                                getStorageColorFunc: root.getStorageColor
                                bytesToGbFunc: root.bytesToGb
                                onSubvolSelected: (name, data) => {
                                    root.selectedSubvolName = name;
                                    root.selectedSubvolData = data;
                                }
                            }
                            NetworkCard {
                                visible: root.currentPage === "network"
                                selectedNetId: root.selectedNetId
                                selectedNetData: root.selectedNetData
                                netRxHistory: root.netRxHistory
                                enableGraphs: root.enableGraphs
                                allInterfacesList: root.getAllInterfacesList()
                                virtualNetQuery: root.virtualNetQuery
                                getIpStringFunc: root.getIpString
                                getRxRateStringFunc: root.getRxRateString
                                getTxRateStringFunc: root.getTxRateString
                                formatBytesRateFunc: root.formatBytesRate
                                onSelectInterface: (ifName) => {
                                    root.selectedNetId = ifName;
                                    root.selectedNetData = {};
                                    root.netRxHistory = [];
                                    root.netTxHistory = [];
                                    root.fetchSelectedNetDetail(ifName);
                                }
                                onUpdateVirtualNetQuery: (query) => root.virtualNetQuery = query
                            }
                            ContainersCard {
                                visible: root.currentPage === "containers"
                                containerList: root.containerList
                                containerStats: root.containerStats
                                expandedContainerId: root.expandedContainerId
                                expandedContainerCpu: root.expandedContainerCpu
                                expandedContainerHistory: root.expandedContainerHistory
                                enableGraphs: root.enableGraphs
                                getMetricColorFunc: root.getMetricColor
                                onToggleExpandContainer: (cId) => {
                                    root.expandedContainerId = root.expandedContainerId === cId ? "" : cId;
                                    root.expandedContainerCpu = 0;
                                    root.expandedContainerHistory = [];
                                    if (root.expandedContainerId) root.fetchContainerCpu(cId);
                                }
                                onCopyContainerId: (cId) => root.copyContainerId(cId)
                            }
                            AlertsDrawer {
                                visible: root.currentPage === "alerts"
                                crossServerAlerts: root.crossServerAlerts
                                alertDetails: root.alertDetails
                            }
                        }
                    }
                }
            }
        }
    }
}
