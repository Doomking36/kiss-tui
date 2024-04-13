#!/bin/bash

# Loop control variable
keep_running=true

# Update Kiss
kiss_update() {
    # Update the system's package list
    yes | kiss u
    # Upgrade all installed packages
    yes | kiss U

    # Notify completion
    dialog --msgbox "System update complete." 6 60
}

# Install Kiss packages
kiss_install() {
    # Present the user with BIOS or UEFI options
    exec 3>&1;
    SYSTEM_TYPE=$(dialog --menu "Select your system type:" 10 50 2 \
    1 "BIOS" \
    2 "UEFI" \
    2>&1 1>&3);
    exec 3>&-;

    # Set default package list based on the system type
    if [ "$SYSTEM_TYPE" -eq 1 ]; then
        PACKAGE_LIST="baseinit grub e2fsprogs dhcpcd ncurses libelf perl vim sqlite libudev-zero util-linux opendoas"
    elif [ "$SYSTEM_TYPE" -eq 2 ]; then
        PACKAGE_LIST="baseinit grub e2fsprogs dhcpcd ncurses libelf perl vim sqlite libudev-zero util-linux opendoas efibootmgr dosfstools"
    else
        dialog --msgbox "Invalid selection." 5 30
        return
    fi

    # Ask the user for additional packages to install
    exec 3>&1;
    ADDITIONAL_PACKAGES=$(dialog --inputbox "Enter additional packages to install separated by spaces (optional):" 10 60 2>&1 1>&3);
    exec 3>&-;

    # Append additional packages if provided
    if [ -n "$ADDITIONAL_PACKAGES" ]; then
        PACKAGE_LIST="$PACKAGE_LIST $ADDITIONAL_PACKAGES"
    fi

    # Build and install the packages
    yes | kiss b $PACKAGE_LIST

    # Notify completion
    dialog --msgbox "Installation of packages complete: $PACKAGE_LIST" 6 60

    echo permit persist :wheel >> /etc/doas.conf
    echo permit nopass root >> /etc/doas.conf
    echo permit nopass :wheel cmd env >> /etc/doas.conf
}


# Function to get hostname
get_hostname() {
    # Prompt the user for a new hostname
    exec 3>&1;
    HOSTNAME=$(dialog --inputbox "Enter your desired hostname:" 10 50 2>&1 1>&3);
    exec 3>&-;

    # Check if the hostname was provided
    if [ -z "$HOSTNAME" ]; then
        dialog --msgbox "No hostname entered. Operation cancelled." 5 50
        return
    fi

    # Write the hostname to /etc/hostname
    echo "$HOSTNAME" > /etc/hostname

    # Update /etc/hosts
    echo "127.0.0.1 $HOSTNAME.localdomain $HOSTNAME" > /etc/hosts
    echo "::1 $HOSTNAME.localdomain $HOSTNAME ip6-localhost" >> /etc/hosts

    dialog --msgbox "Hostname set to $HOSTNAME and updated in /etc/hostname and /etc/hosts." 6 60
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


# Generate fstab
genfstab() {
    # Download the genfstab script
    dialog --infobox "Downloading genfstab script..." 3 50
    if curl -fLO https://github.com/cemkeylan/genfstab/raw/master/genfstab; then
        # Make the script executable
        chmod +x genfstab

        # Execute the script to append to /etc/fstab
        dialog --infobox "Generating and updating /etc/fstab..." 3 50
        ./genfstab -U / >> /etc/fstab

        # Clean up by removing the script
        rm -rf genfstab
        dialog --msgbox "fstab generated and updated successfully." 5 50
    else
        dialog --msgbox "Failed to download genfstab. Check your internet connection or URL." 5 60
    fi
}

# Install Grub on either BIOS or UEFI system
grub_install() {
    # Present the user with BIOS or UEFI options
    exec 3>&1;
    SYSTEM_TYPE=$(dialog --menu "Select the system type for GRUB installation:" 10 50 2 \
    1 "BIOS" \
    2 "UEFI" \
    2>&1 1>&3);
    exec 3>&-;

    # Ask for the partition device
    DEVICE=$(dialog --inputbox "Enter the device partition (e.g., /dev/sda1 for BIOS or /dev/mmcblk0p2 for UEFI):" 10 60 2>&1 1>&3);
    exec 3>&-;

    if [ -z "$DEVICE" ]; then
        dialog --msgbox "No device entered. Aborting installation." 5 50
        return
    fi

    # Execute commands based on the system type
    if [ "$SYSTEM_TYPE" -eq 1 ]; then
        # BIOS system type
        tune2fs -O ^metadata_csum_seed $DEVICE
        echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
        grub-install --target=i386-pc $DEVICE
        grub-mkconfig -o /boot/grub/grub.cfg
        dialog --msgbox "GRUB installed successfully for BIOS on $DEVICE." 6 50
    elif [ "$SYSTEM_TYPE" -eq 2 ]; then
        # UEFI system type
        tune2fs -O ^metadata_csum_seed $DEVICE
        echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=kiss $DEVICE
        grub-mkconfig -o /boot/grub/grub.cfg
        dialog --msgbox "GRUB installed successfully for UEFI on $DEVICE." 6 50
    else
        dialog --msgbox "Invalid system type selection." 5 40
    fi
}



# Main Menu
main_menu() {
    exec 3>&1;
    SELECTION=$(dialog --menu "Main Menu: Choose an option:" 20 60 7 \
    1 "Update Kiss" \
    2 "Install Kiss Packages" \
    3 "Set Hostname" \
    4 "Set Root Password" \
    5 "Add User" \
    6 "Generate Fstab" \
    7 "Install Grub" \
    2>&1 1>&3);
    exec 3>&-;

    case $SELECTION in
        1) kiss_update ;;
        2) kiss_install ;;
        3) get_hostname ;;
        4) set_root_password ;;
        5) add_user ;;
        6) genfstab ;;
        7) grub_install ;;
        *) dialog --msgbox "Exiting script." 6 25; keep_running=false ;;
    esac
}

# Loop the menu until the user exits
while $keep_running; do
    main_menu
done
