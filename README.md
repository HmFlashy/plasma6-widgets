# Plasma 6 Widgets Monorepo

Collection of custom KDE Plasma 6 widgets (`Plasma/Applet`).

## Applets

### 1. `me.masterh.appgroup` — Dossier d'applications
Panel app-folder widget with a live 2×2 or 3×3 mini-icon preview directly in the taskbar:
- Hover animations on both the panel icon and the mini-icons inside
- Drag-and-drop apps (`.desktop`, Kickoff `applications:...`), folders, and web URLs
- Pin button to keep the popup open while launching multiple apps
- Right-click context menu & drag-to-reorder inside the popup
- Configurable columns, icon size, preview grid (`2×2` / `3×3`), and custom popup dimensions

### 2. `me.masterh.gpu3050` — RTX 3050 Monitor
Lightweight panel/desktop monitor showing GPU utilization (%) and temperature (°C) only when the NVIDIA dGPU is active (`D0`), avoiding unnecessary wakeups while suspended (`D3cold`).

## Installation

```bash
./scripts/install.sh          # install/upgrade all widgets
./scripts/install.sh me.masterh.appgroup
```

## Packaging for KDE Store

```bash
./scripts/package.sh
```

Generates `.plasmoid` archives in `dist/` ready to upload to [store.kde.org](https://store.kde.org) under **Plasma 6 Applets**.
