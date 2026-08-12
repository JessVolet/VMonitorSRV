import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property var crossServerAlerts: []

    Layout.fillWidth: true
    Layout.leftMargin: Theme.spacingM
    Layout.rightMargin: Theme.spacingM
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
