import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins

DesktopPluginComponent {
    id: root

    function parseAliases(value) {
        try {
            var parsed = JSON.parse(String(value || "{}"));
            return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
        } catch (e) { return {}; }
    }

    function parseServers(value, aliases) {
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
            servers.push({ alias: aliases[origin] || "", host: match[2], port: String(port), origin: origin,
                           baseUrl: origin + "/api/widget" });
        }
        return servers;
    }


    minWidth: 280
    minHeight: 220

    property string serverUrls: ""
    property var serverAliases: ({})
    property string discoveredHostname: ""
    property string desktopLayout: "gauge"
    property bool desktopShowTemperature: true
    property bool desktopShowDisk: true
    property bool desktopShowStatus: true
    property int fastIntervalSecs: 2
    property var serversList: parseServers(serverUrls, serverAliases)
    property var server: serversList.length > 0 ? serversList[0] : ({ alias: "", host: "No server configured", baseUrl: "" })
    property string baseUrl: server.baseUrl
    property bool isOffline: true
    property string hostname: server.alias || discoveredHostname || server.host
    property int requestSeq: 0
    property var cpuUsage: null
    property var cpuTemp: null
    property var ramUsage: null
    property var diskUsage: null
    onCpuUsageChanged: cpuDial.requestPaint()

    function refreshSettings() {
        serverUrls = getData("serverUrls", "");
        serverAliases = parseAliases(getData("serverAliases", "{}"));
        desktopLayout = getData("desktopLayout", "gauge");
        desktopShowTemperature = getData("desktopShowTemperature", true) !== false;
        desktopShowDisk = getData("desktopShowDisk", true) !== false;
        desktopShowStatus = getData("desktopShowStatus", true) !== false;
        fastIntervalSecs = Math.max(1, Number(getData("fastRefreshInterval", 2)) || 2);
    }

    function fetchName() {
        if (!baseUrl) return;
        var seq = requestSeq;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", baseUrl + "/information", true);
        xhr.timeout = 3000;
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || seq !== root.requestSeq || xhr.status < 200 || xhr.status >= 300) return;
            try {
                var value = String(JSON.parse(xhr.responseText).hostname || "").trim();
                if (value && value !== "Unknown") root.discoveredHostname = value;
            } catch (e) {}
        };
        xhr.send();
    }
    Component.onCompleted: refreshSettings()
    onPluginServiceChanged: refreshSettings()
    onPluginIdChanged: refreshSettings()

    Connections {
        target: root.pluginService
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                root.refreshSettings();
        }
    }

    Timer {
        interval: root.fastIntervalSecs * 1000
        running: root.baseUrl !== "" && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchMetrics()
    }

    function fetchMetrics() {
        if (!root.baseUrl) return;
        var seq = root.requestSeq;
        var url = root.baseUrl;
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url + "/resources", true);
        xhr.timeout = 2500;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (seq !== root.requestSeq || url !== root.baseUrl) return;
                if (xhr.status >= 200 && xhr.status < 300) {
                    try {
                        var data = JSON.parse(xhr.responseText);
                        root.isOffline = false;
                        if (data.cpu) {
                            root.cpuUsage = data.cpu.usage_percent ?? null;
                            root.cpuTemp = data.cpu.temp_c ?? null;
                        }
                        root.ramUsage = data.memory ? (data.memory.usage_percent ?? null) : null;
                        root.diskUsage = data.disk_root ? (data.disk_root.usage_percent ?? null) : null;
                    } catch (e) { root.isOffline = true; }
                } else {
                    root.isOffline = true;
                }
            }
        };
        xhr.send();
    }

    onBaseUrlChanged: {
        requestSeq++;
        isOffline = true;
        cpuUsage = null;
        ramUsage = null;
        diskUsage = null;
        cpuTemp = null;
        discoveredHostname = "";
        if (baseUrl) {
            fetchName();
            fetchMetrics();
        }
    }

    StyledRect {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.withAlpha(Theme.outlineStrong, 0.35)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            RowLayout {
                Layout.fillWidth: true
                DIcon { name: "dns"; size: 19; color: root.isOffline ? Theme.error : Theme.primary }
                StyledText { text: root.hostname; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true; elide: Text.ElideRight }
                StyledText { visible: root.desktopShowStatus; text: !root.baseUrl ? "CONFIGURE" : root.isOffline ? "UNAVAILABLE" : "CONNECTED"; font.pixelSize: Theme.fontSizeSmall - 1; font.weight: Font.Bold; color: root.isOffline ? Theme.error : Theme.primary }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.spacingM

                Item {
                    visible: root.desktopLayout === "gauge"
                    Layout.preferredWidth: 122
                    Layout.fillHeight: true
                    Canvas {
                        id: cpuDial
                        anchors.centerIn: parent
                        width: 108
                        height: 108
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.lineCap = "round";
                            ctx.lineWidth = 8;
                            ctx.beginPath(); ctx.strokeStyle = Theme.surfaceContainerHighest;
                            ctx.arc(54, 54, 40, -Math.PI * 0.75, Math.PI * 0.75); ctx.stroke();
                            ctx.beginPath(); ctx.strokeStyle = Theme.primary;
                            ctx.arc(54, 54, 40, -Math.PI * 0.75, -Math.PI * 0.75 + Math.PI * 1.5 * Math.max(0, Math.min(100, root.cpuUsage || 0)) / 100); ctx.stroke();
                        }
                    }
                    Column {
                        anchors.centerIn: cpuDial
                        StyledText { text: root.cpuUsage === null || root.isOffline ? "N/A" : Number(root.cpuUsage).toFixed(1) + "%"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold; color: Theme.surfaceText; anchors.horizontalCenter: parent.horizontalCenter }
                        StyledText { text: "CPU"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM
                    StyledText { visible: root.desktopShowTemperature; text: "Temperature  " + (root.cpuTemp === null || root.isOffline ? "N/A" : root.cpuTemp + "°C"); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }

                    ColumnLayout {
                        visible: root.desktopLayout === "bars"
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText { text: "CPU"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; Layout.fillWidth: true }
                            StyledText { text: root.cpuUsage === null || root.isOffline ? "N/A" : Number(root.cpuUsage).toFixed(1) + "%"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.primary }
                        }
                        StyledRect {
                            Layout.fillWidth: true; implicitHeight: 6; radius: 3; color: Theme.surfaceContainerHighest
                            StyledRect { width: parent.width * Math.max(0, Math.min(1, (root.cpuUsage || 0) / 100)); height: parent.height; radius: parent.radius; color: Theme.primary }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText { text: "Memory"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; Layout.fillWidth: true }
                            StyledText { text: root.ramUsage === null || root.isOffline ? "N/A" : Number(root.ramUsage).toFixed(1) + "%"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.secondary }
                        }
                        StyledRect {
                            Layout.fillWidth: true; implicitHeight: 6; radius: 3; color: Theme.surfaceContainerHighest
                            StyledRect { width: parent.width * Math.max(0, Math.min(1, (root.ramUsage || 0) / 100)); height: parent.height; radius: parent.radius; color: Theme.secondary }
                        }
                    }
                    ColumnLayout {
                        visible: root.desktopShowDisk
                        Layout.fillWidth: true
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText { text: "Root disk"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; Layout.fillWidth: true }
                            StyledText { text: root.diskUsage === null || root.isOffline ? "N/A" : Number(root.diskUsage).toFixed(1) + "%"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.primary }
                        }
                        StyledRect {
                            Layout.fillWidth: true; implicitHeight: 6; radius: 3; color: Theme.surfaceContainerHighest
                            StyledRect { width: parent.width * Math.max(0, Math.min(1, (root.diskUsage || 0) / 100)); height: parent.height; radius: parent.radius; color: Theme.primary }
                        }
                    }
                }
            }
        }
    }
}
