import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./components"

PluginComponent {
    id: root

    layerNamespacePlugin: "vmonitor-srv"
    popoutWidth: 480
    popoutHeight: 640

    property bool enableGraphs: pluginData.enableGraphs !== false
    property string barDisplayMode: pluginData.barDisplayMode || "alerts"
    property int fastIntervalSecs: Math.max(1, pluginData.fastRefreshInterval || pluginData.refreshInterval || 2)
    property int slowIntervalSecs: Math.max(5, pluginData.slowRefreshInterval || 20)
    property int detailIntervalSecs: Math.max(1, pluginData.detailRefreshInterval || 2)

    property string hostsFilePath: {
        var home = Quickshell.env("HOME") || "/home/vsynlo";
        return home + "/.config/DankMaterialShell/plugins/vMonitorSRV/hosts.json";
    }

    property var serversList: {
        try {
            var parsed = JSON.parse(pluginData.serversConfig || "[]");
            if (Array.isArray(parsed) && parsed.length > 0) return parsed;
        } catch (e) {}
        return [
            { "name": "Fedora Primary", "host": "192.168.100.200", "port": "61208" }
        ];
    }
    property int activeServerIndex: 0
    property var currentServerObj: serversList[Math.min(activeServerIndex, serversList.length - 1)] || serversList[0]
    property string baseUrl: {
        var s = currentServerObj;
        var host = s.host || "192.168.100.200";
        var port = s.port || "61208";
        return `http://${host}:${port}/api/widget`;
    }

    property bool isOffline: false
    property bool showAlertsDrawer: false
    property bool showServerDropdown: false

    property var sysInfo: ({})
    property var sysResources: ({
        "cpu": { "usage_percent": 0, "temp_c": 0 },
        "memory": { "usage_percent": 0, "used_bytes": 0, "total_bytes": 0 },
        "disk_root": { "usage_percent": 0, "used_bytes": 0, "free_bytes": 0 },
        "alerts_count": 0
    })
    property var containerStats: ({ "total": 0, "running": 0, "stopped": 0, "problems": 0 })
    property var containerList: []
    property var subvolumesList: []
    property var physicalNets: []
    property var virtualNets: []
    property int virtualNetCount: 0

    property var crossServerAlerts: []

    property var cpuHistory: [0, 0, 0, 0, 0]
    property var ramHistory: [0, 0, 0, 0, 0]
    property var netRxHistory: [0, 0, 0, 0, 0]
    property var netTxHistory: [0, 0, 0, 0, 0]

    property string selectedNetId: "eno1"
    property var selectedNetData: ({ "name": "eno1", "status": "up", "ipv4": ["192.168.100.200"], "traffic": { "rx_bytes_sec": 0, "tx_bytes_sec": 0 } })

    property string expandedContainerId: ""
    property real expandedContainerCpu: 0
    property var expandedContainerHistory: [0, 0, 0, 0, 0]

    property string selectedSubvolName: ""
    property var selectedSubvolData: root.subvolumesList.length > 0 ? root.subvolumesList[0] : ({ "name": "root", "mount": "/", "percent": 0, "used_bytes": 0 })
    property string virtualNetQuery: ""

    Timer {
        id: fastMetricsTimer
        interval: root.fastIntervalSecs * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchFastMetrics()
    }

    Timer {
        id: slowMetricsTimer
        interval: root.slowIntervalSecs * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.fetchSlowMetrics();
            root.checkCrossServerAlerts();
        }
    }

    Timer {
        id: containerCpuTimer
        interval: root.detailIntervalSecs * 1000
        running: root.expandedContainerId !== "" && !root.isOffline
        repeat: true
        onTriggered: root.fetchContainerCpu(root.expandedContainerId)
    }

    Timer {
        id: netDetailTimer
        interval: root.detailIntervalSecs * 1000
        running: root.selectedNetId !== "" && !root.isOffline
        repeat: true
        onTriggered: root.fetchSelectedNetDetail(root.selectedNetId)
    }

    function getBarPillText() {
        if (root.isOffline) return "OFFLINE";
        if (root.barDisplayMode === "status") return "ONLINE";
        if (root.barDisplayMode === "hostname") return root.currentServerObj.name || root.currentServerObj.host;
        if (root.barDisplayMode === "cpu_ram") return `${Math.round(root.sysResources.cpu.usage_percent)}% | ${Math.round(root.sysResources.memory.usage_percent)}%`;
        var totalAlerts = root.crossServerAlerts.length;
        if (totalAlerts > 0) return `${totalAlerts} Alert(s)`;
        return "Normal";
    }

    function openHostsFileInEditor() {
        Quickshell.execDetached(["xdg-open", root.hostsFilePath]);
    }

    function fetchAllData() {
        fetchFastMetrics();
        fetchSlowMetrics();
        checkCrossServerAlerts();
        if (root.expandedContainerId !== "") fetchContainerCpu(root.expandedContainerId);
        if (root.selectedNetId !== "") fetchSelectedNetDetail(root.selectedNetId);
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
        if (!data) return "0 B/s";
        if (data.traffic && data.traffic.rx_bytes_sec !== undefined) return formatBytesRate(data.traffic.rx_bytes_sec);
        if (data.rx_rate) return data.rx_rate;
        if (data.rx_bytes) return formatBytesRate(data.rx_bytes);
        return "0 B/s";
    }

    function getTxRateString(data) {
        if (!data) return "0 B/s";
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
        if (value < 75) return "#f59e0b";
        return Theme.error;
    }

    function getStorageColor(value) {
        if (value >= 75) return Theme.error;
        if (value >= 50) return "#f59e0b";
        return Theme.primary;
    }

    function getOsIconName(osName) {
        if (!osName || typeof osName !== "string") return "dns";
        var lower = osName.toLowerCase();
        if (lower.includes("fedora")) return "fedora";
        if (lower.includes("ubuntu")) return "ubuntu";
        if (lower.includes("debian")) return "debian";
        if (lower.includes("arch")) return "archlinux";
        if (lower.includes("alpine")) return "alpine";
        if (lower.includes("centos") || lower.includes("rhel") || lower.includes("red hat")) return "redhat";
        return "dns";
    }

    function fetchFastMetrics() {
        httpGet(root.baseUrl + "/resources", function(data) {
            if (data) {
                root.sysResources = data;
                if (data.cpu && data.cpu.usage_percent !== undefined) {
                    root.cpuHistory = pushHistory(root.cpuHistory, data.cpu.usage_percent, 20);
                }
                if (data.memory && data.memory.usage_percent !== undefined) {
                    root.ramHistory = pushHistory(root.ramHistory, data.memory.usage_percent, 20);
                }
            }
        });
        httpGet(root.baseUrl + "/containers/count", function(data) {
            if (data) root.containerStats = data;
        });
    }

    function fetchSlowMetrics() {
        httpGet(root.baseUrl + "/information", function(data) {
            if (data) root.sysInfo = data;
        });
        httpGet(root.baseUrl + "/containers", function(data) {
            if (data && data.containers) root.containerList = data.containers;
        });
        httpGet(root.baseUrl + "/storage/subvolumes", function(data) {
            if (data && data.subvolumes) {
                root.subvolumesList = data.subvolumes;
                if (data.subvolumes.length > 0 && !root.selectedSubvolName) {
                    root.selectedSubvolName = data.subvolumes[0].name || "";
                    root.selectedSubvolData = data.subvolumes[0];
                }
            }
        });
        httpGet(root.baseUrl + "/network", function(data) {
            if (data) {
                if (Array.isArray(data)) root.physicalNets = data;
                else if (data.interfaces) root.physicalNets = data.interfaces;
                else root.physicalNets = [data];

                if (root.physicalNets.length > 0) {
                    var p0 = root.physicalNets[0];
                    var pName = typeof p0 === "string" ? p0 : (p0.name || p0.id || "eno1");
                    if (!root.selectedNetId || root.selectedNetId === "eno1") {
                        root.selectedNetId = pName;
                        root.fetchSelectedNetDetail(pName);
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
            var name = typeof item === "string" ? item : (item.name || item.id || "");
            if (name === netId) return true;
        }
        return false;
    }

    function fetchSelectedNetDetail(netId) {
        if (!netId) return;
        var isVirt = isVirtualInterface(netId);
        var endpoint = isVirt ? (root.baseUrl + "/network/virtual/" + netId) : (root.baseUrl + "/network/" + netId);
        httpGet(endpoint, function(data) {
            if (data) {
                root.selectedNetData = data;
                var rxKb = getRxKbsec(data);
                root.netRxHistory = pushHistory(root.netRxHistory, rxKb, 20);
            }
        });
    }

    function fetchContainerCpu(id) {
        if (!id) return;
        httpGet(root.baseUrl + "/containers/cpu/" + id, function(data) {
            if (data && data.usage_percent !== undefined) {
                root.expandedContainerCpu = data.usage_percent;
                root.expandedContainerHistory = pushHistory(root.expandedContainerHistory, data.usage_percent, 15);
            }
        });
    }

    function checkCrossServerAlerts() {
        var alertsAcc = [];
        for (var i = 0; i < root.serversList.length; i++) {
            (function(srvIndex) {
                var srv = root.serversList[srvIndex];
                var url = `http://${srv.host}:${srv.port}/api/widget/resources`;
                var xhr = new XMLHttpRequest();
                xhr.open("GET", url, true);
                xhr.timeout = 2000;
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                        try {
                            var res = JSON.parse(xhr.responseText);
                            if (res.alerts_count > 0) {
                                alertsAcc.push({
                                    "serverName": srv.name || srv.host,
                                    "host": srv.host,
                                    "count": res.alerts_count,
                                    "log": `[WARN] ${res.alerts_count} active alert(s) on ${srv.name}`
                                });
                                root.crossServerAlerts = alertsAcc;
                            }
                        } catch (e) {}
                    }
                };
                xhr.send();
            })(i);
        }
    }

    function httpGet(url, callback) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        xhr.timeout = 2500;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    root.isOffline = false;
                    try {
                        callback(JSON.parse(xhr.responseText));
                    } catch (e) {
                        callback(null);
                    }
                } else {
                    root.isOffline = true;
                    callback(null);
                }
            }
        };
        xhr.send();
    }

    function httpPost(url, payload, callback) {
        var xhr = new XMLHttpRequest();
        xhr.open("POST", url, true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.timeout = 3000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    try {
                        callback(JSON.parse(xhr.responseText));
                    } catch (e) {
                        callback(true);
                    }
                } else {
                    callback(false);
                }
            }
        };
        xhr.send(JSON.stringify(payload || {}));
    }

    function restartContainer(id) {
        httpPost(root.baseUrl + "/containers/" + id + "/restart", {}, function(success) {
            root.fetchAllData();
        });
    }

    function stopContainer(id) {
        httpPost(root.baseUrl + "/containers/" + id + "/stop", {}, function(success) {
            root.fetchAllData();
        });
    }

    function copyContainerId(id) {
        Quickshell.execDetached(["dms", "cl", "copy", id]);
    }

    function bytesToGb(bytes) {
        if (!bytes || isNaN(bytes)) return "0.0 GB";
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB";
    }

    function getAllInterfacesList() {
        var list = [];
        for (var i = 0; i < root.physicalNets.length; i++) {
            var p = root.physicalNets[i];
            var pName = typeof p === "string" ? p : (p.name || p.id || "eno1");
            list.push({ "name": pName, "isVirtual": false });
        }
        for (var j = 0; j < root.virtualNets.length; j++) {
            var v = root.virtualNets[j];
            var vName = typeof v === "string" ? v : (v.name || v.id || `vnet${j}`);
            list.push({ "name": vName, "isVirtual": true });
        }
        if (root.virtualNetQuery) {
            var q = root.virtualNetQuery.toLowerCase();
            return list.filter(function(item) { return item.name.toLowerCase().includes(q); });
        }
        return list;
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                name: "dns"
                size: root.iconSize
                color: root.isOffline ? Theme.error : "#22c55e"
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.getBarPillText()
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            anchors.centerIn: parent

            DankIcon {
                name: "dns"
                size: root.iconSize
                color: root.isOffline ? Theme.error : "#22c55e"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.isOffline ? "OFF" : (root.barDisplayMode === "alerts" ? `${root.crossServerAlerts.length}` : `${Math.round(root.sysResources.cpu.usage_percent)}%`)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout
            showCloseButton: true

            ColumnLayout {
                width: parent.width
                spacing: Theme.spacingM

                HeaderCard {
                    currentServerObj: root.currentServerObj
                    isOffline: root.isOffline
                    sysInfo: root.sysInfo
                    showServerDropdown: root.showServerDropdown
                    showAlertsDrawer: root.showAlertsDrawer
                    crossServerAlertsCount: root.crossServerAlerts.length
                    onToggleServerDropdown: {
                        root.showServerDropdown = !root.showServerDropdown;
                        if (root.showServerDropdown) root.showAlertsDrawer = false;
                    }
                    onToggleAlertsDrawer: {
                        root.showAlertsDrawer = !root.showAlertsDrawer;
                        if (root.showAlertsDrawer) root.showServerDropdown = false;
                    }
                    onRefreshClicked: root.fetchAllData()
                    onSettingsClicked: {
                        if (typeof PopoutService !== "undefined" && PopoutService) {
                            PopoutService.showPluginSettings("vMonitorSRV");
                        }
                    }
                }

                ServerSelectorDrawer {
                    visible: root.showServerDropdown
                    serversList: root.serversList
                    activeServerIndex: root.activeServerIndex
                    onServerSelected: (index) => {
                        root.activeServerIndex = index;
                        root.showServerDropdown = false;
                        root.cpuHistory = [0, 0, 0, 0, 0];
                        root.ramHistory = [0, 0, 0, 0, 0];
                        root.netRxHistory = [0, 0, 0, 0, 0];
                        root.netTxHistory = [0, 0, 0, 0, 0];
                        root.fetchAllData();
                    }
                    onOpenHostsFile: root.openHostsFileInEditor()
                }

                AlertsDrawer {
                    visible: root.showAlertsDrawer
                    crossServerAlerts: root.crossServerAlerts
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.spacingM
                    Layout.rightMargin: Theme.spacingM
                    implicitHeight: 480
                    height: 480
                    contentHeight: mainContent.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: mainContent
                        width: parent.width
                        spacing: Theme.spacingM

                        InformationCard {
                            sysInfo: root.sysInfo
                            currentServerObj: root.currentServerObj
                            isOffline: root.isOffline
                            getOsIconNameFunc: root.getOsIconName
                        }

                        ResourcesCard {
                            sysResources: root.sysResources
                            enableGraphs: root.enableGraphs
                            cpuHistory: root.cpuHistory
                            getMetricColorFunc: root.getMetricColor
                            getStorageColorFunc: root.getStorageColor
                        }

                        StorageCard {
                            sysResources: root.sysResources
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
                                root.netRxHistory = [0, 0, 0, 0, 0];
                                root.netTxHistory = [0, 0, 0, 0, 0];
                                root.fetchSelectedNetDetail(ifName);
                            }
                            onUpdateVirtualNetQuery: (query) => {
                                root.virtualNetQuery = query;
                            }
                        }

                        ContainersCard {
                            containerList: root.containerList
                            expandedContainerId: root.expandedContainerId
                            expandedContainerCpu: root.expandedContainerCpu
                            expandedContainerHistory: root.expandedContainerHistory
                            enableGraphs: root.enableGraphs
                            getMetricColorFunc: root.getMetricColor
                            onToggleExpandContainer: (cId) => {
                                if (root.expandedContainerId === cId) {
                                    root.expandedContainerId = "";
                                } else {
                                    root.expandedContainerId = cId;
                                    root.expandedContainerCpu = 0;
                                    root.expandedContainerHistory = [0, 0, 0, 0, 0];
                                    root.fetchContainerCpu(cId);
                                }
                            }
                            onCopyContainerId: (cId) => root.copyContainerId(cId)
                            onRestartContainer: (cId) => root.restartContainer(cId)
                            onStopContainer: (cId) => root.stopContainer(cId)
                        }
                    }
                }
            }
        }
    }
}
