import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

StyledRect {
    id: root
    property var sysResources: ({ disk_root: {} })
    property var mainDisks: []
    property var subvolumesList: []
    property string selectedSubvolName: ""
    property var selectedSubvolData: ({})
    property var getStorageColorFunc: function(value) { return Theme.primary; }
    property var bytesToGbFunc: function(value) { return "N/A"; }
    signal subvolSelected(string name, var data)

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
            DIcon { name: "hard_drive"; size: 21; color: Theme.primary }
            StyledText { text: "Storage"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: rootSummary.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadiusSmall
            color: Theme.surfaceContainerHighest
            ColumnLayout {
                id: rootSummary
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS
                RowLayout {
                    Layout.fillWidth: true
                    StyledText { text: "Root filesystem  /"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
                    StyledText { text: root.sysResources.disk_root.usage_percent === undefined ? "N/A" : Number(root.sysResources.disk_root.usage_percent).toFixed(1) + "%"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: root.getStorageColorFunc(root.sysResources.disk_root.usage_percent || 0) }
                }
                StyledRect {
                    Layout.fillWidth: true; implicitHeight: 7; radius: 4; color: Theme.surfaceContainerHigh
                    StyledRect { width: parent.width * Math.max(0, Math.min(1, (root.sysResources.disk_root.usage_percent || 0) / 100)); height: parent.height; radius: parent.radius; color: root.getStorageColorFunc(root.sysResources.disk_root.usage_percent || 0) }
                }
                StyledText {
                    text: root.sysResources.disk_root.used_bytes === undefined ? "Capacity unavailable" : root.bytesToGbFunc(root.sysResources.disk_root.used_bytes) + " used  ·  " + root.bytesToGbFunc(root.sysResources.disk_root.free_bytes) + " free"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }

        StyledText { text: "MOUNTS · " + root.mainDisks.length; font.pixelSize: Theme.fontSizeSmall - 1; font.weight: Font.Bold; color: Theme.surfaceVariantText }
        StyledText { visible: root.mainDisks.length === 0; text: "No main mounts reported"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
        Repeater {
            model: root.mainDisks
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                StyledText { text: modelData.mount || modelData.name || "Mount"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceText; Layout.preferredWidth: 120; elide: Text.ElideMiddle }
                StyledText { text: modelData.device || modelData.fstype || "N/A"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; elide: Text.ElideMiddle }
                StyledText { text: modelData.percent === undefined ? "N/A" : Number(modelData.percent).toFixed(1) + "%"; font.pixelSize: Theme.fontSizeSmall; color: root.getStorageColorFunc(modelData.percent || 0) }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.withAlpha(Theme.outlineStrong, 0.35) }
        StyledText { text: "SUBVOLUMES · " + root.subvolumesList.length; font.pixelSize: Theme.fontSizeSmall - 1; font.weight: Font.Bold; color: Theme.surfaceVariantText }
        StyledText { visible: root.subvolumesList.length === 0; text: "No Btrfs or secondary volumes reported"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }

        Repeater {
            model: root.subvolumesList
            delegate: StyledRect {
                required property var modelData
                readonly property bool selected: root.selectedSubvolName === modelData.name
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Theme.cornerRadiusSmall
                color: selected ? Theme.withAlpha(Theme.primary, 0.13) : Theme.surfaceContainerHighest
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    DIcon { name: selected ? "check_circle" : "folder"; size: 18; color: selected ? Theme.primary : Theme.surfaceVariantText }
                    StyledText { text: modelData.name || modelData.mount || "Volume"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true; elide: Text.ElideRight }
                    StyledText { text: modelData.percent === undefined ? "N/A" : Number(modelData.percent).toFixed(1) + "%"; font.pixelSize: Theme.fontSizeSmall; color: root.getStorageColorFunc(modelData.percent || 0) }
                    DIcon { name: "chevron_right"; size: 18; color: Theme.surfaceVariantText }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.subvolSelected(modelData.name || "", modelData) }
            }
        }

        StyledRect {
            visible: root.subvolumesList.length > 0 && root.selectedSubvolName !== ""
            Layout.fillWidth: true
            implicitHeight: selectedDetails.implicitHeight + Theme.spacingS * 2
            radius: Theme.cornerRadiusSmall
            color: Theme.surfaceContainerHighest
            ColumnLayout {
                id: selectedDetails
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingXS
                StyledText { text: root.selectedSubvolData.name || root.selectedSubvolName; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: Theme.surfaceText }
                StyledText { text: "Mount: " + (root.selectedSubvolData.mount || "N/A") + "  ·  Device: " + (root.selectedSubvolData.device || "N/A"); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; Layout.fillWidth: true; elide: Text.ElideMiddle }
                StyledText { text: "Used: " + root.bytesToGbFunc(root.selectedSubvolData.used_bytes) + "  ·  Total: " + root.bytesToGbFunc(root.selectedSubvolData.size_bytes); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
            }
        }
    }
}
