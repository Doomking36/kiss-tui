#!/bin/bash

# Function to create partitions
partition_drive() {
    cfdisk
}

# Function to get hostname
get_hostname() {
    exec 3>&1;
    HOSTNAME=$(dialog --inputbox "Enter your desired hostname:" 10 50 2>&1 1>&3);
    exec 3>&-;
    echo "Hostname set to $HOSTNAME"
}

# Function to set root password
set_root_password() {
    exec 3>&1;
    ROOT_PASSWORD=$(dialog --insecure --passwordbox "Enter root password:" 10 50 2>&1 1>&3);
    exec 3>&-;
    echo "Root password set"
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
    echo "User $USERNAME added"
}

# Function to clone specific repositories with user-specified destination
repo_input() {
    exec 3>&1;
    DESTINATION=$(dialog --inputbox "Enter the directory where you want to clone the repositories:" 10 60 2>&1 1>&3);
    exec 3>&-;

    if [[ -z "$DESTINATION" ]]; then
        echo "No destination entered. Exiting the repository cloning process."
        return
    fi

    mkdir -p "$DESTINATION"

    echo "Cloning kiss-community/repo repository to $DESTINATION/repo..."
    git clone https://github.com/kiss-community/repo "$DESTINATION/repo"
    echo "Repository kiss-community/repo cloned successfully to $DESTINATION/repo."

    echo "Cloning kiss-community/community repository to $DESTINATION/community..."
    git clone https://github.com/kiss-community/community "$DESTINATION/community"
    echo "Repository kiss-community/community cloned successfully to $DESTINATION/community."
}

# Function to check if the system is UEFI or BIOS
check_uefi_or_bios() {
    if [ -d "/sys/firmware/efi/" ]; then
        echo "The system is UEFI."
    else
        echo "The system is BIOS."
    fi
}

# Main Menu using dialog
main_menu() {
    exec 3>&1;
    SELECTION=$(dialog --menu "Choose an option:" 20 60 6 \
    1 "Partition Disk" \
    2 "Set Hostname" \
    3 "Set Root Password" \
    4 "Add User" \
    5 "Clone Repositories" \
    6 "Check if UEFI or BIOS" \
    2>&1 1>&3);
    exec 3>&-;
    
    case $SELECTION in
        1) partition_drive ;;
        2) get_hostname ;;
        3) set_root_password ;;
        4) add_user ;;
        5) repo_input ;;
        6) check_uefi_or_bios ;;
        *) echo "Exiting"; break ;;
    esac
}

# Loop the menu until the user exits
while true; do
    main_menu
done
