import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

StyledRect {
    id: root
    property var crossServerAlerts: []
    property var alertDetails: []

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
            DIcon { name: "notifications_active"; size: 21; color: root.crossServerAlerts.length ? Theme.warning : Theme.primary }
            StyledText { text: "Alerts"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
            StyledText { text: String(root.crossServerAlerts.reduce(function(sum, item) { return sum + item.count; }, 0)); font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: root.crossServerAlerts.length ? Theme.warning : Theme.primary }
        }

        StyledText {
            visible: root.crossServerAlerts.length === 0
            text: "No active alerts reported by configured servers"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        Repeater {
            model: root.crossServerAlerts
            delegate: StyledRect {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHighest
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    DIcon { name: "warning"; size: 18; color: Theme.warning }
                    StyledText { text: modelData.serverName || modelData.host; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; Layout.fillWidth: true }
                    StyledText { text: String(modelData.count); font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.warning }
                }
            }
        }

        StyledText { text: "Selected server · critical details"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceVariantText }
        StyledText { visible: root.alertDetails.length === 0; text: "No critical alert details"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }

        Repeater {
            model: root.alertDetails
            delegate: StyledRect {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: detailContent.implicitHeight + Theme.spacingS * 2
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHighest
                ColumnLayout {
                    id: detailContent
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingXS
                    RowLayout {
                        Layout.fillWidth: true
                        DIcon { name: "error"; size: 18; color: Theme.error }
                        StyledText { text: (modelData.type || "Alert") + " · " + (modelData.state || "CRITICAL"); font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.error; Layout.fillWidth: true }
                    }
                    StyledText { text: modelData.message || "No message supplied"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    StyledText { text: "Peak " + (modelData.max_value ?? "N/A") + "  ·  Average " + (modelData.avg_value ?? "N/A") + "  ·  " + (modelData.ongoing ? "Ongoing" : "Ended"); font.pixelSize: Theme.fontSizeSmall - 1; color: Theme.surfaceVariantText }
                }
            }
        }
    }
}
