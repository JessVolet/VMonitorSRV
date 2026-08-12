import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property var crossServerAlerts: []

    Layout.fillWidth: true
    implicitHeight: Math.max(100, Math.min(200, root.crossServerAlerts.length * 40 + 50))
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHighest

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        StyledText {
            text: "Cross-Server Active Alerts"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Bold
            color: Theme.error
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.crossServerAlerts
            spacing: Theme.spacingXS
            delegate: StyledRect {
                width: ListView.view.width
                height: 34
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHigh

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingS

                    DankIcon { name: "warning"; color: Theme.error }

                    StyledText {
                        text: modelData.log || `${modelData.serverName}: ${modelData.count} alert(s)`
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
