import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "vmonitor-srv"
    popoutWidth: 460
    popoutHeight: 640

    property bool enableGraphs: pluginData.enableGraphs !== false
    property int intervalSecs: Math.max(1, pluginData.refreshInterval || 2)

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
    property var selectedNetData: ({ "name": "eno1", "rx_rate": "0 B/s", "tx_rate": "0 B/s", "ip": "192.168.100.200", "state": "UP" })

    property string expandedContainerId: ""
    property real expandedContainerCpu: 0
    property var expandedContainerHistory: [0, 0, 0, 0, 0]

    property string selectedSubvolName: ""
    property var selectedSubvolData: root.subvolumesList.length > 0 ? root.subvolumesList[0] : ({ "name": "root", "mount": "/", "percent": 0, "used_bytes": 0 })
    property string virtualNetQuery: ""

    Timer {
        interval: root.intervalSecs * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchFastMetrics()
    }

    Timer {
        interval: 15000
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
        interval: 1500
        running: root.expandedContainerId !== "" && !root.isOffline
        repeat: true
        onTriggered: root.fetchContainerCpu(root.expandedContainerId)
    }

    Timer {
        id: netDetailTimer
        interval: 1500
        running: root.selectedNetId !== "" && !root.isOffline
        repeat: true
        onTriggered: root.fetchSelectedNetDetail(root.selectedNetId)
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

    function parseRateToKb(rateStr) {
        if (!rateStr || typeof rateStr !== "string") return 0;
        var parts = rateStr.trim().split(" ");
        var num = parseFloat(parts[0]) || 0;
        var unit = (parts[1] || "B/s").toUpperCase();
        if (unit.startsWith("M")) return num * 1024;
        if (unit.startsWith("G")) return num * 1024 * 1024;
        if (unit.startsWith("K")) return num;
        return num / 1024;
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
                var rxKb = parseRateToKb(data.rx_rate || data.rx_bytes || "0 B/s");
                var txKb = parseRateToKb(data.tx_rate || data.tx_bytes || "0 B/s");
                root.netRxHistory = pushHistory(root.netRxHistory, rxKb, 20);
                root.netTxHistory = pushHistory(root.netTxHistory, txKb, 20);
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

    function getMetricColor(value) {
        if (value < 60) return Theme.primary;
        if (value < 85) return "#f59e0b";
        return Theme.error;
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
                name: "server"
                size: root.iconSize
                color: root.isOffline ? Theme.error : (root.containerStats.problems > 0 || root.sysResources.alerts_count > 0 ? "#f59e0b" : Theme.primary)
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.isOffline ? "OFFLINE" : `${Math.round(root.sysResources.cpu.usage_percent)}% | ${Math.round(root.sysResources.memory.usage_percent)}%`
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
                name: "server"
                size: root.iconSize
                color: root.isOffline ? Theme.error : (root.containerStats.problems > 0 || root.sysResources.alerts_count > 0 ? "#f59e0b" : Theme.primary)
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.isOffline ? "OFF" : `${Math.round(root.sysResources.cpu.usage_percent)}%`
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: "VMonitorSRV"
            detailsText: root.isOffline ? "Status: OFFLINE" : `IP: ${root.currentServerObj.host} • Up: ${root.sysInfo.uptime || "N/A"}`
            showCloseButton: true

            ColumnLayout {
                width: parent.width
                spacing: Theme.spacingM

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    DankButton {
                        text: `${root.currentServerObj.name || root.currentServerObj.host} ▼`
                        backgroundColor: root.showServerDropdown ? Theme.primary : Theme.surfaceContainerHighest
                        textColor: root.showServerDropdown ? Theme.onPrimary : Theme.surfaceText
                        onClicked: {
                            root.showServerDropdown = !root.showServerDropdown;
                            if (root.showServerDropdown) root.showAlertsDrawer = false;
                        }
                    }

                    Item { Layout.fillWidth: true }

                    DankButton {
                        iconName: "warning"
                        text: `Alerts: ${root.crossServerAlerts.length}`
                        backgroundColor: root.showAlertsDrawer ? "#f59e0b" : Theme.surfaceContainerHighest
                        textColor: root.showAlertsDrawer ? Theme.surfaceContainer : Theme.surfaceText
                        onClicked: {
                            root.showAlertsDrawer = !root.showAlertsDrawer;
                            if (root.showAlertsDrawer) root.showServerDropdown = false;
                        }
                    }

                    DankButton {
                        iconName: "refresh"
                        backgroundColor: Theme.surfaceContainerHighest
                        textColor: Theme.surfaceText
                        onClicked: root.fetchAllData()
                    }

                    DankButton {
                        iconName: "settings"
                        backgroundColor: Theme.surfaceContainerHighest
                        textColor: Theme.surfaceText
                        onClicked: {
                            if (typeof PopoutService !== "undefined" && PopoutService) {
                                PopoutService.showPluginSettings("vMonitorSRV");
                            }
                        }
                    }
                }

                StyledRect {
                    visible: root.showServerDropdown
                    Layout.fillWidth: true
                    implicitHeight: 120
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHighest

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Select Monitored Server"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.primary
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: root.serversList
                            spacing: Theme.spacingXS
                            delegate: StyledRect {
                                width: ListView.view.width
                                height: 34
                                radius: Theme.cornerRadiusSmall
                                color: index === root.activeServerIndex ? Theme.primary : Theme.surfaceContainerHigh

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingS
                                    StyledText {
                                        text: `${modelData.name || modelData.host} (${modelData.host}:${modelData.port || "61208"})`
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: index === root.activeServerIndex ? Font.Bold : Font.Normal
                                        color: index === root.activeServerIndex ? Theme.onPrimary : Theme.surfaceText
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.activeServerIndex = index;
                                        root.showServerDropdown = false;
                                        root.cpuHistory = [0, 0, 0, 0, 0];
                                        root.ramHistory = [0, 0, 0, 0, 0];
                                        root.netRxHistory = [0, 0, 0, 0, 0];
                                        root.netTxHistory = [0, 0, 0, 0, 0];
                                        root.fetchAllData();
                                    }
                                }
                            }
                        }
                    }
                }

                StyledRect {
                    visible: root.showAlertsDrawer
                    Layout.fillWidth: true
                    implicitHeight: 120
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHighest

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Active Alerts across Connected Servers"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.primary
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: root.crossServerAlerts.length > 0 ? root.crossServerAlerts : [{ "serverName": "System", "log": "No active alerts across servers" }]
                            spacing: Theme.spacingXS
                            delegate: RowLayout {
                                width: ListView.view.width
                                spacing: Theme.spacingS
                                StyledText {
                                    text: `[${modelData.serverName || "Server"}]`
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: "#f59e0b"
                                }
                                StyledText {
                                    text: modelData.log || "Normal"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    implicitHeight: 480
                    height: 480
                    contentHeight: mainContent.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: mainContent
                        width: parent.width
                        spacing: Theme.spacingL

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Information"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: 160
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingS

                                    RowLayout {
                                        Layout.fillWidth: true
                                        StyledText {
                                            text: root.sysInfo.hostname || root.currentServerObj.name || "server"
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Bold
                                            color: Theme.primary
                                        }
                                        Item { Layout.fillWidth: true }
                                        StyledText {
                                            text: root.isOffline ? "OFFLINE" : "ONLINE"
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Bold
                                            color: root.isOffline ? Theme.error : Theme.primary
                                        }
                                    }

                                    GridLayout {
                                        columns: 2
                                        rowSpacing: 4
                                        columnSpacing: Theme.spacingM
                                        Layout.fillWidth: true

                                        StyledText { text: "CPU Model:"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceVariantText }
                                        StyledText { text: root.sysInfo.cpu_name || "Intel(R) Core(TM) i5-8500 CPU @ 3.00GHz"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; elide: Text.ElideRight; Layout.fillWidth: true }

                                        StyledText { text: "Hardware Model:"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceVariantText }
                                        StyledText { text: root.sysInfo.hardware_model || "10SJS0FJ00"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; elide: Text.ElideRight; Layout.fillWidth: true }

                                        StyledText { text: "OS Name:"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceVariantText }
                                        StyledText { text: root.sysInfo.os_name || "Fedora Linux 44 64bit"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; elide: Text.ElideRight; Layout.fillWidth: true }

                                        StyledText { text: "Uptime:"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceVariantText }
                                        StyledText { text: root.sysInfo.uptime || "17 days, 17:36:20"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; elide: Text.ElideRight; Layout.fillWidth: true }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.surfaceContainerHighest
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Resources"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: root.enableGraphs ? 190 : 135
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingS

                                    RowLayout {
                                        Layout.fillWidth: true
                                        StyledText { text: "CPU Usage"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; font.weight: Font.Bold }
                                        Item { Layout.fillWidth: true }
                                        StyledText {
                                            text: `${root.sysResources.cpu.usage_percent.toFixed(1)}% (${root.sysResources.cpu.temp_c || 0}°C)`
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: root.getMetricColor(root.sysResources.cpu.usage_percent)
                                            font.weight: Font.Bold
                                        }
                                    }

                                    StyledRect {
                                        Layout.fillWidth: true
                                        height: 6
                                        radius: 3
                                        color: Theme.surfaceContainerHighest
                                        StyledRect {
                                            width: parent.width * Math.min(1.0, root.sysResources.cpu.usage_percent / 100.0)
                                            height: parent.height
                                            radius: parent.radius
                                            color: root.getMetricColor(root.sysResources.cpu.usage_percent)
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        StyledText { text: "RAM Usage"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; font.weight: Font.Bold }
                                        Item { Layout.fillWidth: true }
                                        StyledText {
                                            text: `${root.sysResources.memory.usage_percent.toFixed(1)}%`
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: root.getMetricColor(root.sysResources.memory.usage_percent)
                                            font.weight: Font.Bold
                                        }
                                    }

                                    StyledRect {
                                        Layout.fillWidth: true
                                        height: 6
                                        radius: 3
                                        color: Theme.surfaceContainerHighest
                                        StyledRect {
                                            width: parent.width * Math.min(1.0, root.sysResources.memory.usage_percent / 100.0)
                                            height: parent.height
                                            radius: parent.radius
                                            color: root.getMetricColor(root.sysResources.memory.usage_percent)
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        StyledText { text: "Disk Root (/)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; font.weight: Font.Bold }
                                        Item { Layout.fillWidth: true }
                                        StyledText {
                                            text: `${root.sysResources.disk_root.usage_percent.toFixed(1)}%`
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: root.getMetricColor(root.sysResources.disk_root.usage_percent)
                                            font.weight: Font.Bold
                                        }
                                    }

                                    StyledRect {
                                        Layout.fillWidth: true
                                        height: 6
                                        radius: 3
                                        color: Theme.surfaceContainerHighest
                                        StyledRect {
                                            width: parent.width * Math.min(1.0, root.sysResources.disk_root.usage_percent / 100.0)
                                            height: parent.height
                                            radius: parent.radius
                                            color: root.getMetricColor(root.sysResources.disk_root.usage_percent)
                                        }
                                    }

                                    Canvas {
                                        visible: root.enableGraphs
                                        Layout.fillWidth: true
                                        implicitHeight: 35
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);

                                            ctx.beginPath();
                                            ctx.lineWidth = 1;
                                            ctx.strokeStyle = Theme.surfaceContainerHighest;
                                            ctx.moveTo(0, height - 2);
                                            ctx.lineTo(width, height - 2);
                                            ctx.stroke();

                                            if (!root.cpuHistory || root.cpuHistory.length < 2) return;

                                            ctx.beginPath();
                                            ctx.lineWidth = 2;
                                            ctx.strokeStyle = root.getMetricColor(root.sysResources.cpu.usage_percent);

                                            var step = width / (root.cpuHistory.length - 1);
                                            for (var i = 0; i < root.cpuHistory.length; i++) {
                                                var val = root.cpuHistory[i] || 0;
                                                var y = height - (val / 100.0 * (height - 4)) - 2;
                                                var x = i * step;
                                                if (i === 0) ctx.moveTo(x, y);
                                                else ctx.lineTo(x, y);
                                            }
                                            ctx.stroke();
                                        }

                                        Connections {
                                            target: root
                                            function onCpuHistoryChanged() {
                                                if (root.enableGraphs) parent.requestPaint();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.surfaceContainerHighest
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Storage"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: 70
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    DankIcon { name: "pie_chart"; color: Theme.primary }

                                    ColumnLayout {
                                        spacing: 2
                                        Layout.fillWidth: true
                                        StyledText { text: "Root Disk Storage Pool"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: Theme.surfaceText }
                                        StyledText {
                                            text: `Used: ${root.sysResources.disk_root.usage_percent.toFixed(1)}% (${root.bytesToGb(root.sysResources.disk_root.used_bytes)} / ${root.bytesToGb(root.sysResources.disk_root.total_bytes)})`
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            StyledText {
                                text: `Btrfs Subvolumes Wheel (${root.subvolumesList.length})`
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            ListView {
                                id: subvolCarousel
                                Layout.fillWidth: true
                                implicitHeight: 75
                                orientation: ListView.Horizontal
                                clip: true
                                model: root.subvolumesList
                                spacing: Theme.spacingS

                                delegate: StyledRect {
                                    width: 145
                                    height: 68
                                    radius: Theme.cornerRadius
                                    color: isSelected ? Theme.primary : Theme.surfaceContainerHigh

                                    property string subName: modelData.name || "subvol"
                                    property bool isSelected: root.selectedSubvolName === subName || (root.selectedSubvolName === "" && index === 0)

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingS
                                        spacing: 2

                                        RowLayout {
                                            Layout.fillWidth: true
                                            DankIcon {
                                                name: "folder"
                                                color: isSelected ? Theme.onPrimary : Theme.primary
                                            }
                                            StyledText {
                                                text: subName
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Bold
                                                color: isSelected ? Theme.onPrimary : Theme.surfaceText
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        StyledText {
                                            text: `${(modelData.percent || 0).toFixed(1)}% (${root.bytesToGb(modelData.used_bytes)})`
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: isSelected ? Theme.onPrimary : Theme.surfaceVariantText
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            root.selectedSubvolName = subName;
                                            root.selectedSubvolData = modelData;
                                        }
                                    }
                                }
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: 95
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingXS

                                    RowLayout {
                                        Layout.fillWidth: true
                                        DankIcon { name: "info"; color: Theme.primary }
                                        StyledText {
                                            text: `Selected Subvolume: ${root.selectedSubvolData.name || root.selectedSubvolName || "root"}`
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Bold
                                            color: Theme.surfaceText
                                        }
                                        Item { Layout.fillWidth: true }
                                        StyledText {
                                            text: `${(root.selectedSubvolData.percent || 0).toFixed(1)}%`
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Bold
                                            color: root.getMetricColor(root.selectedSubvolData.percent || 0)
                                        }
                                    }

                                    StyledText {
                                        text: `Mount Point: ${root.selectedSubvolData.mount || "/"}`
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        text: `Used Capacity: ${root.bytesToGb(root.selectedSubvolData.used_bytes)}`
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.primary
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.surfaceContainerHighest
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Network"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: root.enableGraphs ? 115 : 60
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingS
                                    spacing: Theme.spacingXS

                                    RowLayout {
                                        Layout.fillWidth: true

                                        DankIcon { name: "lan"; color: Theme.primary }

                                        ColumnLayout {
                                            spacing: 1
                                            StyledText {
                                                text: `Interface: ${root.selectedNetId} (IP: ${root.selectedNetData.ip || "192.168.100.200"})`
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Bold
                                                color: Theme.surfaceText
                                            }
                                            StyledText {
                                                text: `RX Rate: ${root.selectedNetData.rx_rate || root.selectedNetData.rx_bytes || "0 B/s"}  |  TX Rate: ${root.selectedNetData.tx_rate || root.selectedNetData.tx_bytes || "0 B/s"}`
                                                font.pixelSize: Theme.fontSizeSmall - 1
                                                color: Theme.surfaceVariantText
                                            }
                                        }
                                    }

                                    Canvas {
                                        visible: root.enableGraphs
                                        Layout.fillWidth: true
                                        implicitHeight: 45
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.clearRect(0, 0, width, height);

                                            ctx.beginPath();
                                            ctx.lineWidth = 1;
                                            ctx.strokeStyle = Theme.surfaceContainerHighest;
                                            ctx.moveTo(0, height - 2);
                                            ctx.lineTo(width, height - 2);
                                            ctx.stroke();

                                            if (!root.netRxHistory || root.netRxHistory.length < 2) return;

                                            var maxRx = 1;
                                            for (var i = 0; i < root.netRxHistory.length; i++) {
                                                if (root.netRxHistory[i] > maxRx) maxRx = root.netRxHistory[i];
                                            }

                                            ctx.beginPath();
                                            ctx.lineWidth = 2;
                                            ctx.strokeStyle = Theme.primary;

                                            var step = width / (root.netRxHistory.length - 1);
                                            for (var j = 0; j < root.netRxHistory.length; j++) {
                                                var val = root.netRxHistory[j] || 0;
                                                var y = height - (val / maxRx * (height - 4)) - 2;
                                                var x = j * step;
                                                if (j === 0) ctx.moveTo(x, y);
                                                else ctx.lineTo(x, y);
                                            }
                                            ctx.stroke();
                                        }

                                        Connections {
                                            target: root
                                            function onNetRxHistoryChanged() {
                                                if (root.enableGraphs) parent.requestPaint();
                                            }
                                        }
                                    }
                                }
                            }

                            StyledText {
                                text: `Select Interface to Graph (${root.getAllInterfacesList().length})`
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            DankTextField {
                                Layout.fillWidth: true
                                placeholderText: "Filter physical & virtual interfaces..."
                                text: root.virtualNetQuery
                                onTextChanged: root.virtualNetQuery = text
                            }

                            ListView {
                                Layout.fillWidth: true
                                implicitHeight: Math.min(150, Math.max(45, root.getAllInterfacesList().length * 42))
                                clip: true
                                model: root.getAllInterfacesList()
                                spacing: Theme.spacingXS

                                delegate: StyledRect {
                                    width: ListView.view.width
                                    height: 38
                                    radius: Theme.cornerRadiusSmall
                                    color: isSelected ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                                    property string itemIfName: modelData.name || `if${index}`
                                    property bool isVirt: modelData.isVirtual
                                    property bool isSelected: root.selectedNetId === itemIfName

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingS

                                        DankIcon {
                                            name: isSelected ? "check_circle" : (isVirt ? "hub" : "lan")
                                            color: isSelected ? Theme.primary : Theme.surfaceVariantText
                                        }

                                        StyledText {
                                            text: `${itemIfName} ${isVirt ? "(Virtual)" : "(Physical)"}`
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: isSelected ? Font.Bold : Font.Normal
                                            color: isSelected ? Theme.primary : Theme.surfaceText
                                            Layout.fillWidth: true
                                        }

                                        DankButton {
                                            text: isSelected ? "Active" : "Select"
                                            backgroundColor: isSelected ? Theme.primary : Theme.surfaceContainerHighest
                                            textColor: isSelected ? Theme.onPrimary : Theme.surfaceText
                                            onClicked: {
                                                root.selectedNetId = itemIfName;
                                                root.netRxHistory = [0, 0, 0, 0, 0];
                                                root.netTxHistory = [0, 0, 0, 0, 0];
                                                root.fetchSelectedNetDetail(itemIfName);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.surfaceContainerHighest
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Containers"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: `Podman Containers (${root.containerList.length})`
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            ListView {
                                Layout.fillWidth: true
                                implicitHeight: Math.min(260, Math.max(60, root.containerList.length * (isExpanded ? 120 : 62)))
                                clip: true
                                model: root.containerList
                                spacing: Theme.spacingS

                                delegate: StyledRect {
                                    width: ListView.view.width
                                    height: isExpanded ? 115 : 58
                                    radius: Theme.cornerRadius
                                    color: modelData.status === "running" ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                                    property string cId: modelData.id || ""
                                    property bool isExpanded: root.expandedContainerId === cId

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingS
                                        spacing: Theme.spacingXS

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Theme.spacingS

                                            DankIcon {
                                                name: modelData.status === "running" ? "play_circle" : "error"
                                                color: modelData.status === "running" ? Theme.primary : Theme.error
                                            }

                                            ColumnLayout {
                                                spacing: 1
                                                Layout.fillWidth: true

                                                StyledText {
                                                    text: modelData.name || cId || "Container"
                                                    font.pixelSize: Theme.fontSizeMedium
                                                    color: Theme.surfaceText
                                                    font.weight: Font.Bold
                                                    elide: Text.ElideRight
                                                }

                                                StyledText {
                                                    text: `${modelData.image || "image"} • ${modelData.memory_usage || "N/A"}`
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    color: Theme.surfaceVariantText
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            DankButton {
                                                iconName: isExpanded ? "expand_less" : "expand_more"
                                                backgroundColor: Theme.surfaceContainerHighest
                                                textColor: Theme.surfaceText
                                                onClicked: {
                                                    if (isExpanded) {
                                                        root.expandedContainerId = "";
                                                    } else {
                                                        root.expandedContainerId = cId;
                                                        root.expandedContainerCpu = 0;
                                                        root.expandedContainerHistory = [0, 0, 0, 0, 0];
                                                        root.fetchContainerCpu(cId);
                                                    }
                                                }
                                            }

                                            DankButton {
                                                iconName: "content_copy"
                                                backgroundColor: Theme.surfaceContainerHighest
                                                textColor: Theme.surfaceText
                                                onClicked: root.copyContainerId(cId)
                                            }

                                            DankButton {
                                                iconName: "restart_alt"
                                                backgroundColor: Theme.surfaceContainerHighest
                                                textColor: Theme.surfaceText
                                                onClicked: root.restartContainer(cId)
                                            }

                                            DankButton {
                                                iconName: "stop"
                                                backgroundColor: Theme.surfaceContainerHighest
                                                textColor: Theme.surfaceText
                                                onClicked: root.stopContainer(cId)
                                            }
                                        }

                                        ColumnLayout {
                                            visible: isExpanded
                                            Layout.fillWidth: true
                                            spacing: 2

                                            RowLayout {
                                                Layout.fillWidth: true
                                                StyledText {
                                                    text: "Live CPU Usage:"
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    color: Theme.surfaceText
                                                }

                                                StyledRect {
                                                    Layout.fillWidth: true
                                                    height: 6
                                                    radius: 3
                                                    color: Theme.surfaceContainerHighest

                                                    StyledRect {
                                                        width: parent.width * Math.min(1.0, root.expandedContainerCpu / 100.0)
                                                        height: parent.height
                                                        radius: parent.radius
                                                        color: root.getMetricColor(root.expandedContainerCpu)
                                                    }
                                                }

                                                StyledText {
                                                    text: `${root.expandedContainerCpu.toFixed(1)}%`
                                                    font.pixelSize: Theme.fontSizeSmall
                                                    font.weight: Font.Bold
                                                    color: root.getMetricColor(root.expandedContainerCpu)
                                                }
                                            }

                                            Canvas {
                                                visible: root.enableGraphs
                                                Layout.fillWidth: true
                                                implicitHeight: 25
                                                onPaint: {
                                                    var ctx = getContext("2d");
                                                    ctx.clearRect(0, 0, width, height);

                                                    ctx.beginPath();
                                                    ctx.lineWidth = 1;
                                                    ctx.strokeStyle = Theme.surfaceContainerHighest;
                                                    ctx.moveTo(0, height - 2);
                                                    ctx.lineTo(width, height - 2);
                                                    ctx.stroke();

                                                    if (!root.expandedContainerHistory || root.expandedContainerHistory.length < 2) return;

                                                    ctx.beginPath();
                                                    ctx.lineWidth = 2;
                                                    ctx.strokeStyle = root.getMetricColor(root.expandedContainerCpu);

                                                    var step = width / (root.expandedContainerHistory.length - 1);
                                                    for (var i = 0; i < root.expandedContainerHistory.length; i++) {
                                                        var val = root.expandedContainerHistory[i] || 0;
                                                        var y = height - (val / 100.0 * (height - 4)) - 2;
                                                        var x = i * step;
                                                        if (i === 0) ctx.moveTo(x, y);
                                                        else ctx.lineTo(x, y);
                                                    }
                                                    ctx.stroke();
                                                }

                                                Connections {
                                                    target: root
                                                    function onExpandedContainerHistoryChanged() {
                                                        if (root.enableGraphs) parent.requestPaint();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
