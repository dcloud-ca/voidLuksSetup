#!/bin/bash

efi_part_size="260M"		#Minimum of 100M, Arch wiki recommends at least 260M (as of 24-Mar-2021)
root_part_size="20G"		#Size of the root partition. Required size depends on how much software you ultimately install, but Arch wiki recommends 15-20G (as of 24-Mar-2021)
swap_size="4G"			#If you want to use suspend-to-disk (AKA hibernate), should be >= amount of RAM.
				#Otherwise, equal to square root of RAM (rounded up), or at least 2G
username=""			#Desired username for regular (non-root) user of the Void installation you're making
hostname="voidLinux"		#Desired name to be used for the hostname of the Void installation as well as the volume group name
fs_type="ext4"			#Desired filesystem to be used for the root and home partitions
libc="musl" 			#"musl" for musl, "" for glibc
language="en_US.UTF-8"
vendor_cpu="intel"		#Enter either "amd" or "intel" (all lowercase). This script assumes you're installing on an x86_64 system
vendor_gpu="amd"		#Enter either "amd", "intel", or "nvidia" (all lowercase)
				#For AMD will install the OpenGL and Vulkan driver (mesa, not amdvlk), as well as the video acceration drivers. Does not install the Xorg drivers, you must install the separately if you want to use Xorg
				#For Intel this installs OpenGL and Vulkan drivers, and video acceleration drivers
				#For Nvidia this installs the proprietary driver. It assumes you're using a non-legacy GPU, which generally means any Geforce 600 or newer GTX card (some of the low end GT cards from 600, 700, and 800 series are legacy) 
graphical_de="xfce4"		#Either "xfce4" for the standard XFCE install that you would get if you install using the XFCE live image
				#Or "kde" for a 'minimal' KDE Plasma install with Wayland
apps="nano flatpak elogind dbus alsa apparmor ufw cron"
#apps for intel CPU: nonfree-repo, intel-ucode
#apps for amd CPU: linux-firmware-amd
#apps for amd GPU: linux-firmware-amd mesa-dri vulkan-loader mesa-vulkan-radeon mesa-vaapi mesa-vdpau xf86-video-amdgpu
#apps for intel GPU: linux-firmware-intel mesa-dri mesa-vulkan-intel intel-video-accel xf86-video-intel
#apps for nvidia GPU: nonfree-repo nvidia
#apps for kde: emptty plasma-workspace konsole alsa kcron pulseaduio plasma-pa plasma-firewall dolphin #plasma-nm NetworkManager
#apps for xfce: xorg-minimal xorg-fonts xterm lightdm lightdm-gtk3-greeter xfce4
rm_services=("agetty-tty2" "agetty-tty3" "agetty-tty4" "agetty-tty5" "agetty-tty6" "mdadm" "sshd" "acpid" "NetworkManager")
en_services=("dbus" "elogind" "dhcpcd" "emptty" "ufw" "cron" "ntpd")


declare luks_pw root_pw user_pw
declare -a disk_array

echo -e "\nEnter password to be used for disk encryption\n"
read luks_pw

echo -e "\nEnter password to be used for the root user\n"
read root_pw

echo -e "\nEnter password to be used for the user account\n"
read user_pw

while IFS= read -r line; do
	if [ "$line" != "" ]
	then
		disk_array+=("$(echo $line | sed 's/:.*//')")
		printf '%s %s\n' "${#disk_array[*]}" "$line"
	fi
done < <(fdisk -l | grep -v mapper | grep -o '/.*GiB')

printf "\nSelect disk to be installed to, by entering the number to the left of the desired device and hitting Enter\n"

read selection

disk_selected=${disk_array[((selection-1))]}


if [[ $(echo $disk_selected | grep -o sd) == "sd" ]]
then
	efi_part=$(echo $disk_selected'1')
	luks_part=$(echo $disk_selected'2')
fi
if [[ $(echo $disk_selected | grep -o nvme) == "nvme" ]]
then
	efi_part=$(echo $disk_selected'p1')
	luks_part=$(echo $disk_selected'p2')

fi

wipefs -aq $disk_selected

printf 'label: gpt\n, %s, U, *\n, , L\n' "$efi_part_size" | sfdisk "$disk_selected" #-q

echo $luks_pw | cryptsetup -q luksFormat --type luks1 $luks_part #-q

echo $luks_pw | cryptsetup luksOpen $luks_part $hostname #-q

echo -e "\npress enter\n"
read tmp

vgcreate $hostname /dev/mapper/$hostname #-q

lvcreate --name root -L $root_part_size $hostname #-q
lvcreate --name swap -L $swap_size $hostname
lvcreate --name home -l 100%FREE $hostname

mkfs.$fs_type -L root /dev/$hostname/root #-q
mkfs.$fs_type -L home /dev/$hostname/home
mkswap /dev/$hostname/swap

echo -e "\npress enter\n"
read tmp

mount /dev/$hostname/root /mnt
for dir in dev proc sys run; do mkdir -p /mnt/$dir ; mount --rbind /$dir /mnt/$dir ; mount --make-rslave /mnt/$dir ; done
mkdir -p /mnt/home
mount /dev/$hostname/home /mnt/home

mkfs.vfat $efi_part #-q
mkdir -p /mnt/boot/efi
mount $efi_part /mnt/boot/efi

echo y | xbps-install -Sy -R https://alpha.de.repo.voidlinux.org/current/$libc -r /mnt base-system cryptsetup grub-x86_64-efi lvm2

echo -e "\npress enter\n"
read tmp

luks_uuid=$(blkid -o value -s UUID $luks_part)


sudo cp /etc/resolv.conf /mnt/etc/



echo '#!/bin/bash' > /mnt/chrootSetup.bash
echo -e "root_pw=\"$root_pw\"" >> /mnt/chrootSetup.bash
echo -e "hostname=\"$hostname\"" >> /mnt/chrootSetup.bash
echo -e "fs_type=\"$fs_type\"" >> /mnt/chrootSetup.bash
echo -e "language=\"$language\"" >> /mnt/chrootSetup.bash
echo -e "efi_part=\"$efi_part\"" >> /mnt/chrootSetup.bash
#echo -e "luks_uuid=\"$luks_UUID\"" >> /mnt/chrootSetup.bash
echo -e "luks_pw=\"$luks_pw\"" >> /mnt/chrootSetup.bash
echo -e "luks_part=\"$luks_part\"" >> /mnt/chrootSetup.bash
echo -e "disk_selected=\"$disk_selected\"" >> /mnt/chrootSetup.bash
echo -e "username=\"$username\"" >> /mnt/chrootSetup.bash
echo -e "user_pw=\"$user_pw\"" >> /mnt/chrootSetup.bash
echo -e "luks_uuid=\"$luks_uuid\"" >> /mnt/chrootSetup.bash

echo '
chown root:root /
chmod 755 /
echo -e "$root_pw\n$root_pw" | passwd -q root
echo $hostname > /etc/hostname
echo "LANG=$language" > /etc/locale.conf
# echo "en_US.UTF-8 UTF-8" >> /etc/default/libc-locales
# xbps-reconfigure -f glibc-locales

#luks_uuid=$(blkid -o value -s UUID $luks_part)

#echo -e "# <file system>	<dir>	<type>	<options>	<dump>	<pass>" > /etc/fstab
#echo -e "tmpfs	/tmp	tmpfs	defaults,nosuid,nodev	0	0" >> /etc/fstab
echo -e "/dev/$hostname/root	/	$fs_type	defaults	0	0" >> /etc/fstab
echo -e "/dev/$hostname/home	/home	$fs_type	defaults	0	0" >> /etc/fstab
echo -e "/dev/$hostname/swap	swap	swap	defaults	0	0" >> /etc/fstab
echo -e "$efi_part	/boot/efi	vfat	defaults	0	0" >> /etc/fstab

echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub

sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"rd.lvm.vg=$hostname rd.luks.uuid=$luks_uuid apparmor=1 security=apparmor /" /etc/default/grub


dd bs=1 count=64 if=/dev/urandom of=/boot/volume.key

echo $luks_pw | cryptsetup -q luksAddKey $luks_part /boot/volume.key #-q

chmod 000 /boot/volume.key
chmod -R g-rwx,o-rwx /boot

echo "$hostname	$luks_part	/boot/volume.key	luks" >> /etc/crypttab

echo -e "install_items+=\" /boot/volume.key /etc/crypttab \"" > /etc/dracut.conf.d/10-crypt.conf



grub-install $disk_selected


xbps-reconfigure -fa
useradd $username
usermod -aG wheel $username
echo -e "$user_pw\n$user_pw" | passwd $username
sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /etc/sudoers
' >> /mnt/chrootSetup.bash

#Edit emptty config file
tty=2
sudo sed -i "s/^#*TTY_NUMBER=[0-9]*/TTY_NUMBER=$tty/i" /mnt/etc/emptty/conf
sudo sed -i "s/^#*DEFAULT_USER=/DEFAULT_USER=$user_name/i" /mnt/etc/emptty/conf
  
#Disable services
for service in ${rm_services[@]}
do
	sudo rm /var/service/$service
done
  
#Enable services
for service in ${en_services[@]}
do
	sudo ln -s /etc/sv/$service /var/service/
done 

#Enable SSD trim

#Enable AppArmor

#Firewall setup

#Enable numlock on startup
	#echo 'INITTY=/dev/tty[1-2]; for tty in $INITTY; do setleds -D +num < $tty; done' >> /etc/rc.conf

# chroot /mnt bash chrootSetup.bash
# rm /mnt/chrootSetup.bash

# exit
# umount -R /mnt
# reboot


## services running on live image: NetworkManager acpid dbus elogind lxdm polkitd rtkit sshd udevd uuidd dhcpcd
## default user groups when using void-installer: wheel floppy cdrom optical audio video kvm xbuilder
