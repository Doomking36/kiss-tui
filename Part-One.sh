#!/bin/bash

# Loop control variable
keep_running=true

# Function to create, format, and mount partitions
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
    exec 3>&1;
    SELECTION=$(dialog --clear --title "Main Menu" --menu "Choose an option:" 20 60 10 \
        1 "Check if UEFI or BIOS" \
        2 "Partition, Format and Mount Disk" \
        3 "Start Installation" \
        4 "Clone Repositories" \
        5 "Create Profile" \
        0 "Exit" \
        2>&1 1>&3)
    exec 3>&-;

    # Handle user actions based on selection
    case $SELECTION in
        1) check_uefi_or_bios ;;
        2) partition_drive ;;
        3) start_installation ;;
        4) repo_input ;;
        5) create_profile ;;
        0) dialog --msgbox "Exiting script." 5 30
           keep_running=false
           ;;
        *) dialog --msgbox "Invalid option or cancelled. Please select a valid option." 6 30 ;;
    esac
}

# Initialize running variable
keep_running=true

# Loop the menu until the user exits
while $keep_running; do
    main_menu
done
