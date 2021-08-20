#!/usr/bin/bash

user=$(who am i | awk '{print $1}')

function update_system_and_install_packages() {
    echo $(tput setaf 3)Updating system...$(tput sgr0)
    apt-get update
    apt-get dist-upgrade -y
    echo $(tput setaf 2)System updated.$(tput sgr0)
    echo $(tput setaf 3)Installing additional packages...$(tput sgr0)
    apt-get install openjdk-8-jdk openjdk-8-jre gvfs ipheth-utils libimobiledevice-utils gvfs-backends gvfs-bin gvfs-fuse ifuse -y
    echo $(tput setaf 2)Additional pacakges installed.$(tput sgr0)
    echo $(tput setaf 3)Removing unnecessary packages...$(tput sgr0)
    apt-get autoremove -y
    apt-get autoclean
    echo $(tput setaf 2)Unnecessary packages removed.$(tput sgr0)
}

function install_cron_job() {
    local check=$(crontab -u $user -l 2>/dev/null | grep -c "@reboot java -jar agentrunner.jar > bm3_cron.log 2>&1")
    if [ $check == 0 ]; then
        echo $(tput setaf 3)Adding cron job...$(tput sgr0)
        (
            crontab -u $user -l 2>/dev/null
            echo "@reboot java -jar agentrunner.jar > bm3_cron.log 2>&1"
        ) | crontab -u $user -
    else
        echo "Cron job already exists."
    fi
}

function install_bm3_agent() {
    echo $(tput setaf 3)Installing bootmod3 agent...$(tput sgr0)
    wget -q --show-progress -O agent.jar https://www.dropbox.com/s/8x8flqek9zmegz0/agent.jar
    wget -q --show-progress -O agentapp.jar https://www.dropbox.com/s/hmkau53s5wkefvu/agentapp.jar
    wget -q --show-progress -O agentrunner.jar https://www.dropbox.com/s/br7wnlnjccojwy6/agentrunner.jar
    install_cron_job
    echo $(tput setaf 2)Done.$(tput sgr0)
}

function get_country_code() {
    echo $(tput setaf 3)Attempting to get country code...$(tput sgr0)
    ubuntu_location=$(wget -O - -q http://geoip.ubuntu.com/lookup)
    status=$(echo $ubuntu_location | sed -n -e 's/.*<Status>\(.*\)<\/Status>.*/\1/ p')
    country_code=$(echo $ubuntu_location | sed -n -e 's/.*<CountryCode>\(.*\)<\/CountryCode>.*/\1/ p')
    if [[ $status == "OK" && $country_code != "" ]]; then
        echo "Success! Setting country code to $country_code."
    else
        echo "Could not determine country. Setting value to US."
        country_code='US'
    fi
}

function set_timezone() {
    echo $(tput setaf 3)Determining timezone...$(tput sgr0)
    timezone=$(echo $ubuntu_location | sed -n -e 's/.*<TimeZone>\(.*\)<\/TimeZone>.*/\1/ p')
    continent=${timezone%%'/'*}
    city=${timezone#$continent'/'*}
    if [[ $continent != "" && $city != "" ]]; then
        echo $(tput setaf 2)Setting timezone to $timezone$(tput sgr0)
        ln -fs /usr/share/zoneinfo/$continent/$city /etc/localtime
        dpkg-reconfigure -f noninteractive tzdata
    else
        echo "Could not determine timezone. Skipping."
    fi
}

function set_wifi() {
    echo $(tput setaf 3)Adding "bootmod3" WiFi network...$(tput sgr0)
    get_country_code
    >/etc/wpa_supplicant/wpa_supplicant.conf
    cat <<EOF >/etc/wpa_supplicant/wpa_supplicant.conf
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=$country_code

network={
   ssid="bootmod3"
   psk="bootmod3"
}
EOF
}

function enable_ssh() {
    echo $(tput setaf 3)Enabling SSH...$(tput sgr0)
    sudo systemctl enable ssh
    sudo systemctl start ssh
    echo $(tput setaf 2)Done.$(tput sgr0)
}

function update_agent() {
    echo $(tput setaf 3)Updating agent...$(tput sgr0)
    curl -X POST http://localhost:8181/downloadandupdate
    echo ""
}

function installation_verification() {
    echo $(tput setaf 3)Verifying installation...$(tput sgr0)

    if [[ -f agent.jar ]]; then
        echo $(tput setaf 2)VERIFIED: agent.jar$(tput sgr0)
    else
        echo $(tput setaf 1)ERROR: agent.jar$(tput sgr0)

    fi

    if [[ -f agentapp.jar ]]; then
        echo $(tput setaf 2)VERIFIED: agentapp.jar$(tput sgr0)
    else
        echo $(tput setaf 1)ERROR: agentapp.jar$(tput sgr0)
    fi

    if [[ -f agentapp.jar ]]; then
        echo $(tput setaf 2)VERIFIED: agentrunner.jar$(tput sgr0)
    else
        echo $(tput setaf 1)ERROR: agentrunner.jar$(tput sgr0)
    fi

    cron_job_verification=$(crontab -u $user -l 2>/dev/null | grep -c "@reboot java -jar agentrunner.jar > bm3_cron.log 2>&1")

    if [[ $cron_job_verification == 0 ]]; then
        echo $(tput setaf 1)ERROR: Cron job$(tput sgr0)
    elif [[ $cron_job_verification == 1 ]]; then
        echo $(tput setaf 2)VERIFIED: Cron job$(tput sgr0)
    else
        echo $(tput setaf 3)WARNING: Cron job$(tput sgr0)
    fi

    wifi_verification=$(grep -c "bootmod3" /etc/wpa_supplicant/wpa_supplicant.conf)

    if (($wifi_verification > 1)); then
        echo $(tput setaf 2)VERIFIED: "bootmod3" WiFi network$(tput sgr0)
    else
        echo $(tput setaf 1)ERROR: "bootmod3" WiFi network$(tput sgr0)
    fi

}

function full_install() {
    update_system_and_install_packages
    install_bm3_agent
    java -jar agentrunner.jar >bm3_cron.log 2>&1 &
    set_wifi
    set_timezone
    enable_ssh
    update_agent
    installation_verification
    echo $(tput bold)Installation complete.$(tput sgr0)
    read -p "Reboot now? (y/n) " yn
    case $yn in
    [Yy]*) sudo reboot ;;
    [Nn]*) exit ;;
    *) echo "Please answer yes or no." ;;
    esac
}

function repair_install() {
    kill $(ps aux | grep '[j]ava' | awk '{print $2}') >/dev/null 2>&1
    rm -f /home/pi/* 2>/dev/null
    rm -r -f /home/pi/* 2>/dev/null
    update_system_and_install_packages
    install_bm3_agent
    java -jar agentrunner.jar >bm3_cron.log 2>&1 &
    set_wifi
    set_timezone
    enable_ssh
    update_agent
    installation_verification
    echo $(tput bold)Repair complete.$(tput sgr0)
    read -p "Reboot now? (y/n) " yn
    case $yn in
    [Yy]*) sudo reboot ;;
    [Nn]*) exit ;;
    *) echo "Please answer yes or no." ;;
    esac
}

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or type 'sudo bash bm3_installer_v1.1.sh'"
    exit
fi

#Terminal Main Menu
function main_menu() {
    clear
    echo "~~~~~~~~~~~~~~~~~~~~~~"
    echo " BM3 - INSTALLER v1.1 "
    echo "~~~~~~~~~~~~~~~~~~~~~~"
    echo "Choose option:"
    echo "  1. Install bootmod3"
    echo "  2. Repair installation"
    echo "  3. Advanced menu"
    echo "  4. Exit"

    read -p "Enter option: " option
    case $option in
    1) full_install ;;
    2) repair_install ;;
    3) advanced_menu ;;
    4) exit 1 ;;
    *) echo "Invalid option" ;;
    esac
}

#Advanced terminal menu
function advanced_menu() {
    echo "~~~~~~~~~~~~~~~~~~~~~"
    echo "    ADVANCED MENU    "
    echo "~~~~~~~~~~~~~~~~~~~~~"
    echo "  1. update_system_and_install_packages()"
    echo "  2. install_bm3_agent()"
    echo "  3. set_wifi()"
    echo "  4. enable_ssh()"
    echo "  5. repair_install()"
    echo "  6. full_install()"
    echo "  7. update_agent()"
    echo "  8. installation_verification()"
    echo "  9. Return to main menu"
    echo "  0. Exit"

    read -p "Enter option: " option
    case $option in
    1) update_system_and_install_packages ;;
    2) install_bm3_agent ;;
    3) set_wifi ;;
    4) enable_ssh ;;
    5) repair_install ;;
    6) full_install ;;
    7) update_agent ;;
    8) installation_verification ;;
    9) main_menu ;;
    0) exit 1 ;;
    *) echo "Invalid option" ;;
    esac
}

main_menu
