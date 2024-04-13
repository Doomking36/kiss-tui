#!/bin/bash

# Loop control variable
keep_running=true

# Function to create partitions
partition_drive() {
    cfdisk
}

# Function to check if the system is UEFI or BIOS
check_uefi_or_bios() {
    if [ -d "/sys/firmware/efi/" ]; then
        dialog --msgbox "The system is UEFI." 6 25
    else
        dialog --msgbox "The system is BIOS." 6 25
    fi
}

# Function to get hostname
get_hostname() {
    exec 3>&1;
    HOSTNAME=$(dialog --inputbox "Enter your desired hostname:" 10 50 2>&1 1>&3);
    exec 3>&-;
    dialog --msgbox "Hostname set to $HOSTNAME" 6 40
}

# Function to set root password
set_root_password() {
    exec 3>&1;
    ROOT_PASSWORD=$(dialog --insecure --passwordbox "Enter root password:" 10 50 2>&1 1>&3);
    exec 3>&-;
    dialog --msgbox "Root password set" 6 25
}

# Function to add a user
add_user() {
    exec 3>&1;
    USERNAME=$(dialog --inputbox "Enter new username:" 10 50 2>&1 1>&3);
    exec 3>&-;
    USER_PASSWORD=$(dialog --insecure --passwordbox "Enter password for $USERNAME:" 10 50 2>&1 1>&3);
    exec 3>&-;
    sudo useradd -m $USERNAME
    echo "$USERNAME:$USER_PASSWORD" | sudo chpasswd
    dialog --msgbox "User $USERNAME added" 6 30
}

# Function to clone specific repositories with user-specified destination
repo_input() {
    exec 3>&1;
    DESTINATION=$(dialog --inputbox "Enter the directory where you want to clone the repositories:" 10 60 2>&1 1>&3);
    exec 3>&-;

    if [[ -z "$DESTINATION" ]]; then
        dialog --msgbox "No destination entered. Exiting the repository cloning process." 6 50
        return
    fi

    mkdir -p "$DESTINATION"

    git clone https://github.com/kiss-community/repo "$DESTINATION/repo"
    git clone https://github.com/kiss-community/community "$DESTINATION/community"
    dialog --msgbox "Repositories cloned successfully:\n- $DESTINATION/repo\n- $DESTINATION/community" 10 50
}

# Non-Chroot Menu
non_chroot_menu() {
    exec 3>&1;
    SELECTION=$(dialog --menu "Non-Chroot Menu: Choose an option:" 20 60 2 \
    1 "Partition Disk" \
    2 "Check if UEFI or BIOS" \
    2>&1 1>&3);
    exec 3>&-;

    case $SELECTION in
        1) partition_drive ;;
        2) check_uefi_or_bios ;;
        *) dialog --msgbox "Returning to main menu." 6 25; return ;;
    esac
}

# Chroot Menu
chroot_menu() {
    exec 3>&1;
    SELECTION=$(dialog --menu "Chroot Menu: Choose an option:" 20 60 4 \
    1 "Set Hostname" \
    2 "Set Root Password" \
    3 "Add User" \
    4 "Clone Repositories" \
    2>&1 1>&3);
    exec 3>&-;
    
    case $SELECTION in
        1) get_hostname ;;
        2) set_root_password ;;
        3) add_user ;;
        4) repo_input ;;
        *) dialog --msgbox "Returning to main menu." 6 25; return ;;
    esac
}

# Initial Environment Selection Menu
initial_menu() {
    exec 3>&1;
    SELECTION=$(dialog --menu "Choose your environment:" 10 50 2 \
    1 "Non-Chroot" \
    2 "Chroot" \
    2>&1 1>&3);
    exec 3>&-;

    case $SELECTION in
        1) non_chroot_menu ;;
        2) chroot_menu ;;
        *) dialog --msgbox "Exiting script." 6 25; keep_running=false ;;
    esac
}

# Loop the menu until the user exits
while $keep_running; do
    initial_menu
done
