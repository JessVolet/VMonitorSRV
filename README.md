# VMonitorSRV

VMonitorSRV is a Dux Shell (DMS 2.0+) plugin for a remote Glances-based HTTP API. It provides a bar pill with a popout and a desktop widget. The server API is separate from this repository.

## Features

- Bar indicator: alerts, CPU and RAM, one resource, connection status, or server name. Its icon, text density and theme color are configurable.
- Popout: host information, resources, main mounts and Btrfs subvolumes, network interfaces, containers, and alerts.
- Desktop widget: CPU, RAM, and optional root disk and temperature from the first configured server. Choose a circular CPU indicator or metric bars.
- On-demand polling: detailed metrics run while the popout is visible. The bar checks alert counts at the configured slow interval; CPU/RAM mode also polls fast metrics.

## Requirements

- Dux Shell 2.0 or later.
- A reachable server implementing the `/api/widget` HTTP endpoints used by this plugin. The referenced [Glances server configuration](https://gitlab.com/sowtarez/dotfiles-glances) is a server-side requirement, not a client-side dependency.
- No client-side Python or Glances installation is required. The client uses Dux Shell and Quickshell's HTTP support.

The plugin sends read-only HTTP GET requests. Use `https://` or a trusted private network when appropriate. The current server API does not expose container restart or stop actions.

## Install and configure

```bash
git clone https://github.com/JessVolet/VMonitorSRV.git ~/.config/dms/plugins/vMonitorSRV
```

In **DMS Settings → Plugins**, scan for plugins and enable **VMonitorSRV**. Add its bar widget or desktop widget where you want it. After changes to the source, reload it with:

```bash
dms ipc call plugins reload vMonitorSRV
```

Open **VMonitorSRV Settings** and add HTTP(S) server origins individually, for example:

```text
http://server.local:61208
```

The port defaults to `61208` if omitted. Enter only the origin, without `/api/widget`; the plugin adds that path. Add more servers and reorder them in Settings. The first valid URL drives the desktop widget. The bar popout can select another server. Empty or invalid entries are ignored, and an empty list makes no network requests.

The plugin reads each server's hostname from `/api/widget/information`. A **name** field beside each address lets you override a generic or incorrect hostname. This name takes priority in the bar, server selector, alert list and desktop widget. Settings also offers display choices for the bar, panel and desktop widget, plus refresh intervals.

### Upgrading from the old `hosts.json` setup

The old plugin read `hosts.json` from its installed directory. Copy each host into the new **Server URLs** setting before updating, using `http://HOST:PORT`. The plugin no longer reads `hosts.json`, so updates cannot overwrite your host list. The settings are stored by DMS in its plugin settings store.

## API endpoints

The selected server is expected to expose `GET /api/widget/resources`, `/information`, `/storage/main`, `/storage/subvolumes`, `/network`, `/network/virtual`, `/containers/count`, `/containers`, and `/alerts`. The plugin also reads `/network/{id}`, `/network/virtual/{id}`, and `/containers/cpu/{id}` when their respective detail views are open. These routes match the [current Glances server implementation](https://gitlab.com/sowtarez/dotfiles-glances).

## Development

DMS 2.0 uses `PluginComponent` for the bar and `DesktopPluginComponent` for desktop placements. Its [plugin development guide](https://duxlabs.dev/docs/dms/plugin-development) describes the component lifecycle, settings, and development reload. This repository ships no startup check because it has no local program dependency to gate activation.
