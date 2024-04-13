#!/bin/bash

# Loop control variable
keep_running=true

# Function to create, format, and mount partitions
partition_drive() {
    cfdisk
    exec 3>&1;
    PARTITION=$(dialog --inputbox "Enter the partition to format (e.g., /dev/sda1):" 10 50 2>&1 1>&3);
    exec 3>&-;
    dialog --yesno "Are you sure you want to format $PARTITION?" 7 45
    if [ $? -eq 0 ]; then
        mkfs -t ext4 -F $PARTITION
        dialog --msgbox "$PARTITION formatted as ext4." 6 40
        mount $PARTITION /mnt
        dialog --msgbox "$PARTITION mounted to /mnt." 6 40
    else
        dialog --msgbox "Formatting canceled." 6 40
    fi
}

# Function to check if the system is UEFI or BIOS
check_uefi_or_bios() {
    if [ -d "/sys/firmware/efi/" ]; then
        dialog --msgbox "The system is UEFI." 6 25
    else
        dialog --msgbox "The system is BIOS." 6 25
    fi
}


# Function to start installation process
start_installation() {
    dialog --infobox "Installing tar, curl, and xz packages..." 3 40
    pacman -Sy --noconfirm tar curl xz
    dialog --infobox "Downloading KISS chroot tarball..." 3 40
    curl --output kiss.xz https://codeberg.org/kiss-community/repo/releases/download/23.04.30/kiss-chroot-23.04.30.tar.xz
    dialog --infobox "Extracting the KISS chroot tarball to /mnt..." 3 50
    tar xf kiss.xz -C /mnt
    dialog --infobox "Setting up Kiss"
    chmod u+s /usr/bin/busybox-suid
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

    dialog --infobox "Cloning kiss-community/repo repository to $DESTINATION/repo..." 5 70
    git clone https://github.com/kiss-community/repo "$DESTINATION/repo"
    dialog --infobox "Cloning kiss-community/community repository to $DESTINATION/community..." 5 70
    git clone https://github.com/kiss-community/community "$DESTINATION/community"
    dialog --infobox "Cloning kiss-xorg repository to $DESTINATION/xorg..." 5 70
    git clone https://github.com/ehawkvu/kiss-xorg "$DESTINATION/xorg"
    dialog --msgbox "Repositories cloned successfully:\n- $DESTINATION/repo\n- $DESTINATION/community\n- $DESTINATION/xorg" 10 50
}


# Create Profile containing path to repo for Kiss package manager
create_profile() {
    # Use dialog to get the directory from the user
    DEST=$(dialog --stdout --title "Profile Directory" --inputbox "Enter the directory where the profile should be stored:" 8 50)
    if [ -z "$DEST" ]; then
        echo "No directory entered. Exiting."
        return
    fi

    # Create the profile file
    local PROFILE_FILE="$DEST/profile"

    echo "Creating profile at $PROFILE_FILE..."

    # Write the environment settings to the profile file
    cat > "$PROFILE_FILE" <<EOF
# KISS Path Configuration
export KISS_PATH="$DEST/repo/core"
KISS_PATH="\$KISS_PATH:$DEST/xorg/extra"
KISS_PATH="\$KISS_PATH:$DEST/xorg/xorg"
KISS_PATH="\$KISS_PATH:$DEST/xorg/community"
KISS_PATH="\$KISS_PATH:$DEST/repo/extra"
KISS_PATH="\$KISS_PATH:$DEST/repo/wayland"
KISS_PATH="\$KISS_PATH:$DEST/community/community"

# Build Flags
export CFLAGS="-march=x86-64 -mtune=generic -pipe -Os"
export CXXFLAGS="-march=x86-64 -mtune=generic -pipe -Os"
export MAKEFLAGS="-j1"
export SAMUFLAGS="-j1"

# Set date and time
export TZ=CDT
EOF

    # Inform the user of successful profile creation using dialog
    dialog --title "Profile Created" --msgbox "Profile created successfully at $PROFILE_FILE" 6 50
}



# Main Menu
main_menu() {
    exec 3>&1;
    SELECTION=$(dialog --menu "Main Menu: Choose an option:" 20 60 7 \
    1 "Check if UEFI or BIOS" \
    2 "Partition, Format and Mount Disk" \
    3 "Start Installation" \
    4 "Clone Repositories" \
    5 "Create Profile" \
    2>&1 1>&3);
    exec 3>&-;

    case $SELECTION in
        1) check_uefi_or_bios ;;
        2) partition_drive ;;
        3) start_installation ;;
        4) repo_input ;;
        5) create_profile ;;
        *) dialog --msgbox "Exiting script." 6 25; keep_running=false ;;
    esac
}

# Loop the menu until the user exits
while $keep_running; do
    main_menu
done
