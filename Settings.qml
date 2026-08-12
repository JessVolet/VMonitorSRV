import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "vMonitorSRV"

    StyledText {
        width: parent.width
        text: "VMonitorSRV Configuration"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "enableGraphs"
        label: "Enable Mini Sparkline Graphs"
        description: "Turn off mini-charts to conserve GPU and CPU resources"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "fastRefreshInterval"
        label: "Fast Metrics Refresh Interval"
        description: "Update frequency for constant high-rate metrics (CPU %, RAM %, Disk Root %)"
        defaultValue: 2
        minimum: 1
        maximum: 10
        unit: "s"
    }

    SliderSetting {
        settingKey: "slowRefreshInterval"
        label: "General Info Refresh Interval"
        description: "Update frequency for static system info, container list, subvolumes, and interface discovery"
        defaultValue: 20
        minimum: 10
        maximum: 60
        unit: "s"
    }

    SliderSetting {
        settingKey: "detailRefreshInterval"
        label: "On-Demand Details Polling Interval"
        description: "Update frequency when inspecting live container CPU or selected network graph detail"
        defaultValue: 2
        minimum: 1
        maximum: 10
        unit: "s"
    }
}
