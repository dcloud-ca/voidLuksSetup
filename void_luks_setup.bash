#!/bin/bash

###############################################################################################################
#BEGIN MANDATORY FIELDS
#These fields must be configured as per your computer hardware and desired install configuration

efi_part_size="260M"		#Minimum of 100M, Arch wiki recommends at least 260M (as of 24-Mar-2021)

root_part_size="15G"		#Size of the root partition. Required size depends on how much software you ultimately install
				#Arch wiki recommends 15-20G (as of 24-Mar-2021)
				
swap_size="4G"			#If you want to use suspend-to-disk (AKA hibernate), should be >= amount of RAM.
				#Otherwise, equal to square root of RAM (rounded up), or at least 2G

username="user"			#Desired username for regular (non-root) user of the Void installation you're making

hostname="desktop"		#Desired name to be used for the hostname of the Void installation as well as the volume group name

fs_type="ext4"			#Desired filesystem to be used for the root and home partitions

libc="musl" 			#"musl" for musl, "" for glibc.

language="en_US.UTF-8"

vendor_cpu="intel"		#Enter either "amd" or "intel" (all lowercase). This script assumes you're installing on an x86_64 system

vendor_gpu="amd"		#Enter either "amd", "intel", or "nvidia" (all lowercase)
				#For AMD will install the OpenGL and Vulkan driver (mesa, not amdvlk), as well as the video acceration drivers.
				#For Intel this installs OpenGL and Vulkan drivers, and video acceleration drivers
				#For Nvidia this installs the proprietary driver. It assumes you're using a non-legacy GPU, which generally means any Geforce 600 or newer GTX card (some of the low end GT cards from 600, 700, and 800 series are legacy) 

discards="rd.luks.allow-discards"	#If you're installing on an SSD and you want discard (automatic TRIM) enabled, enter "rd.luks.allow-discards".
					#Otherwise, leave blank (just double quotes, "")
					#Note that there privacy/security considerations to enabling TRIM with LUKS: https://wiki.archlinux.org/index.php/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)

graphical_de="kde"		#"xfce" for the standard XFCE install that you would get if you install using the XFCE live image
                        	#Or "kde" for a KDE Plasma Wayland install. Somewhat reduced install compared to the full 'kde5' meta-package. Uses a console-based display manager (emptty) rather than SDDM (as this would require Xorg).
                        	#Or leave blank (just double quotes, "") to not install DE. Will skip graphics driver installation as well

void_repo="https://alpha.us.repo.voidlinux.org/"	#List of mirrors can be found here: https://docs.voidlinux.org/xbps/repositories/mirrors/index.html

#END MANDATORY FIELDS
###############################################################################################################
#BEGIN OPTIONAL FIELDS
#Lists of apps to install, services to enable/disable, and groups that the user should be made a part of, to be performed during the install
#These can be edited prior to running the script, but you can also easily install (and uninstall) packages, and enable/disable services, once you're up and running.

#Note that the script assumes nano is being installed, and sets it as the default editor for sudoers later in the script
#Even if apparmor is removed here, it will still be added to the kernal command line arguments in the GRUB config performed further in the script
apps="nano flatpak elogind dbus alsa-utils apparmor ufw gufw cronie ntp rclone RcloneBrowser firefox"

#elogind and acpid should not both be enabled. Same with dhcpcd and NetworkManager.
rm_services=("agetty-tty2" "agetty-tty3" "agetty-tty4" "agetty-tty5" "agetty-tty6" "mdadm" "sshd" "acpid" "dhcpcd") 
en_services=("dbus" "elogind" "NetworkManager" "emptty" "ufw" "cronie" "ntpd")
	
#Being part of the wheel group allows use of sudo so you'll be able to add yourself to more groups in the future without having to login as root
#Some additional groups you may way to add to the above list (separate with commas, no spaces): floppy,cdrom,optical,audio,video,kvm,xbuilder
user_groups="wheel"
###############################################################################################################
#These should only need to be changed if you want to tweak what gets installed as part of your graphical desktop environment
#Or you have an old Nvidia or AMD/ATI GPU, and need to use a different driver package

declare apps_intel_cpu="intel-ucode"
declare apps_amd_cpu="linux-firmware-amd"
declare apps_amd_gpu="linux-firmware-amd mesa-dri vulkan-loader mesa-vulkan-radeon mesa-vaapi mesa-vdpau xf86-video-amdgpu"
declare apps_intel_gpu="linux-firmware-intel mesa-dri mesa-vulkan-intel intel-video-accel xf86-video-intel"
declare apps_nvidia_gpu="nvidia"
declare apps_kde="emptty plasma-desktop konsole kcron pulseaudio ark plasma-pa kdeplasma-addons5 user-manager plasma-nm dolphin xdg-utils kscreen kwayland-integration xdg-desktop-portal-kde upower udisks2" #plasma-firewall GUI front end for ufw doesn't seem to be working as of April/21
declare apps_xfce="xorg-minimal xorg-fonts xterm lightdm lightdm-gtk3-greeter xfce4"

###############################################################################################################
#Add CPU microcode, graphics drivers, and/or desktop environment packages to the list of packages to install
case $vendor_cpu in
    "amd")
        apps="$apps $apps_amd_cpu"
        ;;
    "intel")
        apps="$apps $apps_intel_cpu"
        ;;
esac
if [[ -n $graphical_de ]]; then
    case $vendor_gpu in
        "amd")
            apps="$apps $apps_amd_gpu"
            ;;
        "intel")
            apps="$apps $apps_intel_gpu"
            ;;
        "nvidia")
            apps="$apps $apps_nvidia_gpu"
            ;;
    esac
fi
case $graphical_de in
    "kde")
        apps="$apps $apps_kde"
        ;;
    "xfce")
        apps="$apps $apps_xfce"
        ;;
esac

#Read passwords for root user, non-root user, and LUKS encryption from user input
declare luks_pw root_pw user_pw disk_selected
echo -e "\nEnter password to be used for disk encryption\n"
read luks_pw
echo -e "\nEnter password to be used for the root user\n"
read root_pw
echo -e "\nEnter password to be used for the user account\n"
read user_pw

#Prompt user to select disk for installation
PS3="Select disk for installation: "
select line in $(fdisk -l | grep -v mapper | grep -o '/.*GiB' | tr -d ' '); do
        echo "Selected disk: $line"
        disk_selected=$(echo $line | sed 's/:.*$//')
        break
done
if [[ $(echo $disk_selected | grep -o sd) == "sd" ]]; then
	efi_part=$(echo $disk_selected'1')
	luks_part=$(echo $disk_selected'2')
fi
if [[ $(echo $disk_selected | grep -o nvme) == "nvme" ]]; then
	efi_part=$(echo $disk_selected'p1')
	luks_part=$(echo $disk_selected'p2')
fi

#Wipe disk
wipefs -aq $disk_selected
#Format disk as GPT, create EFI partition with size selected above and a 2nd partition with the remaining disk space
printf 'label: gpt\n, %s, U, *\n, , L\n' "$efi_part_size" | sfdisk -q "$disk_selected"
#Create LUKS encrypted partition
echo $luks_pw | cryptsetup -q luksFormat --type luks1 $luks_part
#Open encrypted partition
echo $luks_pw | cryptsetup -q luksOpen $luks_part $hostname

#Create volume group in encrypted partition, and create root, swap and home volumes
vgcreate -q $hostname /dev/mapper/$hostname
lvcreate --name root -qL $root_part_size $hostname
lvcreate --name swap -qL $swap_size $hostname
lvcreate --name home -ql 100%FREE $hostname
#Create swap, root, and home filesystems, with the filesystem for home and root as selected above
mkfs.$fs_type -qL root /dev/$hostname/root
mkfs.$fs_type -qL home /dev/$hostname/home
mkswap /dev/$hostname/swap

#Mount newly created filesystems, and create/mount virtual filesystem location under the root directory
mount /dev/$hostname/root /mnt
for dir in dev proc sys run; do
	mkdir -p /mnt/$dir
	mount --rbind /$dir /mnt/$dir
	mount --make-rslave /mnt/$dir
done
mkdir -p /mnt/home
mount /dev/$hostname/home /mnt/home

#Create/mount EFI system partition filesystem
mkfs.vfat $efi_part
mkdir -p /mnt/boot/efi
mount $efi_part /mnt/boot/efi

#Install Void directly from the repo
echo y | xbps-install -SyR https://alpha.de.repo.voidlinux.org/current/$libc -r /mnt base-system cryptsetup grub-x86_64-efi lvm2

#Find the UUID of the encrypted LUKS partition
luks_uuid=$(blkid -o value -s UUID $luks_part)

#Copy the DNS configuration from the live image to allow internet access from the chroot of the new install
cp /etc/resolv.conf /mnt/etc

#Change ownership and permissions of root directory
chroot /mnt chown root:root /
chroot /mnt chmod 755 /

#Create non-root user and add them to group(s)
chroot /mnt useradd $username
chroot /mnt usermod -aG $user_groups $username
#Use the "HereDoc" to send a sequence of commands into chroot, allowing the root and non-root user passwords in the chroot to be set non-interactively
cat << EOF | chroot /mnt
echo "$root_pw\n$root_pw" | passwd -q root
echo "$user_pw\n$user_pw" | passwd -q $username
EOF

#Set hostname and language/locale
echo $hostname > /mnt/etc/hostname
echo "LANG=$language" > /mnt/etc/locale.conf
#libc-locales are only applicable for glibc installations, skip if musl was selected above
if [[ -z $libc ]]; then
    echo "en_US.UTF-8 UTF-8" >> /mnt/etc/default/libc-locales
    xbps-reconfigure -fr /mnt/ glibc-locales
fi

#Add lines to fstab, which determines which partitions/volumes are mounted at boot
echo -e "/dev/$hostname/root	/	$fs_type	defaults	0	0" >> /mnt/etc/fstab
echo -e "/dev/$hostname/home	/home	$fs_type	defaults	0	0" >> /mnt/etc/fstab
echo -e "/dev/$hostname/swap	swap	swap	defaults	0	0" >> /mnt/etc/fstab
echo -e "$efi_part	/boot/efi	vfat	defaults	0	0" >> /mnt/etc/fstab

#Modify GRUB config to allow for LUKS encryption. The two apparmor items enable the apparmor security module.
echo "GRUB_ENABLE_CRYPTODISK=y" >> /mnt/etc/default/grub
sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"rd.lvm.vg=$hostname rd.luks.uuid=$luks_uuid $discards apparmor=1 security=apparmor /" /mnt/etc/default/grub

#To avoid having to enter the password twice on boot, a key will be configured to automatically unlock the encrypted volume on boot.
#Generate keyfile
dd bs=1 count=64 if=/dev/urandom of=/mnt/boot/volume.key
#Use the "HereDoc" to send a sequence of commands into chroot, allowing the keyfile to be added to the encrypted volume in the chroot non-interactively
cat << EOF | chroot /mnt
echo $luks_pw | cryptsetup -q luksAddKey $luks_part /boot/volume.key
EOF
#Change the permissions to protect generated the keyfile
chroot /mnt chmod 000 /boot/volume.key
chroot /mnt chmod -R g-rwx,o-rwx /boot
#Add keyfile to /etc/crypttab
echo "$hostname	$luks_part	/boot/volume.key	luks" >> /mnt/etc/crypttab
#Add keyfile and crypttab to initramfs
echo -e "install_items+=\" /boot/volume.key /etc/crypttab \"" > /mnt/etc/dracut.conf.d/10-crypt.conf

#Install GRUB bootloader
chroot /mnt grub-install $disk_selected

#Ensure an initramfs is generated
xbps-reconfigure -far /mnt/

#Allow users in the wheel group to use sudo
sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /mnt/etc/sudoers
#Change the default text editor from VI to nano for visudoand sudoedit)
echo "Defaults editor=/usr/bin/nano" >> /mnt/etc/sudoers

#Ensure the xbps package manager in the chroot is up to date
xbps-install -Suyr /mnt xbps
#Nvidia graphics drivers and intel microcode are both proprietary, if we need to install either we need to install the nonfree repo
if [[ $vendor_gpu == "nvidia" ]] || [[ $vendor_cpu == "intel" ]]; then
    xbps-install -Syr /mnt/ void-repo-nonfree
fi
#Install all previously selected packages. This includes all applications in the "apps" variable, as well as packages for graphics drivers, CPU microcode, and graphical DE based on selected options
xbps-install -Syr /mnt $apps
  
#Disable services as selected above
for service in ${rm_services[@]}; do
	chroot /mnt rm /etc/runit/runsvdir/default/$service
done
#Enable services as selected above
for service in ${en_services[@]}; do
	chroot /mnt ln -s /etc/sv/$service /etc/runit/runsvdir/default/
done 

#Enable apparmor, set to "enforce" (alternatively can be "complain")
sed -i 's/^#*APPARMOR=.*$/APPARMOR=enforce/i' /mnt/etc/default/apparmor
#Enable apparmor profile caching, which speeds up boot
sed -i 's/^#*write-cache/write-cache/i' /mnt/etc/apparmor/parser.conf

#Creates typical folders in user's home directory, sets ownership and permissions of the folders as well
for dir in Desktop Documents Downloads Videos Pictures Music; do
	chroot /mnt mkdir -p /home/$username/$dir
	chroot /mnt chown $username:$username /home/$username/$dir
	chroot /mnt chmod 700 /home/$username/$dir
done

#Includes the .bash_aliases file as part of .bashrc. This is a more modular way of adding aliases (which can also be added directly to .bashrc)
echo 'if [ -e $HOME/.bash_aliases ]; then
source $HOME/.bash_aliases
fi' >> /mnt/home/$username/.bashrc
#Create .bash_aliases file, sets owner to user
chroot /mnt touch /home/$username/.bash_aliases
chroot /mnt chown $username:$username /home/$username/.bash_aliases
#Some personal aliases I use to shorten package manager commands. Inpsired by the command syntax used for xbps commands by the xtools package (http://git.vuxu.org/xtools)
echo "alias xi='sudo xbps-install -S'" >> /mnt/home/$username/.bash_aliases 
echo "alias xu='sudo xbps-install -Suy'" >> /mnt/home/$username/.bash_aliases 
echo "alias xs='xbps-query -Rs'" >> /mnt/home/$username/.bash_aliases 
echo "alias xr='sudo xbps-remove -oOR'" >> /mnt/home/$username/.bash_aliases 
echo "alias xq='xbps-query'" >> /mnt/home/$username/.bash_aliases 

#If KDE is selected for install, the emptty console-based display manager will be installed (unless configured otherwise)
#If so, set emptty to use the TTY that is one higher than the number that are configured to be enabled in /var/service/
#By default, this script disables all TTYs except for TTY1, so set emptty to use TTY2.
if [[ $graphical_de == "kde" ]]; then
	tty=2
	sed -i "s/^#*TTY_NUMBER=[0-9]*/TTY_NUMBER=$tty/i" /mnt/etc/emptty/conf
	#Set default emptty login as the non-root user that was created
	sed -i "s/^#*DEFAULT_USER=/DEFAULT_USER=$user_name/i" /mnt/etc/emptty/conf
	#Lists available desktop environments/sessions vertically, rather than all in one row
	sed -i "s/^#*VERTICAL_SELECTION=.*$/VERTICAL_SELECTION=true/i" /mnt/etc/emptty/conf
fi

#Enable numlock on startup for TTY range specified.
#By default this install script will result in two TTYs being used (one for regular login shell, another for emptty)
echo 'INITTY=/dev/tty[1-2]
for tty in $INITTY; do
	setleds -D +num < $tty
done' >> /mnt/etc/rc.conf

#Change the void repository mirror to be used by the package manager
chroot /mnt mkdir -p /etc/xbps.d
cp /mnt/usr/share/xbps.d/*-repository-*.conf /mnt/etc/xbps.d/
sed -i "s|https://alpha.de.repo.voidlinux.org|$void_repo|g" /mnt/etc/xbps.d/*-repository-*.conf

echo -e "\nUnmount newly created Void installation and reboot? (y/n)\n"
read tmp
if [[ $tmp == "y" ]]; then
	umount -R /mnt				#Unmount root volume
	vgchange -an				#Deactivate volume group
	cryptsetup luksClose $hostname		#Close LUKS encrypted partition
	reboot
fi

echo -e "\nDone\n"
