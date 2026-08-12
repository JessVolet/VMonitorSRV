import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property string selectedNetId: "eno1"
    property var selectedNetData: ({})
    property var netRxHistory: []
    property bool enableGraphs: true
    property var allInterfacesList: []
    property string virtualNetQuery: ""

    property var getIpStringFunc: function(d) { return "N/A"; }
    property var getRxRateStringFunc: function(d) { return "0 B/s"; }
    property var getTxRateStringFunc: function(d) { return "0 B/s"; }
    property var formatBytesRateFunc: function(b) { return "0 B/s"; }

    signal selectInterface(string ifName)
    signal updateVirtualNetQuery(string query)

    Layout.fillWidth: true
    implicitHeight: netCol.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh

    ColumnLayout {
        id: netCol
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        RowLayout {
            Layout.fillWidth: true
            DankIcon { name: "lan"; color: Theme.primary }
            StyledText {
                text: "Network"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.surfaceText
            }
        }

        RowLayout {
            Layout.fillWidth: true

            DankIcon { name: "lan"; color: Theme.primary }

            ColumnLayout {
                spacing: 1
                StyledText {
                    text: `Interface: ${root.selectedNetId} (IP: ${root.getIpStringFunc(root.selectedNetData)})`
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }
                StyledText {
                    text: `RX Rate: ${root.getRxRateStringFunc(root.selectedNetData)}  |  TX Rate: ${root.getTxRateStringFunc(root.selectedNetData)}`
                    font.pixelSize: Theme.fontSizeSmall - 1
                    color: Theme.surfaceVariantText
                }
            }
        }

        Item {
            visible: root.enableGraphs
            Layout.fillWidth: true
            implicitHeight: 65

            property int hoverIndex: -1
            property real hoverX: 0
            property real hoverY: 0
            property string hoverText: ""

            Canvas {
                id: netCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var h = height - 12;
                    var w = width - 40;
                    var x0 = 36;

                    var maxRx = 1;
                    for (var i = 0; i < root.netRxHistory.length; i++) {
                        if (root.netRxHistory[i] > maxRx) maxRx = root.netRxHistory[i];
                    }

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
                    ctx.fillText(root.formatBytesRateFunc(maxRx * 1024), 0, 8);
                    ctx.fillText(root.formatBytesRateFunc((maxRx / 2) * 1024), 0, h / 2 + 5);
                    ctx.fillText("0 B/s", 0, h + 5);

                    if (!root.netRxHistory || root.netRxHistory.length < 2) return;

                    ctx.beginPath();
                    ctx.lineWidth = 2;
                    ctx.strokeStyle = Theme.primary;

                    var step = w / (root.netRxHistory.length - 1);
                    for (var j = 0; j < root.netRxHistory.length; j++) {
                        var val = root.netRxHistory[j] || 0;
                        var y = h - (val / maxRx * h) + 2;
                        var x = x0 + j * step;
                        if (j === 0) ctx.moveTo(x, y);
                        else ctx.lineTo(x, y);
                    }
                    ctx.stroke();

                    if (parent.hoverIndex >= 0 && parent.hoverIndex < root.netRxHistory.length) {
                        var hx = x0 + parent.hoverIndex * step;
                        var hval = root.netRxHistory[parent.hoverIndex] || 0;
                        var hy = h - (hval / maxRx * h) + 2;

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
                    function onNetRxHistoryChanged() {
                        if (root.enableGraphs) netCanvas.requestPaint();
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: (mouse) => {
                    var w = width - 40;
                    var x0 = 36;
                    if (mouse.x >= x0 && mouse.x <= x0 + w && root.netRxHistory.length > 1) {
                        var step = w / (root.netRxHistory.length - 1);
                        var idx = Math.round((mouse.x - x0) / step);
                        idx = Math.max(0, Math.min(root.netRxHistory.length - 1, idx));
                        parent.hoverIndex = idx;
                        parent.hoverX = x0 + idx * step;
                        var valKb = root.netRxHistory[idx] || 0;
                        var maxRx = 1;
                        for (var i = 0; i < root.netRxHistory.length; i++) {
                            if (root.netRxHistory[i] > maxRx) maxRx = root.netRxHistory[i];
                        }
                        parent.hoverY = (height - 12) - (valKb / maxRx * (height - 12)) + 2;
                        parent.hoverText = `RX: ${root.formatBytesRateFunc(valKb * 1024)}`;
                    } else {
                        parent.hoverIndex = -1;
                    }
                    netCanvas.requestPaint();
                }
                onExited: {
                    parent.hoverIndex = -1;
                    netCanvas.requestPaint();
                }
            }

            StyledRect {
                visible: parent.hoverIndex >= 0
                x: Math.min(parent.width - width - 4, Math.max(4, parent.hoverX - width / 2))
                y: Math.max(0, parent.hoverY - 24)
                width: netHoverLabel.implicitWidth + 12
                height: 20
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHighest
                border.color: Theme.primary
                border.width: 1

                StyledText {
                    id: netHoverLabel
                    anchors.centerIn: parent
                    text: parent.parent.hoverText
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.weight: Font.Bold
                    color: Theme.primary
                }
            }
        }

        StyledText {
            text: `Select Interface to Graph (${root.allInterfacesList.length})`
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        DankTextField {
            Layout.fillWidth: true
            placeholderText: "Filter physical & virtual interfaces..."
            text: root.virtualNetQuery
            onTextChanged: root.updateVirtualNetQuery(text)
        }

        ListView {
            Layout.fillWidth: true
            implicitHeight: Math.min(150, Math.max(45, root.allInterfacesList.length * 42))
            clip: true
            model: root.allInterfacesList
            spacing: Theme.spacingXS

            delegate: StyledRect {
                width: ListView.view.width
                height: 38
                radius: Theme.cornerRadiusSmall
                color: isSelected ? Theme.surfaceContainerHighest : Theme.surfaceContainerHighest

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

                    StyledRect {
                        width: 60
                        height: 26
                        radius: Theme.cornerRadiusSmall
                        color: isSelected ? Theme.primary : Theme.surfaceContainerHighest

                        StyledText {
                            anchors.centerIn: parent
                            text: isSelected ? "Active" : "Select"
                            font.pixelSize: Theme.fontSizeSmall - 1
                            font.weight: isSelected ? Font.Bold : Font.Normal
                            color: isSelected ? Theme.onPrimary : Theme.surfaceText
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.selectInterface(itemIfName)
                }
            }
        }
    }
}
