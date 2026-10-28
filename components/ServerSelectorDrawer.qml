import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

StyledRect {
    id: root

    property var serversList: []
    property int activeServerIndex: 0

    signal serverSelected(int index)

    Layout.fillWidth: true
    implicitHeight: mainLayout.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius * 1.5
    color: Theme.surfaceContainerHigh
    border.width: 1
    border.color: Theme.withAlpha(Theme.outlineStrong, 0.32)

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXS

            StyledText {
                text: "Servers"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.primary
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

        }

        StyledText {
            visible: !root.serversList || root.serversList.length === 0
            text: "Add server URLs in plugin settings"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.spacingS
            Layout.bottomMargin: Theme.spacingS
        }

        GridLayout {
            visible: root.serversList && root.serversList.length > 0
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.spacingXS
            rowSpacing: Theme.spacingXS

            Repeater {
                model: root.serversList

                delegate: StyledRect {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredWidth: (root.width - Theme.spacingM * 2 - Theme.spacingXS) / 2
                    implicitHeight: 68
                    radius: Theme.cornerRadiusSmall

                    property bool isSelected: index === root.activeServerIndex
                    color: isSelected ? Theme.withAlpha(Theme.primary, 0.24) : Theme.surfaceContainerHighest
                    border.width: isSelected ? 1 : 0
                    border.color: Theme.primary

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingXS

                        RowLayout {
                            Layout.fillWidth: true
                            DIcon {
                                name: isSelected ? "dns" : "server"
                                size: 16
                                color: isSelected ? Theme.primary : Theme.surfaceVariantText
                            }
                            StyledText {
                                text: modelData.name || modelData.host
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: isSelected ? Font.Bold : Font.Medium
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            DIcon { visible: isSelected; name: "check_circle"; size: 15; color: Theme.primary }
                        }
                        StyledText {
                            text: modelData.host + ":" + modelData.port
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.surfaceVariantText
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.serverSelected(index)
                    }
                }
            }
        }
    }
}
