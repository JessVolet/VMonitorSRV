import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property var containerList: []
    property string expandedContainerId: ""
    property real expandedContainerCpu: 0
    property var expandedContainerHistory: []
    property bool enableGraphs: true

    property var getMetricColorFunc: function(val) { return Theme.primary; }

    signal toggleExpandContainer(string cId)
    signal copyContainerId(string cId)
    signal restartContainer(string cId)
    signal stopContainer(string cId)

    Layout.fillWidth: true
    implicitHeight: cntCol.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh

    ColumnLayout {
        id: cntCol
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        RowLayout {
            Layout.fillWidth: true
            DankIcon { name: "layers"; color: Theme.primary }
            StyledText {
                text: "Containers"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.surfaceText
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
            implicitHeight: Math.min(260, Math.max(60, root.containerList.length * (isExpanded ? 120 : 62)))
            clip: true
            model: root.containerList
            spacing: Theme.spacingS

            delegate: StyledRect {
                width: ListView.view.width
                height: isExpanded ? 115 : 58
                radius: Theme.cornerRadiusSmall
                color: modelData.status === "running" ? Theme.surfaceContainerHighest : Theme.surfaceContainer

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
                            backgroundColor: Theme.surfaceContainerHigh
                            textColor: Theme.surfaceText
                            onClicked: root.toggleExpandContainer(cId)
                        }

                        DankButton {
                            iconName: "content_copy"
                            backgroundColor: Theme.surfaceContainerHigh
                            textColor: Theme.surfaceText
                            onClicked: root.copyContainerId(cId)
                        }

                        DankButton {
                            iconName: "restart_alt"
                            backgroundColor: Theme.surfaceContainerHigh
                            textColor: Theme.surfaceText
                            onClicked: root.restartContainer(cId)
                        }

                        DankButton {
                            iconName: "stop"
                            backgroundColor: Theme.surfaceContainerHigh
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
                                    color: root.getMetricColorFunc(root.expandedContainerCpu)
                                }
                            }

                            StyledText {
                                text: `${root.expandedContainerCpu.toFixed(1)}%`
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                                color: root.getMetricColorFunc(root.expandedContainerCpu)
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
                                ctx.strokeStyle = root.getMetricColorFunc(root.expandedContainerCpu);

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
