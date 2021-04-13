#!/bin/bash

###############################################################################################################
#BEGIN MANDATORY FIELDS
#These fields must be configured as per your computer hardware and desired install configuration

efi_part_size="260M"		#Minimum of 100M, Arch wiki recommends at least 260M (as of 24-Mar-2021)

root_part_size="20G"		#Size of the root partition. Required size depends on how much software you ultimately install
				#If you run this install script without modifying the apps to be installed (including KDE graphical DE), about 4-5G is used
				#Arch wiki recommends 15-20G (as of 24-Mar-2021)
				#Alternatively, leave blank to omit creating a separate home partition, and have root occupy the entire drive
				
swap_size=""			#If you want to use suspend-to-disk (AKA hibernate), should be >= amount of RAM (some recommend 2x RAM if you have <8GB).
				#Otherwise, how much swap space (if any) is needed is debatable, rule of thumb I use is equal to square root of RAM (rounded up to whole GB)

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

graphical_de="kde"		#"xfce" for an XFCE4 (xorg) install
                        	#Or "kde" for a KDE Plasma 5 (wayland) install. Somewhat reduced install compared to the full 'kde5' meta-package. Uses a console-based display manager (emptty) rather than SDDM (as this would require Xorg).
                        	#Or leave blank (just double quotes, "") to not install DE. Will skip graphics driver installation as well

void_repo="https://alpha.de.repo.voidlinux.org/"	#List of mirrors can be found here: https://docs.voidlinux.org/xbps/repositories/mirrors/index.html

#END MANDATORY FIELDS
###############################################################################################################
#BEGIN APP/SERVICE SELECTION
#Lists of apps to install, services to enable/disable, and groups that the user should be made a part of, to be performed during the install
#These can be edited prior to running the script, but you can also easily install (and uninstall) packages, and enable/disable services, once you're up and running.

#If apparmor is included here, the script will also add the apparmor security modules to the GRUB command line parameters
apps="xorg-minimal xorg-fonts nano elogind dbus apparmor ufw cronie ntp firefox xdg-desktop-portal xdg-user-dirs xdg-utils" #flatpak alsa-utils gufw rclone RcloneBrowser chromium libreoffice-calc libreoffice-writer

#elogind and acpid should not both be enabled. Same with dhcpcd and NetworkManager.
rm_services=("agetty-tty2" "agetty-tty3" "agetty-tty4" "agetty-tty5" "agetty-tty6" "mdadm" "sshd" "acpid" "dhcpcd") 
en_services=("dbus" "elogind" "NetworkManager" "ufw" "cronie" "ntpd" "udevd" "uuidd")
	
#Being part of the wheel group allows use of sudo so you'll be able to add yourself to more groups in the future without having to login as root
#Some additional groups you may way to add to the above list (separate with commas, no spaces): floppy,cdrom,optical,audio,video,kvm,xbuilder
user_groups="wheel,floppy,cdrom,optical,audio,video,kvm,xbuilder"

#END APP/SERVICE SELECTION
###############################################################################################################
#BEGIN CPU/DRIVER/DE PACKAGES
#These should only need to be changed if you want to tweak what gets installed as part of your graphical desktop environment
#Or you have an old Nvidia or AMD/ATI GPU, and need to use a different driver package

declare apps_intel_cpu="intel-ucode"
declare apps_amd_cpu="linux-firmware-amd"
declare apps_amd_gpu="linux-firmware-amd mesa-dri vulkan-loader mesa-vulkan-radeon mesa-vaapi mesa-vdpau xf86-video-amdgpu"
declare apps_intel_gpu="linux-firmware-intel mesa-dri mesa-vulkan-intel intel-video-accel xf86-video-intel"
declare apps_nvidia_gpu="nvidia"
declare apps_kde="kde5 kde5-baseapps kcron pulseaudio ark user-manager plasma-wayland-protocols xdg-desktop-portal-kde plasma-applet-active-window-control" #libreoffice-kde plasma-disks partitionmanager 
#plasma-firewall GUI front end for ufw doesn't seem to work properly as of April/21
declare apps_xfce="lightdm-gtk3-greeter xfce4 xdg-desktop-portal-gtk xdg-user-dirs-gtk"
declare apps_ob="openbox obconf obmenu-generator tint2 lxappearance alsa-utils lightdm-gtk3-greeter xdg-desktop-portal-gtk xdg-user-dirs-gtk"
#END CPU/DRIVER/DE PACKAGES
###############################################################################################################

#Check if user has filled out required field by seeing if swap_size (which is left blank by default) has a value entered
#If not, exit script
if [[ -z $swap_size ]]; then
	echo -e "\nPlease fill in required fields and re-run script\n"
	exit
fi

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
	en_services+=("sddm")
        ;;
    "xfce")
        apps="$apps $apps_xfce"
	en_services+=("lightdm")
        ;;
    "ob")
        apps="$apps $apps_ob"
        en_services+=("lightdm")
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
if [[ $disk_selected == *"sd"* ]]; then
	efi_part=$(echo $disk_selected'1')
	luks_part=$(echo $disk_selected'2')
elif [[ $disk_selected == *"nvme"* ]]; then
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
echo $luks_pw | cryptsetup luksOpen $luks_part $hostname

#Create volume group in encrypted partition, and create root, swap and home volumes
#If the value for root parition size was left blank, don't create a home volume and instead allocat the rest of the disk to root
vgcreate $hostname /dev/mapper/$hostname
lvcreate --name swap -L $swap_size $hostname
if [[ -z $root_part_size ]]; then
	lvcreate --name root -l 100%FREE $hostname
elif [[ ! -z $root_part_size ]]; then
	lvcreate --name root -L $root_part_size $hostname
	lvcreate --name home -l 100%FREE $hostname
fi	
#Create swap, root, and home filesystems, with the filesystem for home and root as selected above
mkfs.$fs_type -qL root /dev/$hostname/root
if [[ ! -z $root_part_size ]]; then
	mkfs.$fs_type -qL home /dev/$hostname/home
fi
mkswap /dev/$hostname/swap

#Mount newly created filesystems, and create/mount virtual filesystem location under the root directory
mount /dev/$hostname/root /mnt
for dir in dev proc sys run; do
	mkdir -p /mnt/$dir
	mount --rbind /$dir /mnt/$dir
	mount --make-rslave /mnt/$dir
done
if [[ ! -z $root_part_size ]]; then
	mkdir -p /mnt/home
	mount /dev/$hostname/home /mnt/home
fi

#Create/mount EFI system partition filesystem
mkfs.vfat $efi_part
mkdir -p /mnt/boot/efi
mount $efi_part /mnt/boot/efi

#Install Void directly from the repo
echo y | xbps-install -SyR $void_repo/current/$libc -r /mnt base-system cryptsetup grub-x86_64-efi lvm2

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
if [[ ! -z $root_part_size ]]; then
	echo -e "/dev/$hostname/home	/home	$fs_type	defaults	0	0" >> /mnt/etc/fstab
fi
echo -e "/dev/$hostname/swap	swap	swap	defaults	0	0" >> /mnt/etc/fstab
echo -e "$efi_part	/boot/efi	vfat	defaults	0	0" >> /mnt/etc/fstab

#Modify GRUB config to allow for LUKS encryption. Also enables SSD discards if configured above.
#If apparmor is being installed, enable the apparmor security module
kernel_params="rd.lvm.vg=$hostname rd.luks.uuid=$luks_uuid $discards"
if [[ $apps == *"apparmor"* ]]; then
	kernel_params="$kernel_params apparmor=1 security=apparmor"
fi
echo "GRUB_ENABLE_CRYPTODISK=y" >> /mnt/etc/default/grub
sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$kernel_params /" /mnt/etc/default/grub

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
#Change the default text editor from VI to nano for visudo and sudoedit, if nano is installed
if [[ $apps == *"nano"* ]]; then
	echo "Defaults editor=/usr/bin/nano" >> /mnt/etc/sudoers
fi

#Ensure the xbps package manager in the chroot is up to date
xbps-install -SuyR $void_repo/current/$libc -r /mnt xbps
#Nvidia graphics drivers and intel microcode are both proprietary, if we need to install either we need to install the nonfree repo
if [[ $vendor_gpu == "nvidia" ]] || [[ $vendor_cpu == "intel" ]]; then
    xbps-install -SyR $void_repo/current/$libc -r /mnt/ void-repo-nonfree
fi
#Install all previously selected packages. This includes all applications in the "apps" variable, as well as packages for graphics drivers, CPU microcode, and graphical DE based on selected options
xbps-install -SyR $void_repo/current/$libc -r /mnt $apps
  
#Disable services as selected above
for service in ${rm_services[@]}; do
	if [[ -e /mnt/etc/runit/runsvdir/default/$service ]]; then
		chroot /mnt rm /etc/runit/runsvdir/default/$service
	fi
done
#Enable services as selected above
for service in ${en_services[@]}; do
	if [[ ! -e /mnt/etc/runit/runsvdir/default/$service ]]; then
		chroot /mnt ln -s /etc/sv/$service /etc/runit/runsvdir/default/
	fi
done

if [[ $apps == *"apparmor"* ]]; then
	#Enable apparmor, set to "complain" (alternatively can be "enforce")
	sed -i 's/^#*APPARMOR=.*$/APPARMOR=complain/i' /mnt/etc/default/apparmor
	#Enable apparmor profile caching, which speeds up boot
	sed -i 's/^#*write-cache/write-cache/i' /mnt/etc/apparmor/parser.conf
fi

#Creates typical folders in user's home directory, sets ownership and permissions of the folders as well
#It appears this is not necessary, as the user folders will automatically be created on first login
#for dir in Desktop Documents Downloads Videos Pictures Music; do
	#if [[ ! -e /mnt/home/$username/$dir ]]; then
		#chroot /mnt mkdir -p /home/$username/$dir
		#chroot /mnt chown $username:$username /home/$username/$dir
		#chroot /mnt chmod 700 /home/$username/$dir
	#fi
#done

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

#Script updatd to use SDDM for a KDE install rather than emptty, emptty config below disabled
#If so, set emptty to use the TTY that is one higher than the number that are configured to be enabled in /var/service/
#By default, this script disables all TTYs except for TTY1, so set emptty to use TTY2.
num_tty=1
#if [[ $apps == *"emptty"* ]]; then
#	sed -i "s/^#*TTY_NUMBER=[0-9]*/TTY_NUMBER=$num_tty/i" /mnt/etc/emptty/conf
#	#Set default emptty login as the non-root user that was created
#	sed -i "s/^#*DEFAULT_USER=/DEFAULT_USER=$user_name/i" /mnt/etc/emptty/conf
#	#Lists available desktop environments/sessions vertically, rather than all in one row
#	sed -i "s/^#*VERTICAL_SELECTION=.*$/VERTICAL_SELECTION=true/i" /mnt/etc/emptty/conf
#fi

#Enable numlock on startup for TTY range specified.
#By default this install script will result in two TTYs being used (one for regular login shell, another for emptty)
echo "INITTY=/dev/tty[1-$num_tty]
for tty in \$INITTY; do
	setleds -D +num < \$tty
done" >> /mnt/etc/rc.conf

#Change the void repository mirror to be used by the package manager
chroot /mnt mkdir -p /etc/xbps.d
cp /mnt/usr/share/xbps.d/*-repository-*.conf /mnt/etc/xbps.d/
sed -i "s|https://alpha.de.repo.voidlinux.org|$void_repo|g" /mnt/etc/xbps.d/*-repository-*.conf

echo -e "\nUnmount newly created Void installation and reboot? (y/n)\n"
read tmp
if [[ $tmp == "y" ]]; then
	umount -R /mnt				#Unmount root volume
	vgchange -an				#Deactivate volume group
	cryptsetup luksClose $hostname	#Close LUKS encrypted partition
	reboot
fi

echo -e "\nDone\n"
