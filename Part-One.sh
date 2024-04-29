#!/bin/bash

# Function to create a partition
create_partition() {
    # Launch disk partitioning tool
    cfdisk
}

# Function to select and format a partition
select_and_format_partition() {
    # Fetch partition details: device name, size, mount point, and format as dialog radiolist input
    partitions=$(lsblk -nlp -o NAME,SIZE,MOUNTPOINT,TYPE | awk '/part/ {printf "\"%s\" \"%s %s\" %s\n", $1, $1, $2, "off"}')

    # Display a radiolist dialog to allow the user to select a partition
    dialog --radiolist "Select a partition to format:" 20 70 12 ${partitions} 2> /tmp/partition_selection.txt
    selected_partition=$(cat /tmp/partition_selection.txt)
    rm -f /tmp/partition_selection.txt

    # Debugging output
    echo "Selected partition: $selected_partition"

    # Check if the user selected a partition
    if [ -z "$selected_partition" ]; then
        echo "No partition selected."
        return
    fi

    # Proceed to format the selected partition
    format_partition "$selected_partition"
}

# Function to format a partition
format_partition() {
    local PARTITION=$1

    # Debugging output
    echo "Attempting to format: $PARTITION"

    # Verify that the partition exists
    if [ ! -b "$PARTITION" ]; then
        dialog --msgbox "The specified partition does not exist: $PARTITION" 6 50
        return
    fi

    # Confirm before formatting
    dialog --yesno "Are you sure you want to format $PARTITION as ext4? This will erase all data on the partition." 7 60
    if [ $? -ne 0 ]; then
        dialog --msgbox "Formatting canceled." 6 40
        return
    fi

    # Attempt to format the partition
    if ! mkfs.ext4 -F $PARTITION; then
        dialog --msgbox "Failed to format $PARTITION." 6 50
        return
    fi
    dialog --msgbox "$PARTITION formatted as ext4." 6 40
}

# Function to mount a partition
mount_partition() {
    local PARTITION=$1
    # Prompt for the mount point
    exec 3>&1
    MOUNT_POINT=$(dialog --inputbox "Enter the mount point (e.g., /mnt or /newroot):" 10 50 2>&1 1>&3)
    exec 3>&-

    # Attempt to mount the partition
    if ! mount $PARTITION $MOUNT_POINT; then
        dialog --msgbox "Failed to mount $PARTITION on $MOUNT_POINT." 6 50
        return
    fi
    dialog --msgbox "$PARTITION mounted to $MOUNT_POINT." 6 40
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
    # Check if required commands are available
    for cmd in pacman curl tar chmod; do
        if ! command -v "$cmd" >/dev/null; then
            dialog --title "Error" --msgbox "Command $cmd is not installed. Please install it and try again." 6 50
            return
        fi
    done

    # Install necessary packages
    dialog --infobox "Installing tar, curl, and xz packages..." 3 40
    if ! pacman -Sy --noconfirm tar curl xz; then
        dialog --title "Error" --msgbox "Failed to install packages. Check your network connection or package manager settings." 6 50
        return
    fi

    # Download KISS chroot tarball
    dialog --infobox "Downloading KISS chroot tarball..." 3 40
    if ! curl --output kiss.xz --fail https://codeberg.org/kiss-community/repo/releases/download/23.04.30/kiss-chroot-23.04.30.tar.xz; then
        dialog --title "Error" --msgbox "Failed to download the KISS chroot tarball. Check your internet connection." 6 50
        return
    fi

    # Extracting the KISS chroot tarball
    dialog --infobox "Extracting the KISS chroot tarball to /mnt..." 3 50
    if ! tar xf kiss.xz -C /mnt; then
        dialog --title "Error" --msgbox "Failed to extract the tarball. Check the file integrity and destination permissions." 6 50
        return
    fi

    # Setting up Kiss
    dialog --infobox "Setting up Kiss" 3 50
    if ! chmod u+s /usr/bin/busybox-suid; then
        dialog --title "Error" --msgbox "Failed to set permissions for busybox-suid." 6 50
        return
    fi

    dialog --title "Installation Complete" --msgbox "KISS chroot environment has been successfully installed and set up on /mnt." 6 50
}

# Function to clone specific repositories with user-specified destination
repo_input() {
    # Check if git is installed
    if ! command -v git &>/dev/null; then
        dialog --msgbox "Git is not installed. Please install git and try again." 6 50
        return
    fi

    exec 3>&1
    DESTINATION=$(dialog --inputbox "Enter the directory where you want to clone the repositories:" 10 60 2>&1 1>&3)
    exec 3>&-

    if [[ -z "$DESTINATION" ]]; then
        dialog --msgbox "No destination entered. Exiting the repository cloning process." 6 50
        return
    fi

    if ! mkdir -p "$DESTINATION" 2>/dev/null; then
        dialog --msgbox "Failed to create or access the directory. Check permissions or path validity." 6 50
        return
    fi

    # Function to handle cloning and provide user feedback
    clone_repo() {
        local repo_url=$1
        local repo_path=$2
        local repo_name=$(basename "$repo_path")

        dialog --infobox "Cloning $repo_name repository to $repo_path..." 5 70
        if ! git clone "$repo_url" "$repo_path" 2>/dev/null; then
            dialog --msgbox "Failed to clone $repo_name. Check your internet connection or repository URL." 6 60
            return 1
        fi
    }

    # Perform cloning operations
    clone_repo https://github.com/kiss-community/repo "$DESTINATION/repo" &&
    clone_repo https://github.com/kiss-community/community "$DESTINATION/community" &&
    clone_repo https://github.com/ehawkvu/kiss-xorg "$DESTINATION/xorg"

    dialog --msgbox "Repositories cloned successfully:\n- $DESTINATION/repo\n- $DESTINATION/community\n- $DESTINATION/xorg" 10 50
}

# Create Profile containing path to repo for Kiss package manager
create_profile() {
    # Use dialog to get the directory from the user
    DEST=$(dialog --stdout --title "Profile Directory" --fselect "$HOME/" 14 60)
    if [ -z "$DEST" ]; then
        dialog --title "Error" --msgbox "No directory entered. Exiting." 5 40
        return
    fi

    # Ensure the directory exists
    if [ ! -d "$DEST" ]; then
        mkdir -p "$DEST"
        if [ $? -ne 0 ]; then
            dialog --title "Error" --msgbox "Failed to create directory. Exiting." 5 50
            return
        fi
    fi

    # Prompt user for the number of parallel jobs
    JOBS=$(dialog --stdout --title "Number of Jobs" --inputbox "Enter the number of parallel jobs for make (default: nproc):" 8 50 "$(nproc)")
    if [ -z "$JOBS" ]; then
        JOBS=$(nproc)  # Default to the number of processors
    fi

    # Create the profile file
    local PROFILE_FILE="$DEST/profile"
    if ! touch "$PROFILE_FILE"; then
        dialog --title "Error" --msgbox "Unable to create profile file. Check permissions." 5 60
        return
    fi

    dialog --infobox "Creating profile at $PROFILE_FILE..." 3 50
    sleep 2  # Allows the message to be visible before moving on

    # Write the environment settings to the profile file
    cat > "$PROFILE_FILE" <<EOF
# KISS Path Configuration
export KISS_PATH="${DEST%/}/repo/core"
KISS_PATH="\$KISS_PATH:${DEST%/}/xorg/extra"
KISS_PATH="\$KISS_PATH:${DEST%/}/xorg/xorg"
KISS_PATH="\$KISS_PATH:${DEST%/}/xorg/community"
KISS_PATH="\$KISS_PATH:${DEST%/}/repo/extra"
KISS_PATH="\$KISS_PATH:${DEST%/}/repo/wayland"
KISS_PATH="\$KISS_PATH:${DEST%/}/community/community"

# Build Flags
export CFLAGS="-march=x86-64 -mtune=generic -pipe -Os"
export CXXFLAGS="-march=x86-64 -mtune=generic -pipe -Os"
export MAKEFLAGS="-j$JOBS"
export SAMUFLAGS="-j$JOBS"

# Set date and time
export TZ=CDT
EOF

    # Inform the user of successful profile creation using dialog
    dialog --title "Profile Created" --msgbox "Profile created successfully at $PROFILE_FILE" 6 50
}

# Main Menu
main_menu() {
    keep_running=true
    while $keep_running; do
        exec 3>&1;
        SELECTION=$(dialog --cancel-label "Exit" --clear --title "Main Menu" --menu "Choose an option:" 20 60 8 \
            1 "Check if UEFI or BIOS" \
            2 "Create Partition" \
            3 "Format and Mount Disk" \
            4 "Start Installation" \
            5 "Clone Repositories" \
            6 "Create Profile" \
            2>&1 1>&3)
        exit_status=$?
        exec 3>&-;

        if [ $exit_status -eq 1 ]; then  # User pressed 'Exit'
            dialog --msgbox "Exiting script." 5 30
            keep_running=false
            continue
        fi

        case $SELECTION in
            1) check_uefi_or_bios ;;
            2) create_partition ;;
            3) select_and_format_partition ;;
            4) start_installation ;;
            5) repo_input ;;
            6) create_profile ;;
            *) dialog --msgbox "Invalid option or cancelled. Please select a valid option." 6 30 ;;
        esac
    done
}

# Start the script by calling main menu
main_menu
