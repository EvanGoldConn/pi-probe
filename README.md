# pi-probe

Raspberry Pi 4 setup for wireless network operations. On boot, the Pi immediately broadcasts a local WiFi hotspot (`PiRecon`). Once SSHed in, use `wifi-connect` to join any local network. If that connection drops, the Pi automatically returns to hotspot mode.

---

## Hardware

- Raspberry Pi 4 Model B
- Alfa AWUS036ACM adapter (wlan1 — monitor mode only)

## OS

Kali Linux ARM64 — tested on `kali-linux-2026.1-raspberry-pi-arm64`

Download: https://www.kali.org/get-kali/#kali-arm

Flash to microSD with Balena Etcher or Raspberry Pi Imager. Default credentials: `kali/kali` — change immediately after first boot.

---

## Network Interfaces

- `eth0` — ethernet, managed by systemd-networkd
- `wlan0` — managed entirely by wlan0-manager, not networkd
- `wlan1` — Alfa AWUS036ACM, reserved for monitor mode, never touched by wlan0-manager

---

## Boot Behavior

On every boot:
1. wlan0-manager starts, waits 10s for system init
2. Broadcasts `PiRecon` hotspot immediately — no exceptions
3. Watchdog runs every 30s — if wifi-connect session drops, returns to hotspot automatically

Credentials are never saved. wifi-connect is session only — reboot always returns to hotspot.

---

## SSH Access

| Scenario | Command |
|----------|---------|
| Connected to PiRecon hotspot | `ssh kali@192.168.4.1` |
| Ethernet plugged in | `ssh kali@192.168.1.95` (or reserved IP) |
| Any network (mDNS) | `ssh kali@kali-raspberrypi.local` |

Key-based auth is configured — no password needed if your public key is in `~/.ssh/authorized_keys` on the Pi.

---

## Hotspot Defaults

```
SSID:     PiRecon
Password: recon1234
IP:       192.168.4.1
```

Configurable in `config/pi-probe.conf` before running the installer.

---

## Typical Field Workflow

**Step 1 — Connect to Pi hotspot**
On your Mac, join `PiRecon` (password: `recon1234`).

**Step 2 — SSH in**
```bash
ssh kali@192.168.4.1
```

**Step 3 — Sync time if needed**
If clock warning appears on login, run from a separate Mac terminal:
```bash
pi-sync-time
```
Add to `~/.zshrc` on Mac:
```bash
pi-sync-time() {
    ssh -i ~/.ssh/id_ed25519_github_old kali@192.168.4.1 "sudo date -s '$(date -u "+%Y-%m-%d %H:%M:%S")'"
}
```

**Step 4 — Join a local network**
```bash
sudo wifi-connect "NetworkSSID" "Password"
```
Pi associates, gets a DHCP IP, prints it on success.

**Step 5 — Switch Mac to same network, SSH via mDNS**
```bash
ssh kali@kali-raspberrypi.local
```

**Step 6 — Return to hotspot when done**
```bash
sudo wifi-hotspot
```

---

## Scripts

```
wlan0-manager    Systemd service. Owns wlan0. Starts hotspot on boot. Watchdog fallback.
wifi-connect     Join any network for current session. Usage: sudo wifi-connect "SSID" "PSK"
wifi-hotspot     Force hotspot mode immediately.
fix-time         Set clock manually. Usage: sudo fix-time "YYYY-MM-DD HH:MM:SS"
```

---

## Time Sync

On boot with ethernet/internet: `force-timesync.service` syncs via NTP automatically.

On boot in hotspot-only mode: clock warning appears on SSH login. Run `pi-sync-time` from Mac to sync.

---

## Installation

Prerequisites: fresh Kali Linux ARM64, SSH enabled, ethernet connected.

```bash
sudo apt update && sudo apt upgrade -y
git clone https://github.com/EvanGoldConn/pi-probe.git
cd pi-probe
nano config/pi-probe.conf
sudo ./install.sh
```

After install, set DHCP reservations in your router for consistent SSH IPs:
```bash
ip link show eth0    # get eth0 MAC
ip link show wlan0   # get wlan0 MAC
```

Then reboot:
```bash
sudo reboot
```

---

## config/pi-probe.conf

```
HOTSPOT_SSID        SSID to broadcast in hotspot mode
HOTSPOT_PSK         Hotspot password
HOTSPOT_IP          Gateway IP in hotspot mode (default: 192.168.4.1)
HOTSPOT_DHCP_START  Start of DHCP range
HOTSPOT_DHCP_END    End of DHCP range
HOME_GATEWAY        Home router IP
```

---

## Notes

- `wpa_supplicant-wlan0.conf` is not in this repo — never commit it
- `/tmp/wlan0-manual` is written by wifi-connect to signal wlan0-manager not to interfere — cleared on reboot
- `wpa_supplicant.service` (generic) is masked by the installer — intentional, conflicts with wlan0-manager
- `systemd-networkd` does not manage wlan0 — intentional, conflicts with hostapd
- `wlan1` monitor mode is fully independent of wlan0 state
- `avahi-daemon` runs on boot — enables `kali-raspberrypi.local` hostname resolution on any network
