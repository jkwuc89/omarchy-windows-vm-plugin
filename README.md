# Windows VM (Omarchy bar widget)

An [Omarchy](https://omarchy.org/) shell plugin that puts the Docker-based
Windows VM (managed by the packaged `omarchy-windows-vm` command) on the bar,
matching the look and feel of the built-in Bluetooth/Power/Network widgets:
an icon that reflects live status, and a click-to-open panel with a
Start/Stop button.

It never touches Docker or the VM's compose file for writes directly — only
a read-only `docker inspect` for status, and the already-hardened, packaged
`omarchy-windows-vm launch --keep-alive` / `omarchy-windows-vm stop` commands
for actions. All privilege handling (sudoless Docker vs. `pkexec`) stays in
that command.

## Install

```bash
omarchy plugin add ~/projects/personal/omarchy-windows-vm-plugin --enable
```

## Update

After pulling or editing this repo's files and committing:

```bash
omarchy plugin update jkwuc89.windows-vm
```

## Dependencies

- **Docker** — running container daemon
- **omarchy-windows-vm** — packaged VM management command
- **Wayland/uwsm** — for RDP session context

## License

This plugin is licensed under the MIT License. See `LICENSE` file for details.

## Files

- `manifest.json` — plugin declaration (id `jkwuc89.windows-vm`).
- `Service.qml` — polling and start/stop process logic.
- `Panel.qml` — bar icon + popup panel UI.
- `Model.js` — pure state-classification/label helpers.
