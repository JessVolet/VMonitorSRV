import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

StyledRect {
    id: root
    property var sysInfo: ({})
    property var currentServerObj: ({})
    property bool isOffline: false
    property bool hasResponse: false

    Layout.fillWidth: true
    implicitHeight: infoRows.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh

    ColumnLayout {
        id: infoRows
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        RowLayout {
            Layout.fillWidth: true
            DIcon { name: "computer"; size: 20; color: Theme.primary }
            StyledText { text: "System identity"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
            StyledText { text: root.isOffline ? "Unavailable" : root.hasResponse ? "Connected" : "Checking"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: root.isOffline ? Theme.error : Theme.primary }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.withAlpha(Theme.outlineStrong, 0.35) }

        RowLayout {
            Layout.fillWidth: true
            StyledText { text: "Host"; Layout.preferredWidth: 108; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
            StyledText { text: root.sysInfo.hostname || "N/A"; Layout.fillWidth: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; wrapMode: Text.Wrap }
        }
        RowLayout {
            Layout.fillWidth: true
            StyledText { text: "CPU model"; Layout.preferredWidth: 108; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
            StyledText { text: root.sysInfo.cpu_name || "N/A"; Layout.fillWidth: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; wrapMode: Text.Wrap }
        }
        RowLayout {
            Layout.fillWidth: true
            StyledText { text: "Hardware"; Layout.preferredWidth: 108; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
            StyledText { text: root.sysInfo.hardware_model || "N/A"; Layout.fillWidth: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; wrapMode: Text.Wrap }
        }
        RowLayout {
            Layout.fillWidth: true
            StyledText { text: "Operating system"; Layout.preferredWidth: 108; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
            StyledText { text: root.sysInfo.os_name || "N/A"; Layout.fillWidth: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; wrapMode: Text.Wrap }
        }
        RowLayout {
            Layout.fillWidth: true
            StyledText { text: "Uptime"; Layout.preferredWidth: 108; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
            StyledText { text: root.sysInfo.uptime || "N/A"; Layout.fillWidth: true; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; wrapMode: Text.Wrap }
        }
    }
}
