import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

StyledRect {
    id: root
    property var sysResources: ({ cpu: {}, memory: {}, disk_root: {} })
    property bool showCpuTemperature: true
    property bool enableGraphs: true
    property var cpuHistory: []
    property var getMetricColorFunc: function(value) { return Theme.primary; }
    property var getStorageColorFunc: function(value) { return Theme.primary; }

    readonly property real cpuValue: Number(sysResources.cpu.usage_percent) || 0
    readonly property real ramValue: Number(sysResources.memory.usage_percent) || 0
    readonly property real diskValue: Number(sysResources.disk_root.usage_percent) || 0

    Layout.fillWidth: true
    implicitHeight: contents.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh

    onCpuValueChanged: cpuRing.requestPaint()
    onCpuHistoryChanged: historyGraph.requestPaint()

    ColumnLayout {
        id: contents
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        RowLayout {
            Layout.fillWidth: true
            DIcon { name: "monitor_heart"; size: 21; color: Theme.primary }
            StyledText { text: "Resources"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingL

            Item {
                Layout.preferredWidth: 140
                Layout.preferredHeight: 146
                Canvas {
                    id: cpuRing
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 132
                    height: 132
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.lineWidth = 10;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.strokeStyle = Theme.surfaceContainerHighest;
                        ctx.arc(width / 2, height / 2, 52, -Math.PI * 0.75, Math.PI * 0.75);
                        ctx.stroke();
                        ctx.beginPath();
                        ctx.strokeStyle = root.getMetricColorFunc(root.cpuValue);
                        ctx.arc(width / 2, height / 2, 52, -Math.PI * 0.75, -Math.PI * 0.75 + Math.PI * 1.5 * Math.max(0, Math.min(100, root.cpuValue)) / 100);
                        ctx.stroke();
                    }
                }
                Column {
                    anchors.centerIn: cpuRing
                    spacing: 1
                    StyledText { text: root.sysResources.cpu.usage_percent === undefined ? "N/A" : root.cpuValue.toFixed(1) + "%"; font.pixelSize: Theme.fontSizeLarge + 7; font.weight: Font.Bold; color: Theme.surfaceText; anchors.horizontalCenter: parent.horizontalCenter }
                    StyledText { text: "CPU"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; anchors.horizontalCenter: parent.horizontalCenter }
                }
                StyledText {
                    visible: root.showCpuTemperature
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    text: "Temperature  " + (root.sysResources.cpu.temp_c == null ? "N/A" : root.sysResources.cpu.temp_c + "°C")
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { text: "Memory"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
                        StyledText { text: root.sysResources.memory.usage_percent === undefined ? "N/A" : root.ramValue.toFixed(1) + "%"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: root.getMetricColorFunc(root.ramValue) }
                    }
                    StyledRect {
                        Layout.fillWidth: true; implicitHeight: 7; radius: 4; color: Theme.surfaceContainerHighest
                        StyledRect { width: parent.width * Math.max(0, Math.min(1, root.ramValue / 100)); height: parent.height; radius: parent.radius; color: root.getMetricColorFunc(root.ramValue) }
                    }
                    StyledText { text: root.sysResources.memory.total_bytes ? (Math.round(root.sysResources.memory.used_bytes / 1073741824 * 10) / 10) + " / " + (Math.round(root.sysResources.memory.total_bytes / 1073741824 * 10) / 10) + " GiB" : "Capacity unavailable"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { text: "Root filesystem"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
                        StyledText { text: root.sysResources.disk_root.usage_percent === undefined ? "N/A" : root.diskValue.toFixed(1) + "%"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: root.getStorageColorFunc(root.diskValue) }
                    }
                    StyledRect {
                        Layout.fillWidth: true; implicitHeight: 7; radius: 4; color: Theme.surfaceContainerHighest
                        StyledRect { width: parent.width * Math.max(0, Math.min(1, root.diskValue / 100)); height: parent.height; radius: parent.radius; color: root.getStorageColorFunc(root.diskValue) }
                    }
                    StyledText { text: root.sysResources.disk_root.used_bytes !== undefined ? (Math.round(root.sysResources.disk_root.used_bytes / 1073741824 * 10) / 10) + " GiB used" : "Capacity unavailable"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                }
            }
        }

        Item {
            visible: root.enableGraphs
            Layout.fillWidth: true
            implicitHeight: root.enableGraphs ? 66 : 0
            Canvas {
                id: historyGraph
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = Theme.withAlpha(Theme.outlineStrong, 0.4);
                    ctx.lineWidth = 1;
                    ctx.beginPath(); ctx.moveTo(0, height - 5); ctx.lineTo(width, height - 5); ctx.stroke();
                    if (!root.cpuHistory || root.cpuHistory.length < 2) return;
                    ctx.strokeStyle = root.getMetricColorFunc(root.cpuValue);
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    for (var i = 0; i < root.cpuHistory.length; i++) {
                        var x = i * width / (root.cpuHistory.length - 1);
                        var y = height - 5 - Math.max(0, Math.min(100, root.cpuHistory[i])) * (height - 12) / 100;
                        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                    }
                    ctx.stroke();
                }
            }
            StyledText { anchors.left: parent.left; anchors.top: parent.top; text: "CPU TREND"; font.pixelSize: Theme.fontSizeSmall - 1; font.weight: Font.Bold; color: Theme.surfaceVariantText }
        }
    }
}
