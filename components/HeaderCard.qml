import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

StyledRect {
    id: root
    property var currentServerObj: ({})
    property bool isOffline: false
    property bool hasResponse: false
    property var sysInfo: ({})
    property bool showServerDropdown: false
    signal toggleServerDropdown()
    signal refreshClicked()
    signal settingsClicked()

    Layout.fillWidth: true
    implicitHeight: 70
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh

    Rectangle {
        width: 4
        height: parent.height - Theme.spacingM * 2
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        radius: 2
        color: !root.currentServerObj.host ? Theme.surfaceVariantText : root.isOffline ? Theme.error : Theme.primary
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingS
        spacing: Theme.spacingS

        DIcon {
            name: "dns"
            size: 25
            color: root.isOffline ? Theme.error : Theme.primary
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            StyledText {
                text: root.currentServerObj.name || root.sysInfo.hostname || "No server selected"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.surfaceText
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            StyledText {
                text: (root.currentServerObj.host || "Configure a server") + "  ·  " + (root.sysInfo.uptime || "Uptime unavailable")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        StyledText {
            text: !root.currentServerObj.host ? "CONFIGURE" : root.isOffline ? "UNAVAILABLE" : root.hasResponse ? "CONNECTED" : "CHECKING"
            font.pixelSize: Theme.fontSizeSmall - 1
            font.weight: Font.Bold
            color: !root.currentServerObj.host ? Theme.surfaceVariantText : root.isOffline ? Theme.error : Theme.primary
        }

        DButton {
            iconName: root.showServerDropdown ? "expand_less" : "expand_more"
            tooltipText: "Select server"
            backgroundColor: root.showServerDropdown ? Theme.primary : Theme.surfaceContainerHighest
            textColor: root.showServerDropdown ? Theme.onPrimary : Theme.surfaceText
            onClicked: root.toggleServerDropdown()
        }
        DButton {
            iconName: "refresh"
            tooltipText: "Refresh"
            backgroundColor: Theme.surfaceContainerHighest
            textColor: Theme.surfaceText
            onClicked: root.refreshClicked()
        }
        DButton {
            iconName: "settings"
            tooltipText: "Plugin settings"
            backgroundColor: Theme.surfaceContainerHighest
            textColor: Theme.surfaceText
            onClicked: root.settingsClicked()
        }
    }
}
