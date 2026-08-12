import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Item {
    id: root

    property var pluginService: null
    property string pluginId: "vMonitorSRV"
    property bool editMode: false
    property real widgetWidth: 340
    property real widgetHeight: 220
    property real minWidth: 280
    property real minHeight: 180

    property string baseUrl: "http://10.190.217.209:61208/api/widget"
    property bool isOffline: false
    property string hostname: "VMonitorSRV"
    property real cpuUsage: 0
    property real cpuTemp: 0
    property real ramUsage: 0
    property real diskUsage: 0

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchMetrics()
    }

    function fetchMetrics() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.baseUrl + "/resources", true);
        xhr.timeout = 2500;
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    root.isOffline = false;
                    try {
                        var data = JSON.parse(xhr.responseText);
                        if (data.cpu) {
                            root.cpuUsage = data.cpu.usage_percent || 0;
                            root.cpuTemp = data.cpu.temp_c || 0;
                        }
                        if (data.memory) root.ramUsage = data.memory.usage_percent || 0;
                        if (data.disk_root) root.diskUsage = data.disk_root.usage_percent || 0;
                    } catch (e) {}
                } else {
                    root.isOffline = true;
                }
            }
        };
        xhr.send();
    }

    StyledRect {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        opacity: 0.90
        border.color: root.editMode ? Theme.primary : "transparent"
        border.width: root.editMode ? 2 : 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            RowLayout {
                Layout.fillWidth: true

                DankIcon {
                    name: "server"
                    color: root.isOffline ? Theme.error : Theme.primary
                }

                StyledText {
                    text: root.hostname
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: root.isOffline ? "OFFLINE" : "LIVE"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    color: root.isOffline ? Theme.error : "#a6e3a1"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXS

                RowLayout {
                    Layout.fillWidth: true
                    StyledText { text: "CPU"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                    Item { Layout.fillWidth: true }
                    StyledText { text: `${root.cpuUsage.toFixed(1)}% (${root.cpuTemp}°C)`; font.pixelSize: Theme.fontSizeSmall; color: Theme.primary }
                }

                StyledRect {
                    Layout.fillWidth: true
                    height: 5
                    radius: 3
                    color: Theme.surfaceContainerHigh
                    StyledRect {
                        width: parent.width * Math.min(1.0, root.cpuUsage / 100.0)
                        height: parent.height
                        radius: parent.radius
                        color: Theme.primary
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    StyledText { text: "RAM"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                    Item { Layout.fillWidth: true }
                    StyledText { text: `${root.ramUsage.toFixed(1)}%`; font.pixelSize: Theme.fontSizeSmall; color: "#a6e3a1" }
                }

                StyledRect {
                    Layout.fillWidth: true
                    height: 5
                    radius: 3
                    color: Theme.surfaceContainerHigh
                    StyledRect {
                        width: parent.width * Math.min(1.0, root.ramUsage / 100.0)
                        height: parent.height
                        radius: parent.radius
                        color: "#a6e3a1"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    StyledText { text: "Disk Root"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                    Item { Layout.fillWidth: true }
                    StyledText { text: `${root.diskUsage.toFixed(1)}%`; font.pixelSize: Theme.fontSizeSmall; color: "#89b4fa" }
                }

                StyledRect {
                    Layout.fillWidth: true
                    height: 5
                    radius: 3
                    color: Theme.surfaceContainerHigh
                    StyledRect {
                        width: parent.width * Math.min(1.0, root.diskUsage / 100.0)
                        height: parent.height
                        radius: parent.radius
                        color: "#89b4fa"
                    }
                }
            }
        }
    }
}
