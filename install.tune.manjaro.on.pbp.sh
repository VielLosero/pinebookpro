#!/bin/bash
# Script for download and tune pinebook pro manjaro i3 image on SD or eMMC.
# 

# Variables
THIS_SCRIPT=$(basename $0)
HOME_DIR=$(echo $HOME)
# dir files to tune image
COPY_FILES_FROM=$HOME_DIR/data/pinebookpro/
# download file link
## https://www.manjaro.org/downloads/arm/pinebook-pro/arm8-pinebook-pro-i3/
URL=https://osdn.net/projects/manjaro-arm/storage/pbpro/i3/20.10/Manjaro-ARM-i3-pbpro-20.10.img.xz
FILE=Manjaro-ARM-i3-pbpro-20.10.img.xz
FILE_SHA1=c12f50e96950863e3922e17291f4cea449ad675a 
FILE_DIR=$HOME_DIR/data/pinebookpro/software-releases/
# device and image UUID
DEVICE=sdb
IMAGE_BOOT_UUID="6157-0A82"
IMAGE_ROOT_UUID="4a96675c-e769-416e-8eac-1e04bf7cbab2"


check_file() {
	if [ ! -e ${FILE_DIR}${FILE} ] ; then
		wget -O ${FILE_DIR}${FILE} $URL && echo "[*] Image file downloaded"
	else 
		echo "[*] Image file exist, checking sha1"
		if [ "$( _hash=($(sha1sum ${FILE_DIR}${FILE} )) ;echo ${_hash[0]})" == "$FILE_SHA1" ] ; then 
			echo "[*] Image file sha1 OK"
		else
			echo "[!] Image file sha1 FAIL ... exiting" && exit 1
		fi
	fi
}

check_device(){
	# Device, check device partitions ...
	DEVICE_BOOT=$(lsblk /dev/$DEVICE -o PATH |tail +3 |head -1 | cut -d"/" -f 3)
	DEVICE_ROOT=$(lsblk /dev/$DEVICE -o PATH |tail +4 |head -1 | cut -d"/" -f 3)
	
	## check if device have a wellknow image or dd it
	if [ "$(lsblk /dev/${DEVICE_BOOT} -o UUID 2>/dev/null | tail -1)" == "$IMAGE_BOOT_UUID" ] ; then 
		if [ "$(lsblk /dev/${DEVICE_ROOT} -o UUID 2>/dev/null | tail -1)" == "$IMAGE_ROOT_UUID" ] ; then 
			echo "[*] Check if image need resize"
			if [ "$(fdisk -l /dev/sdb2 | head -1 | cut -d" " -f 3)" != "58,64" ] ; then
				resize_image && check_device
			else
				echo "[*] Device image OK"
			fi
		else
			copy_image_to_device && check_device
		fi
	else
		copy_image_to_device && check_device
	fi
}


copy_image_to_device(){
	#copy image to device
	#unzip -p 2021-01-11-raspios-buster-armhf-lite.zip | dd of=/dev/sdb bs=4M status=progress
	echo "[*] Copying $FILE to /dev/$DEVICE"
	# sanity check
	read -r -p "Are you sure? [Yes/No] " _response
	case "$_response" in
		[Yy][Ee][Ss]|[Yy]) xzcat -d -k ${FILE_DIR}${FILE} | dd of=/dev/$DEVICE bs=4M status=progress;;
		[Nn][Oo]|[Nn]) echo " exiting" && exit 1 ;;
	esac
}

resize_image(){
	# try to resize image
	echo "[*] Resizing partition..."
	#echo ", +" | sfdisk --no-reread -N 2 /dev/$DEVICE
	echo -e "d\n2\nn\np\n2\n500001\n\nn\nw\n" | fdisk /dev/${DEVICE} 2>&1 >/dev/null || exit 1 
	e2fsck -f /dev/${DEVICE_ROOT}
	resize2fs -p /dev/${DEVICE_ROOT}
}

mount_device() {
	# Mounting device 
	#DEVICE_BOOT=$(lsblk /dev/$DEVICE -o PATH |tail +3 |head -1 | cut -d"/" -f 3)
	#DEVICE_ROOT=$(lsblk /dev/$DEVICE -o PATH |tail +4 |head -1 | cut -d"/" -f 3)
	## variables for mount 
	MNT_BOOT=/mnt/${DEVICE_BOOT}_boot
	MNT_ROOT=/mnt/${DEVICE_ROOT}_root
	## Create mount point dirs if not exist
	[ ! -d $MNT_BOOT ] && echo "[*] Making boot dir mountpoint" && sudo mkdir $MNT_BOOT 
	[ ! -d $MNT_ROOT ] && echo "[*] Making root dir mountpoint" && sudo mkdir $MNT_ROOT
	## check if dir are empty then mount device
	[[ -z $(sudo ls -A $MNT_BOOT) ]] && \
	sudo mount /dev/$DEVICE_BOOT $MNT_BOOT && \
	echo "[*] Mounting boot device" 
	## check if dir are empty then mount device
	[[ -z $(sudo ls -A $MNT_ROOT) ]] && \
	sudo mount /dev/$DEVICE_ROOT $MNT_ROOT && \
	echo "[*] Mounting root device"
	## check if mounted
	if mount -l | grep "/dev/$DEVICE_BOOT on $MNT_BOOT" >/dev/null; then 
	echo "[*] Device boot mounted" 
	else
		exit 1
	fi
	if mount -l | grep "/dev/$DEVICE_ROOT on $MNT_ROOT" >/dev/null ; then
	echo "[*] Device root mounted" 
	else
		exit 1
	fi
}

tune_image(){
	# tune image
	echo "[*] Tuning image"
	## cp EOM-script
	#cp $COPY_FILES_FROM/manjaro/manjaro-arm-oem-install $MNT_ROOT/usr/share/manjaro-arm-oem-install/manjaro-arm-oem-install
	## Copy this script to image opt
	if [ ! -e $MNT_ROOT/opt/$THIS_SCRIPT ] ; then cp $0 $MNT_ROOT/opt/;chmod 700 $MNT_ROOT/opt/$THIS_SCRIPT ; fi
	## Copy image to SD_card needed for dd on emmc, change device to emmc etc
	#if  [ ! -e $MNT_ROOT/opt/${FILE} ] ; then cp ${FILE_DIR}${FILE} $MNT_ROOT ; fi
	
	## Copying specific config files
	cp $COPY_FILES_FROM/bootsplash/bootsplash.tux $MNT_ROOT/usr/lib/firmware/bootsplash-themes/manjaro/bootsplash
	mkdir -p $MNT_ROOT/etc/xdg/termite/
	cp $COPY_FILES_FROM/config/etc/xdg/termite/config $MNT_ROOT/etc/xdg/termite/config
	cp $COPY_FILES_FROM/config/usr/share/conky/conky_maia $MNT_ROOT/usr/share/conky/conky_maia
	#.bashrc
	cat<<'EOF'>$MNT_ROOT/usr/share/manjaro-arm-oem-install/manjaro-arm-oem-install
#! /bin/bash

# suppress dmesg output while the script is running
echo 1 > /proc/sys/kernel/printk

#variables
TMPDIR=/var/tmp
SYSTEM=`inxi -M | awk '{print $6}'`
SYSTEMPRO=`inxi -M | awk '{print $8}'`
USER="rock"
FULLNAME="rock"
PASSWORD="rock"
USERGROUPS=""
ROOTPASSWORD="rock"
TIMEZONE="Europe/Madrid"
LOCALE="es_ES.UTF-8"
KEYMAP="uk"
HOSTNAME="pbp"
PACKAGES="arm-none-eabi-gcc atinout autoconf automake bind bison bluez-utils-compat dtc fakeroot flex gcc hugo libreoffice-fresh-es m4 make mpv mtd-utils nethogs nvme-cli patch pikaur pkgconf pkgfile python-bluepy python-pip python-pygame python-pyserial python-reportlab rsync sox sshfs termite texinfo wavemon" #cronie qemu vim bind-tools"

#set dialog theme to Manjaro colors
export DIALOGRC="/usr/share/manjaro-arm-oem-install/dialogrc"

# Functions
msg() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    GREEN="${BOLD}\e[1;32m"
      local mesg=$1; shift
      printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
 }

sbmsg() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    GREEN="${BOLD}\e[1;32m"
      local mesg=$1; shift
      printf "    [${GREEN}*${ALL_OFF}${BOLD}] ${mesg}${ALL_OFF}\n" "$@" >&2
 }


create_oem_install() {
    echo "$USER" > $TMPDIR/user
    echo "$PASSWORD" >> $TMPDIR/password
    echo "$PASSWORD" >> $TMPDIR/password
    echo "$ROOTPASSWORD" >> $TMPDIR/rootpassword
    echo "$ROOTPASSWORD" >> $TMPDIR/rootpassword
    msg "Setting root password..."
    passwd root < $TMPDIR/rootpassword 1> /dev/null 2>&1
    msg "Adding user $USER..."
    useradd -m -G wheel,sys,audio,input,video,storage,lp,network,users,power -s /bin/bash $(cat $TMPDIR/user) 1> /dev/null 2>&1
    if [ -d /usr/share/sddm ]; then
    cp /usr/share/sddm/faces/.face.icon /usr/share/sddm/faces/$USER.face.icon
    fi
    usermod -aG $USERGROUPS $(cat $TMPDIR/user) 1> /dev/null 2>&1
    msg "Setting full name to $FULLNAME..."
    chfn -f "$FULLNAME" $(cat $TMPDIR/user) 1> /dev/null 2>&1
    msg "Setting password for $USER..."
    passwd $(cat $TMPDIR/user) < $TMPDIR/password 1> /dev/null 2>&1
    msg "Setting timezone to $TIMEZONE..."
    timedatectl set-timezone $TIMEZONE 1> /dev/null 2>&1
    timedatectl set-ntp true 1> /dev/null 2>&1
    msg "Generating $LOCALE locale..."
    sed -i s/"#$LOCALE"/"$LOCALE"/g /etc/locale.gen 1> /dev/null 2>&1
    locale-gen 1> /dev/null 2>&1
    localectl set-locale $LOCALE 1> /dev/null 2>&1
    if [[ "$SYSTEM" != "Pinebook" ]]; then
    msg "Setting keymap to $KEYMAP..."
    localectl set-keymap $KEYMAP 1> /dev/null 2>&1
    fi
    if [ -f /etc/sway/inputs/default-keyboard ]; then
    sed -i s/"us"/"$KEYMAP"/ /etc/sway/inputs/default-keyboard
        	if [[ "$KEYMAP" = "uk" ]]; then
        	sed -i s/"uk"/"gb"/ /etc/sway/inputs/default-keyboard
        	fi
    fi
    msg "Setting hostname to $HOSTNAME..."
    hostnamectl set-hostname $HOSTNAME 1> /dev/null 2>&1
    #msg "Resizing partition..."
    #resize-fs 1> /dev/null 2>&1
    msg "Applying system settings..."
    	sbmsg "Disabling unwanted services..."
    	systemctl disable systemd-resolved.service 1> /dev/null 2>&1
	sbmsg "Configuring crypted home... "
	echo "data    /dev/nvme0n1p3       0 discard" >> /etc/crypttab
        echo "/dev/mapper/data      /home     xfs    defaults        0 0" >> /etc/fstab
	sbmsg "Configuring DPI for big fonts..."
        sed -i 's/Xft.dpi:.*/Xft.dpi: 140/' /home/$USER/.Xresources
	sbmsg "Remove conky_maia shortcuts..."
	sed -i 's/conky -c /usr/share/conky/conky1.10_shortcuts_maia &&/#conky -c /usr/share/conky/conky1.10_shortcuts_maia &&/' /usr/bin/start_conky_maia
	sbmsg "Creating system links..."
	[ ! -f /usr/bin/vi ] && ln -s /usr/bin/vim /usr/bin/vi
	sbmsg "Creating default mountpoints..."
	for mountdir in 1 2 3 4 backup blanc red blue negre disk1 sea_remote install; do
	    [ ! -d /mnt/$mountdir ] && mkdir /mnt/$mountdir && echo "[*] Mount dir $mountdir created"
	done
	sbmsg "Creating Power saving service..."
	## Config power saving for nmve
	if [ ! -f /etc/systemd/system/ssd.power.save.settings.service ] ; then
	cat <<EOFS> /etc/systemd/system/ssd.power.save.settings.service
[Unit]
#For power limiting SSD consumition: Some NVMe SSDs don't appear to allow saving the setting with "-s" option. In those cases, leave off the "-s" and use a startup script to set the non-default power state at boot.
Description=SSD power limitation

[Service]
User=root
ExecStart=nvme set-feature /dev/nvme0 -f 2 -v 2

[Install]
WantedBy=default.target
EOFS
	fi
	sbmsg "Configuring network..."

	sbmsg "Updating software..."
	if ping -c 1 8.8.8.8 ; then 
	#pacman -Syu
	pacman -Syu --ignore=uboot-pinebookpro #,linux-aarch64 
	fi
	sbmsg "Installing software..."
	pacman -S $PACKAGES
	fi
    	sbmsg "Enabling wanted services..."
	systemctl enable ssd.power.save.settings.service 1> /dev/null 2>&1
	systemctl enable fstrim.timer 1> /dev/null 2>&1

    msg "Cleaning install for unwanted files..."
    sudo rm -rf /var/log/*
    
    # Remove temp files on host
    sudo rm -rf $TMPDIR/user $TMPDIR/password $TMPDIR/rootpassword
}

# Kill bootsplash so the script can be seen
echo off > /sys/devices/platform/bootsplash.0/enabled

create_oem_install

msg "Configuration complete. Cleaning up..."
mv /usr/lib/systemd/system/getty@.service.bak /usr/lib/systemd/system/getty@.service
rm /root/.bash_profile
sed -i s/"PermitRootLogin yes"/"#PermitRootLogin prohibit-password"/g /etc/ssh/sshd_config
sed -i s/"PermitEmptyPasswords yes"/"#PermitEmptyPasswords no"/g /etc/ssh/sshd_config

## Remove packages
#pacman -Rsn manjaro-arm-oem-install --noconfirm 1> /dev/null 2>&1

if [ -f /usr/bin/sddm ]; then
systemctl enable sddm 1> /dev/null 2>&1
elif [ -f /usr/bin/lightdm ]; then
systemctl enable lightdm 1> /dev/null 2>&1
elif [ -f /usr/bin/gdm ]; then
systemctl enable gdm 1> /dev/null 2>&1
elif [ -f /usr/bin/greetd ]; then
systemctl enable greetd 1> /dev/null 2>&1
fi

msg "Rebooting in 3 seconds..."
sleep 1
echo "2..."
sleep 1
echo "1..."
sleep 1
reboot
EOF
}

umount_device(){
	# umount device
	sudo umount /dev/$DEVICE_BOOT && \
	sudo umount /dev/$DEVICE_ROOT && \
	## remove mountpoints
	[[ -z $(sudo ls -A $MNT_BOOT) ]] && \
	sudo rmdir $MNT_BOOT && echo "[*] $MNT_BOOT umounted"
	[[ -z $(sudo ls -A $MNT_ROOT) ]] && \
	sudo rmdir $MNT_ROOT && echo "[*] $MNT_ROOT umounted"
}


# main loop
check_file && check_device && mount_device && tune_image && umount_device

# exit
#exit 0

