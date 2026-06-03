# pi-probe

A Raspberry Pi 4 setup for wireless network operations. On boot, the Pi attempts to connect to a configured home network. If that fails, it automatically broadcasts a local WiFi hotspot instead.

## Hardware

- Raspberry Pi 4 Model B
- Alfa AWUS036ACM adapter (wlan1, used for monitor mode)

## OS

Kali Linux ARM64, tested on kali-linux-2026.1-raspberry-pi-arm64

Download from: https://www.kali.org/get-kali/#kali-arm

Flash to a microSD card using Balena Etcher or Raspberry Pi Imager.
Default credentials are kali/kali. Change the password immediately after first boot.

## Network Interfaces

- eth0: ethernet, managed by systemd-networkd
- wlan0: managed entirely by wlan0-manager, not networkd
- wlan1: Alfa AWUS036ACM, reserved for monitor mode operations

## How wlan0 Works

On every boot and any time connectivity is lost:
1. Attempts to connect to home WiFi via wpa_supplicant
2. If that fails, starts broadcasting the hotspot

A watchdog loop checks connectivity every 30 seconds and recovers automatically.

## Scripts

    wlan0-manager        Runs as a systemd service on boot. Owns wlan0 entirely.
    wifi-connect         Connects wlan0 to any network. Usage: sudo wifi-connect "SSID" "PSK"
    wifi-home            Hands control back to wlan0-manager
    wifi-hotspot         Forces hotspot mode immediately

## Installation

Prerequisites: fresh Kali Linux ARM64 install, SSH enabled, ethernet connected for initial setup.

Update the system first:

    sudo apt update && sudo apt upgrade -y

Clone the repo:

    git clone https://github.com/YourUsername/pi-probe.git
    cd pi-probe

Edit the config file before running the installer:

    nano config/pi-probe.conf

Run the installer:

    sudo ./install.sh

After the installer finishes, create the wpa_supplicant config for your home network:

    sudo tee /etc/wpa_supplicant/wpa_supplicant-wlan0.conf << EOF
    country=US
    ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
    update_config=1

    network={
        ssid="YourNetworkName"
        psk="YourNetworkPassword"
        key_mgmt=WPA-PSK
    }
    EOF

Change country=US to your country code if outside the US. This file is gitignored and should never be committed.

For consistent SSH access, set DHCP reservations in your router for the Pi's MAC addresses:

    ip link show eth0
    ip link show wlan0

Then reboot:

    sudo reboot

## SSH Access

When connected to home network, SSH to the DHCP-assigned IP (check your router).
When ethernet is plugged in, SSH to the ethernet DHCP-assigned IP.
When in hotspot mode, SSH to 192.168.4.1 by default.

## Hotspot Defaults

    SSID: PiRecon
    PSK:  recon1234
    IP:   192.168.4.1

These can be changed in config/pi-probe.conf before running the installer.

## config/pi-probe.conf

    HOTSPOT_SSID        SSID to broadcast in hotspot mode
    HOTSPOT_PSK         Hotspot password
    HOTSPOT_IP          Gateway IP in hotspot mode
    HOTSPOT_DHCP_START  Start of DHCP range in hotspot mode
    HOTSPOT_DHCP_END    End of DHCP range in hotspot mode
    HOME_GATEWAY        Your home router IP, used for connectivity checks

## Notes

wpa_supplicant-wlan0.conf is not included in this repo. Never commit it.

/tmp/wlan0-manual is a state file written when wifi-connect is used manually. It tells the watchdog not to interfere with an active connection. The file is cleared on reboot.

wlan1 monitor mode works independently of wlan0 and is unaffected by any wlan0 state changes.

The generic wpa_supplicant.service is disabled by the installer. This is intentional. If left enabled, it conflicts with wpa_supplicant@wlan0.service at boot and causes wlan0-manager to fail silently.
