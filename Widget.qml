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
    popoutWidth: 420
    popoutHeight: 580

    property string baseUrl: {
        var url = pluginData.apiBaseUrl || "http://10.190.217.209:61208/api/widget";
        return url.replace(/\/+$/, "");
    }
    property int intervalSecs: Math.max(1, pluginData.refreshInterval || 2)

    property bool isOffline: false
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
    property var physicalNet: ({ "name": "eth0", "ip": "N/A", "rx_rate": "0 B/s", "tx_rate": "0 B/s", "state": "UP" })
    property var virtualNets: []
    property int virtualNetCount: 0

    Timer {
        interval: root.intervalSecs * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchFastMetrics()
    }

    Timer {
        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchSlowMetrics()
    }

    function fetchAllData() {
        fetchFastMetrics();
        fetchSlowMetrics();
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
            detailsText: `${root.sysInfo.cpu_name || "CPU"} • ${root.sysInfo.os_name || "Linux"} • Up: ${root.sysInfo.uptime || "N/A"}`
            showCloseButton: true

            Flickable {
                width: parent.width
                implicitHeight: mainLayout.implicitHeight
                height: Math.min(mainLayout.implicitHeight, 480)
                contentHeight: mainLayout.implicitHeight
                clip: true

                ColumnLayout {
                    id: mainLayout
                    width: parent.width
                    spacing: Theme.spacingM

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: root.isOffline ? "Status: OFFLINE" : "Status: ONLINE"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: root.isOffline ? Theme.error : Theme.primary
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

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 110
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            RowLayout {
                                Layout.fillWidth: true
                                StyledText { text: "CPU Usage"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                                Item { Layout.fillWidth: true }
                                StyledText {
                                    text: `${root.sysResources.cpu.usage_percent.toFixed(1)}% (${root.sysResources.cpu.temp_c || 0}°C)`
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primary
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
                                    color: Theme.primary
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                StyledText { text: "RAM Usage"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                                Item { Layout.fillWidth: true }
                                StyledText {
                                    text: `${root.sysResources.memory.usage_percent.toFixed(1)}%`
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: "#a6e3a1"
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
                                    color: "#a6e3a1"
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                StyledText { text: "Disk Root (/)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                                Item { Layout.fillWidth: true }
                                StyledText {
                                    text: `${root.sysResources.disk_root.usage_percent.toFixed(1)}%`
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: "#89b4fa"
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
                                    color: "#89b4fa"
                                }
                            }
                        }
                    }

                    StyledText {
                        text: `Podman Containers (${root.containerStats.running} Running / ${root.containerStats.problems} Errors)`
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    ListView {
                        Layout.fillWidth: true
                        implicitHeight: Math.min(220, Math.max(60, root.containerList.length * 62))
                        clip: true
                        model: root.containerList
                        spacing: Theme.spacingS

                        delegate: StyledRect {
                            width: ListView.view.width
                            height: 56
                            radius: Theme.cornerRadius
                            color: modelData.status === "running" ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: modelData.status === "running" ? "play_circle" : "error"
                                    color: modelData.status === "running" ? "#a6e3a1" : Theme.error
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Layout.fillWidth: true

                                    StyledText {
                                        text: modelData.name || modelData.id || "Container"
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
                                    iconName: "content_copy"
                                    onClicked: root.copyContainerId(modelData.id)
                                }

                                DankButton {
                                    iconName: "restart_alt"
                                    onClicked: root.restartContainer(modelData.id)
                                }

                                DankButton {
                                    iconName: "stop"
                                    onClicked: root.stopContainer(modelData.id)
                                }
                            }
                        }
                    }

                    StyledText {
                        text: "Btrfs Subvolumes"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    ListView {
                        Layout.fillWidth: true
                        implicitHeight: Math.min(140, Math.max(40, root.subvolumesList.length * 44))
                        clip: true
                        model: root.subvolumesList
                        spacing: Theme.spacingXS

                        delegate: StyledRect {
                            width: ListView.view.width
                            height: 38
                            radius: Theme.cornerRadiusSmall
                            color: Theme.surfaceContainerHigh

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS

                                ColumnLayout {
                                    spacing: 1
                                    Layout.fillWidth: true

                                    StyledText {
                                        text: modelData.name || "Subvolume"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        text: modelData.mount || "/"
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        color: Theme.surfaceVariantText
                                        elide: Text.ElideRight
                                    }
                                }

                                StyledText {
                                    text: `${(modelData.percent || 0).toFixed(1)}%`
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                }
                            }
                        }
                    }

                    StyledText {
                        text: `Network (${root.physicalNet.name || "eth0"}: ${root.physicalNet.ip || "N/A"})`
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS

                            DankIcon {
                                name: "lan"
                                color: Theme.primary
                            }

                            StyledText {
                                text: `RX: ${root.physicalNet.rx_rate || "0 B/s"}  |  TX: ${root.physicalNet.tx_rate || "0 B/s"}`
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: `${root.virtualNetCount} Virtual Nets`
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }
                    }
                }
            }
        }
    }
}
