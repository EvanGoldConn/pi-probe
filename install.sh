#!/bin/bash
# Installs pi-probe on a fresh Kali Linux ARM64 Raspberry Pi 4.
# Reads config/pi-probe.conf and substitutes values into all configs.
# Run from the repo root as: sudo ./install.sh

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$REPO_DIR/config/pi-probe.conf"

if [ ! -f "$CONFIG" ]; then
    echo "[pi-probe] ERROR: config/pi-probe.conf not found"
    exit 1
fi

# Load config
source "$CONFIG"

echo "[pi-probe] Configuration:"
echo "  HOTSPOT_SSID:      $HOTSPOT_SSID"
echo "  HOTSPOT_IP:        $HOTSPOT_IP"
echo "  HOTSPOT_DHCP:      $HOTSPOT_DHCP_START - $HOTSPOT_DHCP_END"
echo "  HOME_GATEWAY:      $HOME_GATEWAY"
echo ""

read -p "Proceed with install? [y/N] " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "[pi-probe] Aborted."
    exit 0
fi

echo "[pi-probe] Installing dependencies..."
apt update && apt install -y hostapd dnsmasq hcxdumptool hcxtools hashcat

echo "[pi-probe] Disabling conflicting services..."
systemctl stop hostapd dnsmasq wpa_supplicant wpa_supplicant@wlan0.service 2>/dev/null
systemctl disable hostapd dnsmasq wpa_supplicant 2>/dev/null
# Critical -- generic wpa_supplicant.service conflicts with wpa_supplicant@wlan0.service
# and causes socket errors on boot if not disabled
systemctl disable wpa_supplicant.service 2>/dev/null

echo "[pi-probe] Copying and configuring scripts..."
cp "$REPO_DIR/scripts/wlan0-manager" /usr/local/bin/
cp "$REPO_DIR/scripts/wifi-connect" /usr/local/bin/
cp "$REPO_DIR/scripts/wifi-home" /usr/local/bin/
cp "$REPO_DIR/scripts/wifi-hotspot" /usr/local/bin/
chmod +x /usr/local/bin/wlan0-manager
chmod +x /usr/local/bin/wifi-connect
chmod +x /usr/local/bin/wifi-home
chmod +x /usr/local/bin/wifi-hotspot

# Substitute config values into wlan0-manager
sed -i "s|192.168.4.1|$HOTSPOT_IP|g" /usr/local/bin/wlan0-manager
sed -i "s|192.168.1.1|$HOME_GATEWAY|g" /usr/local/bin/wlan0-manager

echo "[pi-probe] Writing hostapd.conf..."
sed \
    -e "s|PLACEHOLDER_SSID|$HOTSPOT_SSID|g" \
    -e "s|PLACEHOLDER_PSK|$HOTSPOT_PSK|g" \
    "$REPO_DIR/config/hostapd.conf" > /etc/hostapd/hostapd.conf

echo "[pi-probe] Writing dnsmasq.conf..."
sed \
    -e "s|PLACEHOLDER_DHCP_START|$HOTSPOT_DHCP_START|g" \
    -e "s|PLACEHOLDER_DHCP_END|$HOTSPOT_DHCP_END|g" \
    -e "s|PLACEHOLDER_HOTSPOT_IP|$HOTSPOT_IP|g" \
    "$REPO_DIR/config/dnsmasq.conf" > /etc/dnsmasq.conf

echo "[pi-probe] Installing systemd service..."
cp "$REPO_DIR/systemd/wlan0-manager.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable wlan0-manager.service

echo "[pi-probe] Setting up networkd..."
cat > /etc/systemd/network/10-eth0.network << 'NETEOF'
[Match]
Name=eth0

[Network]
DHCP=yes
NETEOF

cat > /etc/systemd/network/10-wlan0.network << 'NETEOF'
[Match]
Name=wlan0

[Network]
DHCP=yes

[DHCP]
RouteMetric=1024
NETEOF

systemctl restart systemd-networkd

echo ""
echo "[pi-probe] Install complete."
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. Create /etc/wpa_supplicant/wpa_supplicant-wlan0.conf with your home network credentials:"
echo ""
echo "   sudo tee /etc/wpa_supplicant/wpa_supplicant-wlan0.conf << 'WPAEOF'"
echo "   country=US"
echo "   ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev"
echo "   update_config=1"
echo "   "
echo "   network={"
echo "       ssid=\"YourNetworkName\""
echo "       psk=\"YourNetworkPassword\""
echo "       key_mgmt=WPA-PSK"
echo "   }"
echo "   WPAEOF"
echo ""
echo "   Note: country=US sets the regulatory domain."
echo "   Change to your country code if outside the US (e.g. country=GB)."
echo ""
echo "2. If your router assigns static IPs via DHCP reservation, set reservations for:"
echo "   eth0 MAC: (run 'ip link show eth0' to find it)"
echo "   wlan0 MAC: (run 'ip link show wlan0' to find it)"
echo "   This ensures consistent SSH access after reboot."
echo ""
echo "3. sudo reboot"
echo ""
echo "On boot: tries home WiFi, falls back to $HOTSPOT_SSID hotspot (PSK: $HOTSPOT_PSK)"
echo "SSH via WiFi: ssh kali@<dhcp-assigned-ip>"
echo "SSH via hotspot: ssh kali@$HOTSPOT_IP"
