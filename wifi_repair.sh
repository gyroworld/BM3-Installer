#!usr/bin/bash

>/etc/wpa_supplicant/wpa_supplicant.conf

echo 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
   ssid="bootmod3"
   psk="bootmod3"
}' | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf

>/etc/network/interfaces

echo '# interfaces(5) file used by ifup(8) and ifdown(8)

# Please note that this file is written to be used with dhcpcd
# For static IP, consult /etc/dhcpcd.conf and 'man dhcpcd.conf'

# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

auto lo
iface lo inet loopback

auto eth0
iface eth0 inet manual

allow-hotplug wlan0
iface wlan0 inet manual
    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf' | sudo tee -a /etc/network/interfaces
