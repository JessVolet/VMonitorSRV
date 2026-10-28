import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets
import qs.DCommon.Widgets
import "./components"

PluginSettings {
    id: root
    pluginId: "vMonitorSRV"

    StyledText {
        width: parent.width
        text: "Monitoring preferences"
        font.pixelSize: Theme.fontSizeLarge + 2
        font.weight: Font.Bold
        color: Theme.surfaceText
    }
    StyledText {
        width: parent.width
        text: "Configure servers, display options and refresh intervals."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    ServerSettingsCard { settingsRoot: root }

    Rectangle { width: parent.width; height: 1; color: Theme.withAlpha(Theme.outlineStrong, 0.35) }
    StyledText { width: parent.width; text: "Bar indicator"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold; color: Theme.surfaceText }

    SelectionSetting {
        settingKey: "barDisplayMode"
        label: "Content"
        description: "Choose the information shown in the bar."
        options: [
            { label: "Alerts across servers", value: "alerts" },
            { label: "CPU and RAM", value: "cpu_ram" },
            { label: "CPU", value: "cpu" },
            { label: "Memory", value: "memory" },
            { label: "Root disk", value: "disk" },
            { label: "Connection status", value: "status" },
            { label: "Server name", value: "hostname" }
        ]
        defaultValue: "alerts"
    }
    SelectionSetting {
        settingKey: "barAccent"
        label: "Indicator color"
        description: "Uses colors from the current Dux Shell theme."
        options: [
            { label: "Primary", value: "primary" },
            { label: "Secondary", value: "secondary" },
            { label: "Neutral", value: "neutral" }
        ]
        defaultValue: "primary"
    }
    ToggleSetting { settingKey: "barShowIcon"; label: "Show icon"; description: "Display the server icon beside the bar text."; defaultValue: true }
    ToggleSetting { settingKey: "barCompact"; label: "Compact text"; description: "Use shorter labels in the bar indicator."; defaultValue: false }

    Rectangle { width: parent.width; height: 1; color: Theme.withAlpha(Theme.outlineStrong, 0.35) }
    StyledText { width: parent.width; text: "Panel"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold; color: Theme.surfaceText }
    SelectionSetting {
        settingKey: "panelDefaultPage"
        label: "Initial page"
        description: "Page shown when the panel opens."
        options: [
            { label: "Overview", value: "overview" },
            { label: "Storage", value: "storage" },
            { label: "Network", value: "network" },
            { label: "Containers", value: "containers" },
            { label: "Alerts", value: "alerts" }
        ]
        defaultValue: "overview"
    }
    ToggleSetting { settingKey: "showSystemInfo"; label: "System information"; description: "Show host details on the overview page."; defaultValue: true }
    ToggleSetting { settingKey: "showCpuTemperature"; label: "CPU temperature"; description: "Show temperature when the server reports it."; defaultValue: true }
    ToggleSetting {
        settingKey: "enableGraphs"
        label: "History graphs"
        description: "Draw CPU, network and container trends in the panel."
        defaultValue: true
    }

    Rectangle { width: parent.width; height: 1; color: Theme.withAlpha(Theme.outlineStrong, 0.35) }
    StyledText { width: parent.width; text: "Desktop widget"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold; color: Theme.surfaceText }
    SelectionSetting {
        settingKey: "desktopLayout"
        label: "Layout"
        description: "Choose a circular CPU indicator or aligned metric bars."
        options: [
            { label: "CPU gauge", value: "gauge" },
            { label: "Metric bars", value: "bars" }
        ]
        defaultValue: "gauge"
    }
    ToggleSetting { settingKey: "desktopShowTemperature"; label: "CPU temperature"; description: "Display the value when the server reports it."; defaultValue: true }
    ToggleSetting { settingKey: "desktopShowDisk"; label: "Root disk"; description: "Include root filesystem usage."; defaultValue: true }
    ToggleSetting { settingKey: "desktopShowStatus"; label: "Connection status"; description: "Show a connection label in the header."; defaultValue: true }

    Rectangle { width: parent.width; height: 1; color: Theme.withAlpha(Theme.outlineStrong, 0.35) }
    StyledText { width: parent.width; text: "Refresh cadence"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold; color: Theme.surfaceText }
    StyledText { width: parent.width; text: "Short intervals feel more responsive but increase network traffic."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap }

    SliderSetting {
        settingKey: "fastRefreshInterval"
        label: "Resource usage"
        description: "CPU, memory and root disk in the open panel, CPU/RAM bar mode and desktop widget."
        defaultValue: 2
        minimum: 1
        maximum: 10
        unit: "s"
    }
    SliderSetting {
        settingKey: "slowRefreshInterval"
        label: "Inventory and server alerts"
        description: "Host details, mounts, interfaces, containers and cross-server alerts."
        defaultValue: 20
        minimum: 10
        maximum: 60
        unit: "s"
    }
    SliderSetting {
        settingKey: "detailRefreshInterval"
        label: "Selected detail"
        description: "Traffic for the selected interface or CPU for an expanded container."
        defaultValue: 2
        minimum: 1
        maximum: 10
        unit: "s"
    }
}
