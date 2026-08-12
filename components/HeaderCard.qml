import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property var currentServerObj: ({})
    property bool isOffline: false
    property var sysInfo: ({})
    property bool showServerDropdown: false
    property bool showAlertsDrawer: false
    property int crossServerAlertsCount: 0

    signal toggleServerDropdown()
    signal toggleAlertsDrawer()
    signal refreshClicked()
    signal settingsClicked()

    Layout.fillWidth: true
    Layout.leftMargin: Theme.spacingM
    Layout.rightMargin: Theme.spacingM
    implicitHeight: headerCol.implicitHeight + Theme.spacingS * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh

    ColumnLayout {
        id: headerCol
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingS

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            Image {
                source: "../VMonitorSRV.svg"
                sourceSize.width: 24
                sourceSize.height: 24
                width: 24
                height: 24
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "VMonitorSRV"
                font.pixelSize: Theme.fontSizeLarge + 2
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            Item { Layout.fillWidth: true }
        }

        StyledText {
            text: root.isOffline ? "Status: OFFLINE" : `IP: ${root.currentServerObj.host || "N/A"} • Up: ${root.sysInfo.uptime || "N/A"}`
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXS

            DankButton {
                text: `${root.currentServerObj.name || root.currentServerObj.host || "Server"} ▼`
                backgroundColor: root.showServerDropdown ? Theme.primary : Theme.surfaceContainerHighest
                textColor: root.showServerDropdown ? Theme.onPrimary : Theme.surfaceText
                onClicked: root.toggleServerDropdown()
            }

            Item { Layout.fillWidth: true }

            DankButton {
                iconName: "warning"
                text: `Alerts: ${root.crossServerAlertsCount}`
                backgroundColor: root.showAlertsDrawer ? "#f59e0b" : Theme.surfaceContainerHighest
                textColor: root.showAlertsDrawer ? Theme.surfaceContainer : Theme.surfaceText
                onClicked: root.toggleAlertsDrawer()
            }

            DankButton {
                iconName: "refresh"
                backgroundColor: Theme.surfaceContainerHighest
                textColor: Theme.surfaceText
                onClicked: root.refreshClicked()
            }

            DankButton {
                iconName: "settings"
                backgroundColor: Theme.surfaceContainerHighest
                textColor: Theme.surfaceText
                onClicked: root.settingsClicked()
            }
        }
    }
}
