# VMonitorSRV

[![DMS Version](https://img.shields.io/badge/DMS-%21%3D1.5.0-818cf8.svg)](https://github.com/AvengeMedia/DankMaterialShell)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

<p align="center">
  <img src="VMonitorSRV.svg" alt="VMonitorSRV Logo" width="128" height="128">
</p>

**VMonitorSRV** is a plugin for **DankMaterialShell (DMS ≥ 1.5.0)** for monitoring a remote Linux server running Glances from your desktop environment.

---

<p align="center">
  <img src="screenshot.png" alt="VMonitorSRV Preview" width="800">
</p>

## Features

The plugin provides three surface components in DMS:

* **Bar Widget (`widget`):** Indicator for the top bar (supports horizontal and vertical orientations). Displays CPU and RAM usage alongside a server status icon.
* **Control Panel (`popout`):** Popout menu triggered from the bar widget:
  * **Host Information:** Hostname, CPU model, OS version, kernel build, and uptime.
  * **System Resources:** CPU, RAM, and root filesystem usage.
  * **Btrfs Subvolumes:** Storage usage for mounted Btrfs subvolumes.
  * **Podman Containers:** Container status (active, stopped, error), image tags, and memory usage.
* **Desktop Tile (`desktop`):** Desktop widget using *wlr-layer-shell* for persistent monitoring on the desktop layer.

---

## Architecture & Communication

* **Asynchronous Polling:** Queries the server API asynchronously via QML `XMLHttpRequest`.
* **Tiered Polling:** 
  * High-frequency polling (default 1.5s) for dynamic metrics (CPU/RAM).
  * Low-frequency polling (default 15s) for static metadata (hardware info, mounts).
* **Connection Fallback:** Displays an offline state indicator if the remote server endpoint becomes unreachable.

---

## Prerequisites

1. **DankMaterialShell** version `1.5.0` or higher.
2. A remote server running **Glances** configured with:
   * 🔗 **Glances Dotfiles:** [sowtarez / dotfiles-glances](https://gitlab.com/sowtarez/dotfiles-glances)

---

## Installation & Setup

1. **Clone the plugin** into your DMS plugins directory:
   ```bash
   git clone https://github.com/JessVolet/VMonitorSRV.git ~/.config/DankMaterialShell/plugins/vMonitorSRV
   ```

2. **Enable and Reload:**
   In DMS Settings → Plugins → Scan for Plugins, enable `VMonitorSRV`, then execute:
   ```bash
   dms ipc call plugins reload vMonitorSRV
   ```

3. **Configuration:**
   Go to DMS Settings → Plugins → `VMonitorSRV` Settings to configure the server host, port, and polling intervals.
