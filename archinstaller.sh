#!/bin/bash
#|---/ /+--------------------------+---/ /|#
#|--/ /-| Main installation script |--/ /-|#
#|-/ /--|     HK - AXL - CODER     |-/ /--|#
#|/ /---+--------------------------+/ /---|#

# Arch Linux installation
#
# Bootable USB:
# - [Download](https://archlinux.org/download/) ISO and GPG files
# - Verify the ISO file: `$ pacman-key -v archlinux-<version>-dual.iso.sig`
# - Create a bootable USB with: `# dd if=archlinux*.iso of=/dev/sdX && sync`
#
# UEFI setup:
#
# - Set boot mode to UEFI, disable Legacy mode entirely.
# - Temporarily disable Secure Boot.
# - Make sure a strong UEFI administrator password is set.
# - Delete preloaded OEM keys for Secure Boot, allow custom ones.
# - Set SATA operation to AHCI mode.
#
# Run installation:
#
# - Connect to wifi via: `# iwctl station wlan0 connect WIFI-NETWORK`

starter() {
  cat <<"EOF"

----------------------------------------------------------------------------------------------

        .
       / \         _       _  _                  _     _
      / ^ \      _| |_    | || |_  _ _ __ _ _ __| |___| |_ ___
     /  _  \    |_   _|   | __ | || | '_ \ '_/ _` / _ \  _(_-<
    /  | | ~\     |_|     |_||_|\_, | .__/_| \__,_\___/\__/__/
   /.-'   '-.\                  |__/|_|

 _   _                ..
| | | | ___  __      /  \   __  __ ___         ____    ___   ______   _________  ________
| | | | | | / /     /    \  \ \/ / | |        / /     // \\  | | \ \  | |-----'  | |  \ \
| <=> | | |/_/_ <> /  ^^  \  |  |  | |___ <> | |     ||<=>|| | |  | | | |<==>_.  | |   \ \
| | | | |_|  |_|  /   ||   \/_/\_\ |_____|   | |      \\_//  |_|_/_/  |_|_____|  | |<==>\_\
| | | |          /   /  \   \                | |   _                             | |  \ \
|_| |_|         /..-'    '-..\                \_\__))                            |_|   \_\


#####################:= Welcome to HK-AXL-CODER's arch installer script =:####################

----------------------------------------------------------------------------------------------
EOF
}
starter

# set a value of shell options
# -u := treat unset variable as an error
# -o (option name) := set value corresponding to option name
pipefail := the return value of a pipeline is the status of the last command to exit with a non zero status
set -uo pipefail

#trap := trap signal and other events
trap 'echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $?' ERR

# exec := replace shell with the given command
# tee := copy standard input to each FILE, and to standard output
exec 1> >(tee "stdout.log")
exec 2> >(tee "stderr.log" >&2)

echo -e "\n:=> Checking UEFI boot mode </=:"
if [ ! -f /sys/firmware/efi/fw_platform_size ]; then
  echo >&2"You must boot in UEFI mode to continue"
  exit 2
else
  echo "Your good to go!"
fi

echo -e"\n:=> Setting up clock </=:"
timedatectl set-ntp true
hwclock --systohc --utc

echo -e "\n:=> Listing available devices </=:"
devicelist=$(lsblk -dplnx size -o name,size | grep -Ev "boot|rpmb|loop" | tac | tr '\n' ' ')
read -r -a devicelist <<<"$devicelist"
echo -e "${devicelist[@]}"

echo -e "\n:=> Selecting the drive to use </=:"
read -r -p "Enter the drive to use(eg sda, nvme0n1): " drive
device=/dev/$drive
echo "You selected the $device device"
sleep 3

echo -e "\n:=> Partioning $device device </=:"
sleep 1
lsblk -plnx size -o name "${device}" | xargs -n1 wipefs --all
sgdisk --clear "${device}" --new 1::-551MiB "${device}" --new 2::0 --typecode 2:ef00 "${device}"
sgdisk --change-name=1:primary --change-name=2:ESP "${device}"

part_root="$(ls "${device}"* | grep -E "^${device}p?1$")"
part_boot="$(ls "${device}"* | grep -E "^${device}p?2$")"

echo -e "\n:=> Formatting partitions </=:"
sleep 1
mkfs.vfat -n "EFI" -F 32 "${part_boot}"
sleep 1
mkfs.btrfs -L BTRFS "$part_root"

echo -e "\n:=> Setting up BTRFS subvolumes </=:"
mount "$part_root" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var
btrfs subvolume create /mnt/@srv
btrfs subvolume create /mnt/@opt
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@pkgs
btrfs subvolume create /mnt/@aurbuild
btrfs subvolume create /mnt/@archbuild
btrfs subvolume create /mnt/@docker
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@swap
btrfs subvolume create /mnt/@.snapshots
umount /mnt

echo -e "\n:=> Mounting the subvolumes </=:"
mount -o noatime,nodiratime,compress=zstd,discard=async,subvol=@ "$part_root" /mnt
mkdir -p /mnt/{boot/efi,home,var/{cache/pacman,log,tmp,lib/{aurbuild,archbuild,docker}},srv,opt,swap,.snapshots}
mount "${part_boot}" /mnt/boot/efi
mount -o noatime,nodiratime,compress=zstd,discard=async,subvol=@home "$part_root" /mnt/home
mount -o noatime,nodiratime,compress=zstd,discard=async,subvol=@srv "$part_root" /mnt/srv
mount -o noatime,nodiratime,compress=zstd,discard=async,subvol=@opt "$part_root" /mnt/opt
mount -o noatime,nodiratime,compress=zstd,discard=async,subvol=@var "$part_root" /mnt/var
mount -o noatime,nodiratime,compress=zstd,discard=async,subvol=@tmp "$part_root" /mnt/var/tmp
mount -o noatime,nodiratime,compress=zstd,discard=async,subvol=@pkgs "$part_root" /mnt/var/cache/pacman
mount -o noatime,nodiratime,compress=zstd,discard=async,subvol=@aurbuild "$part_root" /mnt/var/lib/aurbuild
mount -o noatime,nodiratime,compress=zstd,discard=async,subvol=@archbuild "$part_root" /mnt/var/lib/archbuild
mount -o noatime,nodiratime,compress=zstd,discard=async,subvol=@docker "$part_root" /mnt/var/lib/docker
mount -o noatime,nodiratime,compress=zstd,discard=async,subvol=@log "$part_root" /mnt/var/log
mount -o noatime,nodiratime,compress=zstd,discard=async,subvol=@swap "$part_root" /mnt/swap
mount -o noatime,nodiratime,compress=zstd,discard=async,subvol=@.snapshots "$part_root" /mnt/.snapshots

echo -e "\n:=> Installing base packages </=:"
pacstrap -K /mnt base linux-firmware linux-headers sudo nano intel-ucode btrfs-progs

echo -e "\n:=> Generating fstab </=:"
genfstab -U /mnt >>/mnt/etc/fstab

echo -e "\n:=> chrooting to the new system </=:"
arch-chroot /mnt /bin/bash

echo -e "\n:=> Setting locales and time </=:"
ln -sf /usr/share/zoneinfo/Africa/Nairobi /etc/localtime
hwclock --systohc --utc
date
echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf

echo -e "\n:=> Setting up hostname and hosts files </=:"
read -r -p "Enter the your desired hostname:= " hostname
echo "$hostname" >/etc/hostname

echo "127.0.0.1     localhost" >>/etc/hosts
echo "::1           localhost" >>/etc/hosts
echo "127.0.0.1     $hostname.localdomain     $hostname" >>/etc/hosts

echo -e "\n:=> Setting up root password </=:"
read -r -p "Enter the root password:= " root_password
echo "root:$root_password" | chpasswd

echo -e "\n:=> Adding a regular user </=:"
read -r -p "Enter the username:= " username
useradd -m -g users -G wheel "$username"
read -r -p "Enter the password for $username:= " user_password
echo "$username:$user_password" | chpasswd

echo -e "\n:=> Adding $username to the sudo group </=:"
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers

sed -i "s/^#Color$/Color/" pacman.conf
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 10/" /etc/pacman.conf

echo -e "\n:=> Now installing grub </=:"
pacman -Sy --noconfirm --needed grub efibootmgr dosfstools
grub-install --bootloader-id=GRUB --efi-directory=/boot/efi --recheck
grub-mkconfig -o /boot/grub/grub.cfg

echo -e "\n:=> Installing additional tools </=:"
pacman -Sy --noconfirm --needed curl git reflector terminus-font dialog wget base-devel go haveged acpi acpid nss-mdns networkmanager modemmanager

echo -e "\n:=> Enabling services </=:"
systemctl enable {acpid,haveged,avahi-daemon,NetworkManager,ModemManager}

echo -e "\n:=> Installing yay aur helper </=:"
git clone https://aur.archlinux.org/yay.git ~/yay
cd ~/yay || exit
makepkg -si

echo -e "\n:=> Now installing Hyprland </=:"
git clone https://github.com/prasanthrangan/hyprdots ~/Dots
cd ~/Dots/Scripts || exit
chmod +x ./install.sh
./install.sh custom_apps.lst

echo -e "\n:=> Congrats!,the script completed successfully </=:"
