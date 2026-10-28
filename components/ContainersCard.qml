import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

StyledRect {
    id: root
    property var containerList: []
    property var containerStats: ({ total: 0, running: 0, stopped: 0, problems: 0 })
    property string expandedContainerId: ""
    property real expandedContainerCpu: 0
    property var expandedContainerHistory: []
    property bool enableGraphs: true
    property var getMetricColorFunc: function(value) { return Theme.primary; }
    signal toggleExpandContainer(string cId)
    signal copyContainerId(string cId)

    Layout.fillWidth: true
    implicitHeight: contents.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh

    ColumnLayout {
        id: contents
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        RowLayout {
            Layout.fillWidth: true
            DIcon { name: "deployed_code"; size: 21; color: Theme.primary }
            StyledText { text: "Containers"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
            StyledText { text: String(root.containerStats.total || root.containerList.length); font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: Theme.primary }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM
            StyledText { text: (root.containerStats.running || 0) + " running"; font.pixelSize: Theme.fontSizeSmall; color: Theme.primary }
            StyledText { text: (root.containerStats.stopped || 0) + " stopped"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
            StyledText { text: (root.containerStats.problems || 0) + " problems"; font.pixelSize: Theme.fontSizeSmall; color: root.containerStats.problems ? Theme.error : Theme.surfaceVariantText }
        }

        StyledText {
            visible: root.containerList.length === 0
            text: "No containers reported by this server"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        Repeater {
            model: root.containerList
            delegate: StyledRect {
                required property var modelData
                required property int index
                readonly property string containerId: String(modelData.id || "")
                readonly property bool expanded: root.expandedContainerId === containerId
                readonly property bool running: modelData.status === "running"

                Layout.fillWidth: true
                implicitHeight: rowContent.implicitHeight + Theme.spacingS * 2
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHighest

                ColumnLayout {
                    id: rowContent
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingXS

                    RowLayout {
                        Layout.fillWidth: true
                        DIcon { name: running ? "play_circle" : "pause_circle"; size: 20; color: running ? Theme.primary : Theme.warning }
                        StyledText { text: modelData.name || containerId || "Unnamed container"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true; elide: Text.ElideRight }
                        StyledText { text: modelData.status || "unknown"; font.pixelSize: Theme.fontSizeSmall; color: running ? Theme.primary : Theme.warning }
                        DButton { iconName: expanded ? "expand_less" : "expand_more"; tooltipText: expanded ? "Hide details" : "Show details"; backgroundColor: Theme.surfaceContainerHigh; textColor: Theme.surfaceText; onClicked: root.toggleExpandContainer(containerId) }
                    }

                    StyledText { text: modelData.image || "Image unavailable"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; elide: Text.ElideMiddle }
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { text: (modelData.engine || "Engine N/A") + "  ·  " + (modelData.memory_usage || "Memory N/A"); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; Layout.fillWidth: true; elide: Text.ElideRight }
                        StyledText { text: modelData.uptime || "Uptime N/A"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; elide: Text.ElideRight }
                    }

                    ColumnLayout {
                        visible: expanded
                        Layout.fillWidth: true
                        spacing: Theme.spacingS
                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.withAlpha(Theme.outlineStrong, 0.35) }
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText { text: "ID  " + containerId + (modelData.pod ? "  ·  Pod " + modelData.pod : ""); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; elide: Text.ElideMiddle }
                            DButton { iconName: "content_copy"; tooltipText: "Copy container ID"; backgroundColor: Theme.surfaceContainerHigh; textColor: Theme.surfaceText; onClicked: root.copyContainerId(containerId) }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText { text: "CPU usage"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; Layout.fillWidth: true }
                            StyledText { text: root.expandedContainerCpu.toFixed(1) + "%"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: root.getMetricColorFunc(root.expandedContainerCpu) }
                        }
                        StyledRect {
                            Layout.fillWidth: true; implicitHeight: 5; radius: 3; color: Theme.surfaceContainerHigh
                            StyledRect { width: parent.width * Math.max(0, Math.min(1, root.expandedContainerCpu / 100)); height: parent.height; radius: parent.radius; color: root.getMetricColorFunc(root.expandedContainerCpu) }
                        }
                        Canvas {
                            visible: root.enableGraphs
                            Layout.fillWidth: true
                            implicitHeight: root.enableGraphs ? 38 : 0
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                if (!root.expandedContainerHistory || root.expandedContainerHistory.length < 2) return;
                                ctx.strokeStyle = root.getMetricColorFunc(root.expandedContainerCpu);
                                ctx.lineWidth = 2;
                                ctx.beginPath();
                                for (var i = 0; i < root.expandedContainerHistory.length; i++) {
                                    var x = i * width / (root.expandedContainerHistory.length - 1);
                                    var y = height - 2 - Math.max(0, Math.min(100, root.expandedContainerHistory[i])) * (height - 4) / 100;
                                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                                }
                                ctx.stroke();
                            }
                            Connections { target: root; function onExpandedContainerHistoryChanged() { parent.requestPaint(); } }
                        }
                    }
                }
            }
        }
    }
}
