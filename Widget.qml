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
    popoutWidth: 440
    popoutHeight: 580

    property string baseUrl: {
        var url = pluginData.apiBaseUrl || "http://10.190.217.209:61208/api/widget";
        return url.replace(/\/+$/, "");
    }
    property int intervalSecs: Math.max(1, pluginData.refreshInterval || 2)

    property bool isOffline: false
    property int currentTab: 0

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
    property var physicalNet: ({ "name": "eno1", "ip": "N/A", "rx_rate": "0 B/s", "tx_rate": "0 B/s", "state": "UP" })
    property var virtualNets: []
    property int virtualNetCount: 0

    property string expandedContainerId: ""
    property real expandedContainerCpu: 0
    property string expandedNetId: ""
    property var expandedNetData: ({ "rx_rate": "0 B/s", "tx_rate": "0 B/s" })
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
        onTriggered: root.fetchSlowMetrics()
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
        running: root.expandedNetId !== "" && !root.isOffline
        repeat: true
        onTriggered: root.fetchNetDetail(root.expandedNetId)
    }

    function fetchAllData() {
        fetchFastMetrics();
        fetchSlowMetrics();
        if (root.expandedContainerId !== "") fetchContainerCpu(root.expandedContainerId);
        if (root.expandedNetId !== "") fetchNetDetail(root.expandedNetId);
    }

    function fetchFastMetrics() {
        httpGet(root.baseUrl + "/resources", function(data) {
            if (data) root.sysResources = data;
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
            if (data && data.subvolumes) root.subvolumesList = data.subvolumes;
        });
        httpGet(root.baseUrl + "/network", function(data) {
            if (data) {
                if (Array.isArray(data) && data.length > 0) root.physicalNet = data[0];
                else if (data.interfaces && data.interfaces.length > 0) root.physicalNet = data.interfaces[0];
                else if (data.name) root.physicalNet = data;
            }
        });
        httpGet(root.baseUrl + "/network/virtual", function(data) {
            if (data) {
                if (data.interfaces) root.virtualNets = data.interfaces;
                if (data.count !== undefined) root.virtualNetCount = data.count;
                else root.virtualNetCount = root.virtualNets.length;
            }
        });
    }

    function fetchContainerCpu(id) {
        if (!id) return;
        httpGet(root.baseUrl + "/containers/cpu/" + id, function(data) {
            if (data && data.usage_percent !== undefined) {
                root.expandedContainerCpu = data.usage_percent;
            }
        });
    }

    function fetchNetDetail(id) {
        if (!id) return;
        httpGet(root.baseUrl + "/network/" + id, function(data) {
            if (data) root.expandedNetData = data;
        });
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
        if (value < 60) return "#a6e3a1";
        if (value < 85) return "#f59e0b";
        return Theme.error || "#f38ba8";
    }

    function bytesToGb(bytes) {
        if (!bytes || isNaN(bytes)) return "0 GB";
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB";
    }

    function getFilteredVirtualNets() {
        if (!root.virtualNetQuery) return root.virtualNets;
        var q = root.virtualNetQuery.toLowerCase();
        return root.virtualNets.filter(function(item) {
            var name = typeof item === "string" ? item : (item.name || "");
            return name.toLowerCase().includes(q);
        });
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
            headerText: root.sysInfo.hostname || "VMonitorSRV"
            detailsText: root.isOffline ? "Status: OFFLINE" : `IP: ${root.physicalNet.ip || "192.168.100.200"} • Up: ${root.sysInfo.uptime || "N/A"}`
            showCloseButton: true

            ColumnLayout {
                width: parent.width
                spacing: Theme.spacingS

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXS

                    DankButton {
                        Layout.fillWidth: true
                        iconName: "dashboard"
                        text: "Dashboard"
                        backgroundColor: root.currentTab === 0 ? Theme.primary : Theme.surfaceContainer
                        textColor: root.currentTab === 0 ? Theme.onPrimary : Theme.surfaceText
                        onClicked: root.currentTab = 0
                    }

                    DankButton {
                        Layout.fillWidth: true
                        iconName: "storage"
                        text: "Storage"
                        backgroundColor: root.currentTab === 1 ? Theme.primary : Theme.surfaceContainer
                        textColor: root.currentTab === 1 ? Theme.onPrimary : Theme.surfaceText
                        onClicked: root.currentTab = 1
                    }

                    DankButton {
                        Layout.fillWidth: true
                        iconName: "dns"
                        text: "Net & Podman"
                        backgroundColor: root.currentTab === 2 ? Theme.primary : Theme.surfaceContainer
                        textColor: root.currentTab === 2 ? Theme.onPrimary : Theme.surfaceText
                        onClicked: root.currentTab = 2
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: root.isOffline ? "Server Offline" : "Server Active"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: root.isOffline ? Theme.error : "#a6e3a1"
                    }

                    Item { Layout.fillWidth: true }

                    DankButton {
                        iconName: "refresh"
                        text: "Refresh"
                        onClicked: root.fetchAllData()
                    }

                    DankButton {
                        iconName: "settings"
                        onClicked: {
                            if (typeof PopoutService !== "undefined" && PopoutService) {
                                PopoutService.showPluginSettings("vMonitorSRV");
                            }
                        }
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    implicitHeight: 430
                    height: 430
                    contentHeight: tabContent.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: tabContent
                        width: parent.width
                        spacing: Theme.spacingM

                        ColumnLayout {
                            visible: root.currentTab === 0
                            Layout.fillWidth: true
                            spacing: Theme.spacingM

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: 70
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: 2

                                    StyledText {
                                        text: root.sysInfo.hostname || "Fedora Server"
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: `${root.sysInfo.cpu_name || "CPU"} • ${root.sysInfo.os_name || "Fedora Linux"} (${root.sysInfo.kernel_version || "Kernel"})`
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: 140
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
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingM

                                StyledRect {
                                    Layout.fillWidth: true
                                    implicitHeight: 70
                                    radius: Theme.cornerRadius
                                    color: Theme.surfaceContainerHigh

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        DankIcon { name: "view_module"; color: Theme.primary; anchors.horizontalCenter: parent.horizontalCenter }
                                        StyledText {
                                            text: `${root.containerStats.running} / ${root.containerStats.total} Containers`
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Bold
                                            color: Theme.surfaceText
                                        }
                                    }
                                }

                                StyledRect {
                                    Layout.fillWidth: true
                                    implicitHeight: 70
                                    radius: Theme.cornerRadius
                                    color: Theme.surfaceContainerHigh

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        DankIcon {
                                            name: "warning"
                                            color: root.sysResources.alerts_count > 0 || root.containerStats.problems > 0 ? "#f59e0b" : "#a6e3a1"
                                            anchors.horizontalCenter: parent.horizontalCenter
                                        }
                                        StyledText {
                                            text: `Alerts: ${root.sysResources.alerts_count + root.containerStats.problems}`
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Bold
                                            color: Theme.surfaceText
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.currentTab === 1
                            Layout.fillWidth: true
                            spacing: Theme.spacingM

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: 65
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    DankIcon { name: "pie_chart"; color: Theme.primary }

                                    ColumnLayout {
                                        spacing: 2
                                        StyledText { text: "Root Disk Storage Pool"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: Theme.surfaceText }
                                        StyledText {
                                            text: `Used: ${root.sysResources.disk_root.usage_percent.toFixed(1)}%`
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }
                            }

                            StyledText {
                                text: `Btrfs Subvolumes (${root.subvolumesList.length})`
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            ListView {
                                Layout.fillWidth: true
                                implicitHeight: Math.min(260, Math.max(60, root.subvolumesList.length * 52))
                                clip: true
                                model: root.subvolumesList
                                spacing: Theme.spacingS

                                delegate: StyledRect {
                                    width: ListView.view.width
                                    height: 48
                                    radius: Theme.cornerRadiusSmall
                                    color: Theme.surfaceContainerHigh

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingS

                                        DankIcon { name: "folder"; color: Theme.primary }

                                        ColumnLayout {
                                            spacing: 1
                                            Layout.fillWidth: true

                                            StyledText {
                                                text: modelData.name || "subvol"
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Bold
                                                color: Theme.surfaceText
                                                elide: Text.ElideRight
                                            }

                                            StyledText {
                                                text: `${modelData.mount || "/"} • ${root.bytesToGb(modelData.used_bytes)}`
                                                font.pixelSize: Theme.fontSizeSmall - 1
                                                color: Theme.surfaceVariantText
                                                elide: Text.ElideRight
                                            }
                                        }

                                        StyledText {
                                            text: `${(modelData.percent || 0).toFixed(1)}%`
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Bold
                                            color: root.getMetricColor(modelData.percent || 0)
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            visible: root.currentTab === 2
                            Layout.fillWidth: true
                            spacing: Theme.spacingM

                            StyledText {
                                text: `Physical Network (${root.physicalNet.name || "eno1"})`
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingS

                                    DankIcon { name: "lan"; color: Theme.primary }

                                    ColumnLayout {
                                        spacing: 1
                                        StyledText {
                                            text: `IP: ${root.physicalNet.ip || "192.168.100.200"}`
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Bold
                                            color: Theme.surfaceText
                                        }
                                        StyledText {
                                            text: `RX: ${root.physicalNet.rx_rate || "0 B/s"}  |  TX: ${root.physicalNet.tx_rate || "0 B/s"}`
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }
                            }

                            StyledText {
                                text: `Virtual Interfaces (${root.virtualNetCount})`
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            DankTextField {
                                Layout.fillWidth: true
                                placeholderText: "Filter virtual interfaces..."
                                text: root.virtualNetQuery
                                onTextChanged: root.virtualNetQuery = text
                            }

                            ListView {
                                Layout.fillWidth: true
                                implicitHeight: Math.min(130, Math.max(45, root.getFilteredVirtualNets().length * 42))
                                clip: true
                                model: root.getFilteredVirtualNets()
                                spacing: Theme.spacingXS

                                delegate: StyledRect {
                                    width: ListView.view.width
                                    height: isExpanded ? 70 : 38
                                    radius: Theme.cornerRadiusSmall
                                    color: isExpanded ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                                    property string itemIfName: typeof modelData === "string" ? modelData : (modelData.name || `vnet${index}`)
                                    property bool isExpanded: root.expandedNetId === itemIfName

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingS

                                        RowLayout {
                                            Layout.fillWidth: true

                                            DankIcon { name: "hub"; color: Theme.primary }

                                            StyledText {
                                                text: itemIfName
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Bold
                                                color: Theme.surfaceText
                                                Layout.fillWidth: true
                                            }

                                            DankButton {
                                                iconName: isExpanded ? "expand_less" : "expand_more"
                                                onClicked: {
                                                    if (isExpanded) root.expandedNetId = "";
                                                    else {
                                                        root.expandedNetId = itemIfName;
                                                        root.fetchNetDetail(itemIfName);
                                                    }
                                                }
                                            }
                                        }

                                        RowLayout {
                                            visible: isExpanded
                                            Layout.fillWidth: true

                                            StyledText {
                                                text: `Live Traffic -> RX: ${root.expandedNetData.rx_rate || "0 B/s"} | TX: ${root.expandedNetData.tx_rate || "0 B/s"}`
                                                font.pixelSize: Theme.fontSizeSmall - 1
                                                color: Theme.primary
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }
                                }
                            }

                            StyledText {
                                text: `Podman Containers (${root.containerList.length})`
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            ListView {
                                Layout.fillWidth: true
                                implicitHeight: Math.min(240, Math.max(60, root.containerList.length * (isExpanded ? 105 : 62)))
                                clip: true
                                model: root.containerList
                                spacing: Theme.spacingS

                                delegate: StyledRect {
                                    width: ListView.view.width
                                    height: isExpanded ? 100 : 58
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
                                                color: modelData.status === "running" ? "#a6e3a1" : Theme.error
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
                                                onClicked: {
                                                    if (isExpanded) {
                                                        root.expandedContainerId = "";
                                                    } else {
                                                        root.expandedContainerId = cId;
                                                        root.expandedContainerCpu = 0;
                                                        root.fetchContainerCpu(cId);
                                                    }
                                                }
                                            }

                                            DankButton {
                                                iconName: "content_copy"
                                                onClicked: root.copyContainerId(cId)
                                            }

                                            DankButton {
                                                iconName: "restart_alt"
                                                onClicked: root.restartContainer(cId)
                                            }

                                            DankButton {
                                                iconName: "stop"
                                                onClicked: root.stopContainer(cId)
                                            }
                                        }

                                        RowLayout {
                                            visible: isExpanded
                                            Layout.fillWidth: true
                                            spacing: Theme.spacingS

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
