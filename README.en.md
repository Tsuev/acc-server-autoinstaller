# acc-server-autoinstaller

[Русский](README.md) | **English**

An open-source CLI utility that fully automates the installation and removal of the
**Assetto Corsa Competizione Dedicated Server** on Ubuntu.

After installation you get a ready-to-use Dedicated Server with the **ACCWeb** admin
panel — no need to run any commands manually.

## Features

- Fully automated setup: dependencies, Wine, SteamCMD, Dedicated Server, ACCWeb.
- Automatic configuration of `configuration.json` and `settings.json` (proper UTF-16LE handling).
- Mandatory Linux compatibility patch: `"ignorePrematureDisconnects": 0`.
- ACCWeb autostart via systemd (under Xvfb).
- UFW configuration (game ports + panel port).
- Safe to re-run (`install` never breaks an existing installation).
- Complete removal with a single command.

## Requirements

- Ubuntu **22.04 LTS** or **24.04 LTS**
- **x86_64 (amd64)** architecture
- **root** privileges (run with `sudo`)
- Free disk space: **≥ 15 GB** (20+ GB recommended)
- RAM: **≥ 2 GB** (4+ GB recommended)
- Internet access (for apt, SteamCMD and GitHub)
- A Steam account that owns ACC (to download the Dedicated Server)

## Supported operating systems

| OS               | Architecture | Status    |
| ---------------- | ------------ | --------- |
| Ubuntu 22.04 LTS | x86_64       | Supported |
| Ubuntu 24.04 LTS | x86_64       | Supported |

## Project structure

```
acc-server-autoinstaller/
├── install.sh          # installation entry point
├── uninstall.sh        # uninstallation entry point
├── lib/                # modules (common helpers, checks, dependencies, ...)
│   ├── common.sh
│   ├── checks.sh
│   ├── deps.sh
│   ├── user.sh
│   ├── wine.sh
│   ├── steam.sh
│   ├── accweb.sh
│   ├── config.sh
│   ├── firewall.sh
│   ├── systemd.sh
│   └── report.sh
├── templates/          # configuration templates
│   ├── config.yml.tpl
│   ├── accweb.service.tpl
│   ├── event.json
│   ├── eventRules.json
│   ├── entrylist.json
│   ├── bop.json
│   └── assistRules.json
├── README.md           # Russian documentation
├── README.en.md        # English documentation (this file)
└── LICENSE
```

## Installation

```bash
# 1. Clone the repository
git clone https://github.com/Tsuev/acc-server-autoinstaller.git
cd acc-server-autoinstaller

# 2. Run the installer
sudo ./install.sh
```

The installer will prompt you for:

- server name (default `ACC Dedicated Server`);
- game TCP port (default `9600`);
- game UDP port (default `9600`);
- ACCWeb panel port (default `8080`);
- ACCWeb administrator password;
- Steam Login / Steam Password / Steam Guard (if enabled).

All parameters can be provided in advance via environment variables (handy for
automation):

```bash
sudo \
  SERVER_NAME="My Server" \
  TCP_PORT=9600 \
  UDP_PORT=9600 \
  WEB_PORT=8080 \
  ADMIN_PASSWORD="secret" \
  STEAM_USER="username" \
  STEAM_PASS="password" \
  ./install.sh
```

> The Steam Guard code is one-time and short-lived, so it is requested right
> before the server download.

### What the installer does

1. Checks the OS, architecture, free disk space, RAM and root privileges.
2. Installs dependencies: Wine, SteamCMD, Xvfb, winbind, unzip, curl, wget, jq, ufw, iconv.
3. Creates the `acc` user (if it does not exist).
4. Creates and initializes the Wine prefix.
5. Performs Steam authorization and downloads the ACC Dedicated Server (Steam app id `1430110`).
6. Downloads the latest stable ACCWeb release from GitHub Releases.
7. Generates ACCWeb's `config.yml` with the path to the Dedicated Server.
8. Creates the Dedicated Server configuration (`configuration.json`, `settings.json`, etc.) in UTF-16LE.
9. Adds `"ignorePrematureDisconnects": 0` (Linux compatibility patch).
10. Validates all JSON files.
11. Opens the game ports and panel port in UFW.
12. Creates and starts the `accweb` systemd service.
13. Verifies that ACCWeb responds over HTTP and that the Dedicated Server starts.

When finished, a report is printed with the panel URL, login, password and game ports.

## Usage

After installation:

- Panel: `http://<server-IP>:8080/`
- Login: `username` (only the password is entered)
- Password: the one you set during installation

Service management:

```bash
sudo systemctl status accweb
sudo systemctl restart accweb
sudo journalctl -u accweb -f
```

## Uninstallation

```bash
sudo ./uninstall.sh
```

The uninstaller:

1. prints a warning and asks for confirmation (`yes`);
2. stops and removes the ACCWeb systemd service;
3. removes the UFW rules created by the installer;
4. removes ACCWeb, the Dedicated Server and the Wine prefix;
5. removes SteamCMD (optional — it can be kept in `/opt/steamcmd`);
6. removes the `acc` user and its home directory;
7. runs `systemctl daemon-reload`.

Re-running `uninstall.sh` is safe (it will not fail).

## FAQ

### Do I need a Steam account to install?
Yes. The Dedicated Server is downloaded through SteamCMD using your Steam account
that owns ACC. The login/password are used only once, to download the files.

### Why does the Dedicated Server run under Wine?
The official ACC Dedicated Server is distributed for Windows only. Wine allows it
to run on Linux, and Xvfb provides a virtual display.

### Which ports need to be open?
By default the game TCP `9600`, game UDP `9600` and panel port `8080`. The installer
opens them in UFW automatically. Do not forget to also forward these ports on your
cloud provider / router if the server is behind NAT.

### What is `ignorePrematureDisconnects`?
A mandatory Linux parameter `"ignorePrematureDisconnects": 0` in `settings.json`.
Without it the server misbehaves under Wine. The installer adds it automatically
and never creates duplicates.

### Can I run the installer again?
Yes. The installer is idempotent: it does not overwrite existing configurations
and correctly skips already-completed steps.

### How do I update ACCWeb or the Dedicated Server?
- ACCWeb: replace the ACCWeb directory with the new version, or reinstall.
- Dedicated Server: re-download via SteamCMD (`app_update 1430110 validate`).

## Troubleshooting

### ACCWeb does not respond over HTTP
```bash
sudo systemctl status accweb
sudo journalctl -u accweb -e
```
Make sure the panel port is free and open in UFW.

### The Dedicated Server does not start
1. Check the ACCWeb logs:
   ```bash
   sudo journalctl -u accweb -f
   ```
2. Make sure `configuration.json` and `settings.json` are valid and located in the
   instance directory (`/home/acc/accweb/config/default/`).
3. Make sure `ignorePrematureDisconnects` is present in `settings.json`.

### Steam authorization error
- Verify your Steam Login/Password.
- If Steam Guard is enabled, provide a fresh code (it is one-time and valid for a
  limited time).
- After several failed attempts Steam may temporarily block the login — wait and
  try again.

### Not enough disk space
Free up space and re-run the installer. The minimum requirement is 15 GB; 20+ GB is
recommended (ACC content with DLC takes several gigabytes).

### UFW is disabled
If UFW is not active, the installer still adds the rules, but they only take effect
after UFW is enabled:
```bash
sudo ufw enable
```
Do not forget to allow SSH first: `sudo ufw allow OpenSSH`.

## License

[MIT](./LICENSE)

## Third-party components

- [ACCWeb](https://github.com/assetto-corsa-web/accweb) — MIT
- Assetto Corsa Competizione Dedicated Server — proprietary software by Kunos Simulazioni
- SteamCMD — Valve Corporation

