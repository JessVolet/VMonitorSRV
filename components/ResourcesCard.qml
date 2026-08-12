import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property var sysResources: ({ "cpu": { "usage_percent": 0, "temp_c": 0 }, "memory": { "usage_percent": 0 }, "disk_root": { "usage_percent": 0 } })
    property bool enableGraphs: true
    property var cpuHistory: []
    property var getMetricColorFunc: function(val) { return Theme.primary; }
    property var getStorageColorFunc: function(val) { return Theme.primary; }

    Layout.fillWidth: true
    implicitHeight: resCol.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh

    ColumnLayout {
        id: resCol
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        RowLayout {
            Layout.fillWidth: true
            DankIcon { name: "speed"; color: Theme.primary }
            StyledText {
                text: "Resources"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.surfaceText
            }
        }

        RowLayout {
            Layout.fillWidth: true
            StyledText { text: "CPU Usage"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; font.weight: Font.Bold }
            Item { Layout.fillWidth: true }
            StyledText {
                text: `${(root.sysResources.cpu.usage_percent || 0).toFixed(1)}% (${root.sysResources.cpu.temp_c || 0}°C)`
                font.pixelSize: Theme.fontSizeSmall
                color: root.getMetricColorFunc(root.sysResources.cpu.usage_percent || 0)
                font.weight: Font.Bold
            }
        }

        StyledRect {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: Theme.surfaceContainerHighest
            StyledRect {
                width: parent.width * Math.min(1.0, (root.sysResources.cpu.usage_percent || 0) / 100.0)
                height: parent.height
                radius: parent.radius
                color: root.getMetricColorFunc(root.sysResources.cpu.usage_percent || 0)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            StyledText { text: "RAM Usage"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; font.weight: Font.Bold }
            Item { Layout.fillWidth: true }
            StyledText {
                text: `${(root.sysResources.memory.usage_percent || 0).toFixed(1)}%`
                font.pixelSize: Theme.fontSizeSmall
                color: root.getMetricColorFunc(root.sysResources.memory.usage_percent || 0)
                font.weight: Font.Bold
            }
        }

        StyledRect {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: Theme.surfaceContainerHighest
            StyledRect {
                width: parent.width * Math.min(1.0, (root.sysResources.memory.usage_percent || 0) / 100.0)
                height: parent.height
                radius: parent.radius
                color: root.getMetricColorFunc(root.sysResources.memory.usage_percent || 0)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            StyledText { text: "Disk Root (/)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; font.weight: Font.Bold }
            Item { Layout.fillWidth: true }
            StyledText {
                text: `${(root.sysResources.disk_root.usage_percent || 0).toFixed(1)}%`
                font.pixelSize: Theme.fontSizeSmall
                color: root.getStorageColorFunc(root.sysResources.disk_root.usage_percent || 0)
                font.weight: Font.Bold
            }
        }

        StyledRect {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: Theme.surfaceContainerHighest
            StyledRect {
                width: parent.width * Math.min(1.0, (root.sysResources.disk_root.usage_percent || 0) / 100.0)
                height: parent.height
                radius: parent.radius
                color: root.getStorageColorFunc(root.sysResources.disk_root.usage_percent || 0)
            }
        }

        Item {
            visible: root.enableGraphs
            Layout.fillWidth: true
            implicitHeight: 55

            property int hoverIndex: -1
            property real hoverX: 0
            property real hoverY: 0
            property string hoverText: ""

            Canvas {
                id: cpuCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var h = height - 12;
                    var w = width - 24;
                    var x0 = 20;

                    ctx.beginPath();
                    ctx.lineWidth = 1;
                    ctx.strokeStyle = Theme.surfaceContainerHighest;
                    ctx.moveTo(x0, 2);
                    ctx.lineTo(x0 + w, 2);
                    ctx.moveTo(x0, h / 2 + 2);
                    ctx.lineTo(x0 + w, h / 2 + 2);
                    ctx.moveTo(x0, h + 2);
                    ctx.lineTo(x0 + w, h + 2);
                    ctx.stroke();

                    ctx.fillStyle = Theme.surfaceVariantText;
                    ctx.font = "8px sans-serif";
                    ctx.fillText("100%", 0, 8);
                    ctx.fillText("50%", 0, h / 2 + 5);
                    ctx.fillText("0%", 0, h + 5);

                    if (!root.cpuHistory || root.cpuHistory.length < 2) return;

                    ctx.beginPath();
                    ctx.lineWidth = 2;
                    ctx.strokeStyle = root.getMetricColorFunc(root.sysResources.cpu.usage_percent || 0);

                    var step = w / (root.cpuHistory.length - 1);
                    for (var i = 0; i < root.cpuHistory.length; i++) {
                        var val = root.cpuHistory[i] || 0;
                        var y = h - (val / 100.0 * h) + 2;
                        var x = x0 + i * step;
                        if (i === 0) ctx.moveTo(x, y);
                        else ctx.lineTo(x, y);
                    }
                    ctx.stroke();

                    if (parent.hoverIndex >= 0 && parent.hoverIndex < root.cpuHistory.length) {
                        var hx = x0 + parent.hoverIndex * step;
                        var hval = root.cpuHistory[parent.hoverIndex] || 0;
                        var hy = h - (hval / 100.0 * h) + 2;

                        ctx.beginPath();
                        ctx.lineWidth = 1;
                        ctx.strokeStyle = Theme.primary;
                        ctx.moveTo(hx, 0);
                        ctx.lineTo(hx, h + 4);
                        ctx.stroke();

                        ctx.beginPath();
                        ctx.arc(hx, hy, 4, 0, 2 * Math.PI);
                        ctx.fillStyle = Theme.primary;
                        ctx.fill();
                    }
                }

                Connections {
                    target: root
                    function onCpuHistoryChanged() {
                        if (root.enableGraphs) cpuCanvas.requestPaint();
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: (mouse) => {
                    var w = width - 24;
                    var x0 = 20;
                    if (mouse.x >= x0 && mouse.x <= x0 + w && root.cpuHistory.length > 1) {
                        var step = w / (root.cpuHistory.length - 1);
                        var idx = Math.round((mouse.x - x0) / step);
                        idx = Math.max(0, Math.min(root.cpuHistory.length - 1, idx));
                        parent.hoverIndex = idx;
                        parent.hoverX = x0 + idx * step;
                        var val = root.cpuHistory[idx] || 0;
                        parent.hoverY = (height - 12) - (val / 100.0 * (height - 12)) + 2;
                        parent.hoverText = `CPU: ${val.toFixed(1)}%`;
                    } else {
                        parent.hoverIndex = -1;
                    }
                    cpuCanvas.requestPaint();
                }
                onExited: {
                    parent.hoverIndex = -1;
                    cpuCanvas.requestPaint();
                }
            }

            StyledRect {
                visible: parent.hoverIndex >= 0
                x: Math.min(parent.width - width - 4, Math.max(4, parent.hoverX - width / 2))
                y: Math.max(0, parent.hoverY - 24)
                width: hoverLabel.implicitWidth + 12
                height: 20
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHighest
                border.color: Theme.primary
                border.width: 1

                StyledText {
                    id: hoverLabel
                    anchors.centerIn: parent
                    text: parent.parent.hoverText
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.weight: Font.Bold
                    color: Theme.primary
                }
            }
        }
    }
}
