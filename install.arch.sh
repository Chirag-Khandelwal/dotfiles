#!/usr/bin/env bash

HOSTNAME="<hostname>"
BOOT_DRIVE="/dev/sda"
KERNEL_VARIANT="-lts" # suffix of the desired linux kernel variant; empty to get default
NETWORK_DEVICE="en*" # used to setup systemd-networkd and DHCP - makes sure network is reconnected correctly if router goes down
TIMEZONE="America/Vancouver"
LOCALE="en_US.UTF-8"
USERNAME="<username>"
FULLNAME="<Full Name>"
PASSWORD="<a-super-secure-password-here>"
SSH_KEY="<a public SSH key which will be used to login with the newly created account>"

set -e

echo -e "\e[95m\e[1m==>> Updating timedatectl to use ntp ...\e[0m"
timedatectl set-ntp true

echo -e "\e[95m\e[1m==>> Wiping disk: $BOOT_DRIVE ...\e[0m"
wipefs -a -f ${BOOT_DRIVE}

echo -e "\e[95m\e[1m==>> Setting up boot and root partitions in $BOOT_DRIVE ...\e[0m"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:boot ${BOOT_DRIVE}
sgdisk -n 2:0:0 -t 2:8300 -c 2:root ${BOOT_DRIVE}

echo -e "\e[95m\e[1m==>> The partition table is as follows:\e[0m"
sgdisk -p ${BOOT_DRIVE}

echo -e "\e[95m\e[1m==>> Creating partitions:\e[0m"
echo -e "\e[95m\e[1m====>> boot ...\e[0m"
mkfs.fat -F32 "${BOOT_DRIVE}1"
echo -e "\e[95m\e[1m====>> root ...\e[0m"
mkfs.ext4 -F "${BOOT_DRIVE}2"

echo -e "\e[95m\e[1m==>> Mounting boot and root partitions ...\e[0m"
mount "${BOOT_DRIVE}2" /mnt
mkdir /mnt/boot
mount "${BOOT_DRIVE}1" /mnt/boot

echo -e "\e[95m\e[1m==>> Bootstrapping the partitions using pacstrap ...\e[0m"
sed -i "s/#ParallelDownloads = [0-9]\+/ParallelDownloads = $(nproc)/g" /etc/pacman.conf
pacstrap -K /mnt base base-devel linux$KERNEL_VARIANT linux$KERNEL_VARIANT-headers linux-firmware dkms zsh fish neofetch neovim less bat openssh git ccache keychain eza

echo -e "\e[95m\e[1m==>> Generating mountpoints in fstab using genfstab ...\e[0m"
genfstab -U /mnt >> /mnt/etc/fstab

echo -e "\e[95m\e[1m==>> Performing chroot commands ...\e[0m"
arch-chroot /mnt /bin/bash <<EOF
echo -e "\e[95m\e[1m====>> Seting timezone ...\e[0m"
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

echo -e "\e[95m\e[1m====>> Generating /etc/adjtime ...\e[0m"
hwclock --systohc

echo -e "\e[95m\e[1m====>> Setting locale to $LOCALE ...\e[0m"
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo -e "\e[95m\e[1m====>> Setting hostname as: $HOSTNAME ...\e[0m"
echo "$HOSTNAME" > /etc/hostname

echo -e "\e[95m\e[1m====>> Running mkinitcpio ...\e[0m"
mkinitcpio -P

echo -e "\e[95m\e[1m====>> Installing systemd-boot bootloader ...\e[0m"
bootctl install
(
echo "default $HOSTNAME";
echo "timeout 2";
echo "editor no";
) > /boot/loader/loader.conf
ROOTUUID=$(lsblk -dno UUID ${BOOT_DRIVE}2)
(
echo "title	$HOSTNAME";
echo "linux	/vmlinuz-linux$KERNEL_VARIANT";
echo "initrd	/initramfs-linux$KERNEL_VARIANT.img";
echo "options	root=UUID=\$ROOTUUID rw";
) > /boot/loader/entries/$HOSTNAME.conf

echo -e "\e[95m\e[1m====>> Setting up vimrc for root ...\e[0m"
curl -sL https://raw.githubusercontent.com/Electrux/dotfiles/main/dotvimrc > /root/.vimrc
mkdir -p /root/.config/nvim
cp /root/.vimrc /root/.config/nvim/init.vim

echo -e "\e[95m\e[1m====>> Creating admin user $USERNAME ...\e[0m"
useradd -mG wheel -s /bin/zsh -c "$FULLNAME" $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

echo -e "\e[95m\e[1m====>> Setting up $USERNAME's shell and vim config ...\e[0m"

echo -e "\e[95m\e[1m======>> Setting up zsh shell ...\e[0m"
curl -sL https://raw.githubusercontent.com/Electrux/dotfiles/main/dotzshrc > /home/$USERNAME/.zshrc
# chown is done after vimrc
echo -e "\e[95m\e[1m======>> Setting up fish shell ...\e[0m"
mkdir -p /home/$USERNAME/.config/fish/functions
curl -sL https://raw.githubusercontent.com/Electrux/dotfiles/main/fish_functions/l.fish > /home/$USERNAME/.config/fish/functions/l.fish
curl -sL https://raw.githubusercontent.com/Electrux/dotfiles/main/fish_functions/t.fish > /home/$USERNAME/.config/fish/functions/t.fish
curl -sL https://raw.githubusercontent.com/Electrux/dotfiles/main/fish_functions/ccd.fish > /home/$USERNAME/.config/fish/functions/ccd.fish
curl -sL https://raw.githubusercontent.com/Electrux/dotfiles/main/config.fish > /home/$USERNAME/.config/fish/config.fish
# chown is done after vimrc
echo -e "\e[95m\e[1m======>> Setting up (n)vimrc ...\e[0m"
mkdir -p /home/$USERNAME/.config/nvim
curl -sL https://raw.githubusercontent.com/Electrux/dotfiles/main/dotvimrc > /home/$USERNAME/.vimrc
cp /home/$USERNAME/.vimrc /home/$USERNAME/.config/nvim/init.vim
chown -R $USERNAME:$USERNAME /home/$USERNAME/.zshrc /home/$USERNAME/.config /home/$USERNAME/.vimrc

echo -e "\e[95m\e[1m====>> Enabling no password sudo for users in wheel group ...\e[0m"
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel-nopasswd

echo -e "\e[95m\e[1m====>> Setting up DHCP network ...\e[0m"
(
echo "[Match]";
echo "Name=$NETWORK_DEVICE";
echo "";
echo "[Link]";
echo "RequiredForOnline=routable";
echo "";
echo "[Network]";
echo "DHCP=yes";
) > /etc/systemd/network/01-dhcp.network
systemctl enable systemd-networkd systemd-resolved

echo -e "\e[95m\e[1m====>> Setting up ssh server with authentication key login ...\e[0m"
mkdir -p /home/$USERNAME/.ssh
echo "$SSH_KEY" > /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
chmod 0600 /home/$USERNAME/.ssh/authorized_keys
systemctl enable sshd

echo -e "\e[95m\e[1m====>> Setting up git global user and email configuration ...\e[0m"
su $USERNAME -c 'git config --global user.name "$FULLNAME"'
su $USERNAME -c 'git config --global user.email "$USERNAME@$HOSTNAME"'

echo -e "\e[95m\e[1m====>> Setting up AUR Helper: paru ...\e[0m"
su $USERNAME -c 'cd && git clone https://aur.archlinux.org/paru-bin.git && cd paru-bin && makepkg -si --needed --noconfirm --nocheck --noprepare && cd .. && rm -r paru-bin'

EOF

echo -e "\e[95m\e[1m==>> Link /etc/resolv.conf to systemd-resolved's stub ...\e[0m"
ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

echo -e "\e[95m\e[1m==>> Installation Finished!!!\e[0m"
