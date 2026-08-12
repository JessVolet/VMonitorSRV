import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property var sysInfo: ({})
    property var currentServerObj: ({})
    property bool isOffline: false

    Layout.fillWidth: true
    implicitHeight: infoCol.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh

    ColumnLayout {
        id: infoCol
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            DankIcon {
                name: "dns"
                size: 22
                color: Theme.primary
            }

            StyledText {
                text: root.sysInfo.hostname || root.currentServerObj.name || "server"
                font.pixelSize: Theme.fontSizeLarge + 2
                font.weight: Font.Bold
                color: Theme.primary
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: root.isOffline ? "OFFLINE" : "ONLINE"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                color: root.isOffline ? Theme.error : Theme.primary
            }
        }

        GridLayout {
            columns: 2
            rowSpacing: 4
            columnSpacing: Theme.spacingM
            Layout.fillWidth: true

            StyledText { text: "CPU Model:"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceVariantText }
            StyledText { text: root.sysInfo.cpu_name || "Intel(R) Core(TM) i5-8500 CPU @ 3.00GHz"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; elide: Text.ElideRight; Layout.fillWidth: true }

            StyledText { text: "Hardware Model:"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceVariantText }
            StyledText { text: root.sysInfo.hardware_model || "10SJS0FJ00"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; elide: Text.ElideRight; Layout.fillWidth: true }

            StyledText { text: "OS Name:"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceVariantText }
            RowLayout {
                spacing: Theme.spacingXS
                Layout.fillWidth: true
                DankIcon {
                    name: "dns"
                    size: 16
                    color: Theme.primary
                }
                StyledText {
                    text: root.sysInfo.os_name || "Fedora Linux 44 64bit"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            StyledText { text: "Uptime:"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceVariantText }
            StyledText { text: root.sysInfo.uptime || "17 days, 17:36:20"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }
}
