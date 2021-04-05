#!/bin/bash

efi_part_size="260M"		#Minimum of 100M, Arch wiki recommends at least 260M (as of 24-Mar-2021)
root_part_size="20G"		#Size of the root partition. Required size depends on how much software you ultimately install, but Arch wiki recommends 15-20G (as of 24-Mar-2021)
swap_size="4G"			#If you want to use suspend-to-disk (AKA hibernate), should be >= amount of RAM.
				#Otherwise, equal to square root of RAM (rounded up), or at least 2G
username="user"			#Desired username for regular (non-root) user of the Void installation you're making
hostname="desktop"		#Desired name to be used for the hostname of the Void installation as well as the volume group name
fs_type="ext4"			#Desired filesystem to be used for the root and home partitions
libc="musl" 			#"musl" for musl, "" for glibc
language="en_US.UTF-8"
vendor_cpu="intel"		#Enter either "amd" or "intel" (all lowercase). This script assumes you're installing on an x86_64 system
vendor_gpu="amd"		#Enter either "amd", "intel", or "nvidia" (all lowercase)
				#For AMD will install the OpenGL and Vulkan driver (mesa, not amdvlk), as well as the video acceration drivers. Does not install the Xorg drivers, you must install the separately if you want to use Xorg
				#For Intel this installs OpenGL and Vulkan drivers, and video acceleration drivers
				#For Nvidia this installs the proprietary driver. It assumes you're using a non-legacy GPU, which generally means any Geforce 600 or newer GTX card (some of the low end GT cards from 600, 700, and 800 series are legacy) 
graphical_de="xfce"		#"xfce" for the standard XFCE install that you would get if you install using the XFCE live image
                        	#Or "kde" for a 'minimal' KDE Plasma install with Wayland
                        	#Leave black (just double quotes, "") to not install DE. Will skip graphics driver installation as well
void_repo="https://alpha.us.repo.voidlinux.org/"
apps="nano flatpak elogind dbus alsa-utils apparmor ufw cronie ntp rclone RcloneBrowser firefox"
rm_services=("agetty-tty2" "agetty-tty3" "agetty-tty4" "agetty-tty5" "agetty-tty6" "mdadm" "sshd" "acpid" "NetworkManager")
en_services=("dbus" "elogind" "dhcpcd" "emptty" "ufw" "cronie" "ntpd")
user_groups="wheel" #floppy,cdrom,optical,audio,video,kvm,xbuilder


declare apps_intel_cpu="intel-ucode"
declare apps_amd_cpu="linux-firmware-amd"
declare apps_amd_gpu="linux-firmware-amd mesa-dri vulkan-loader mesa-vulkan-radeon mesa-vaapi mesa-vdpau xf86-video-amdgpu"
declare apps_intel_gpu="linux-firmware-intel mesa-dri mesa-vulkan-intel intel-video-accel xf86-video-intel"
declare apps_nvidia_gpu="nvidia"
declare apps_kde="emptty plasma-workspace konsole kcron pulseaudio ark plasma-pa plasma-firewall dolphin" #plasma-nm NetworkManager
declare apps_xfce="xorg-minimal xorg-fonts xterm lightdm lightdm-gtk3-greeter xfce4"
declare luks_pw root_pw user_pw disk_selected


case $vendor_cpu in
    "amd")
        apps="$apps $apps_amd_cpu"
        ;;
    "intel")
        apps="$apps $apps_intel_cpu"
        ;;
esac

if [[ -n $graphical_de ]]
then
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


echo -e "\nEnter password to be used for disk encryption\n"
read luks_pw

echo -e "\nEnter password to be used for the root user\n"
read root_pw

echo -e "\nEnter password to be used for the user account\n"
read user_pw

PS3="Select disk for installation: "
select line in $(fdisk -l | grep -v mapper | grep -o '/.*GiB' | tr -d ' ')
do
        echo "Selected disk: $line"
        disk_selected=$(echo $line | sed 's/:.*$//')
        break
done


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

printf 'label: gpt\n, %s, U, *\n, , L\n' "$efi_part_size" | sfdisk -q "$disk_selected"

echo $luks_pw | cryptsetup -q luksFormat --type luks1 $luks_part

echo $luks_pw | cryptsetup -q luksOpen $luks_part $hostname


vgcreate -q $hostname /dev/mapper/$hostname

lvcreate --name root -qL $root_part_size $hostname
lvcreate --name swap -qL $swap_size $hostname
lvcreate --name home -ql 100%FREE $hostname

mkfs.$fs_type -qL root /dev/$hostname/root
mkfs.$fs_type -qL home /dev/$hostname/home
mkswap /dev/$hostname/swap

mount /dev/$hostname/root /mnt
for dir in dev proc sys run; do mkdir -p /mnt/$dir ; mount --rbind /$dir /mnt/$dir ; mount --make-rslave /mnt/$dir ; done
mkdir -p /mnt/home
mount /dev/$hostname/home /mnt/home

mkfs.vfat -q $efi_part
mkdir -p /mnt/boot/efi
mount $efi_part /mnt/boot/efi

echo y | xbps-install -Sy -R https://alpha.de.repo.voidlinux.org/current/$libc -r /mnt base-system cryptsetup grub-x86_64-efi lvm2


luks_uuid=$(blkid -o value -s UUID $luks_part)


cp /etc/resolv.conf /mnt/etc/

echo "Press any key\n"
read tmp


chroot /mnt chown root:root /
chroot /mnt chmod 755 /

echo $hostname > /mnt/etc/hostname
echo "LANG=$language" > /mnt/etc/locale.conf

if [[ -z $libc ]]
then
    echo "en_US.UTF-8 UTF-8" >> /mnt/etc/default/libc-locales
    xbps-reconfigure -r /mnt/ -f glibc-locales
fi

echo -e "/dev/$hostname/root	/	$fs_type	defaults	0	0" >> /mnt/etc/fstab
echo -e "/dev/$hostname/home	/home	$fs_type	defaults	0	0" >> /mnt/etc/fstab
echo -e "/dev/$hostname/swap	swap	swap	defaults	0	0" >> /mnt/etc/fstab
echo -e "$efi_part	/boot/efi	vfat	defaults	0	0" >> /mnt/etc/fstab

echo "GRUB_ENABLE_CRYPTODISK=y" >> /mnt/etc/default/grub

sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"rd.lvm.vg=$hostname rd.luks.uuid=$luks_uuid rd.luks.allow-discards apparmor=1 security=apparmor /" /mnt/etc/default/grub


dd bs=1 count=64 if=/dev/urandom of=/mnt/boot/volume.key

cat << EOF | chroot /mnt
echo "$root_pw\n$root_pw" | passwd -q root
echo $luks_pw | cryptsetup -q luksAddKey $luks_part /boot/volume.key
useradd $username
usermod -aG wheel $username
echo "$user_pw\n$user_pw" | passwd -q $username
EOF

chroot /mnt chmod 000 /boot/volume.key
chroot /mnt chmod -R g-rwx,o-rwx /boot

echo "$hostname	$luks_part	/boot/volume.key	luks" >> /mnt/etc/crypttab

echo -e "install_items+=\" /boot/volume.key /etc/crypttab \"" > /mnt/etc/dracut.conf.d/10-crypt.conf



chroot /mnt grub-install $disk_selected


xbps-reconfigure -r /mnt/ -fa

sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /mnt/etc/sudoers
echo "Defaults editor=/usr/bin/nano" >> /mnt/etc/sudoers

xbps-install -Suyr /mnt xbps

if [[ $vendor_gpu == "nvidia" ]] || [[ $vendor_cpu == "intel" ]]
then
    xbps-install -Syr /mnt/ void-repo-nonfree
fi

xbps-install -Syr /mnt $apps
  
#Disable services
for service in ${rm_services[@]}
do
	sudo rm /etc/runit/runsvdir/default/$service
done
  
#Enable services
for service in ${en_services[@]}
do
	sudo ln -s /etc/sv/$service /etc/runit/runsvdir/default/
done 

sed -i 's/^#*APPARMOR=.*$/APPARMOR=complain/i' /mnt/etc/default/apparmor


#Edit emptty config file
tty=2
sed -i "s/^#*TTY_NUMBER=[0-9]*/TTY_NUMBER=$tty/i" /mnt/etc/emptty/conf
sed -i "s/^#*DEFAULT_USER=/DEFAULT_USER=$user_name/i" /mnt/etc/emptty/conf

#Enable SSD trim

#Enable AppArmor

#Firewall setup

#Enable numlock on startup
echo 'INITTY=/dev/tty[1-2]; for tty in $INITTY; do setleds -D +num < $tty; done' >> /mnt/etc/rc.conf

mkdir -p /mnt/etc/xbps.d
cp /mnt/usr/share/xbps.d/*-repository-*.conf /mnt/etc/xbps.d/
sed -i "s|https://alpha.de.repo.voidlinux.org|$void_repo|g" /etc/xbps.d/*-repository-*.conf

# chroot /mnt bash chrootSetup.bash
# rm /mnt/chrootSetup.bash

# exit
# umount -R /mnt
# vgchange -an #hostname
# cryptsetup luksClose $hostname
# reboot


## services running on live image: NetworkManager acpid dbus elogind lxdm polkitd rtkit sshd udevd uuidd dhcpcd
## default user groups when using void-installer: wheel floppy cdrom optical audio video kvm xbuilder
