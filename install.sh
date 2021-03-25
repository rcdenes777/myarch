#!/usr/bin/env bash

function recovery() {
  echo "Unlock and mount /dev/sda2"
  cryptsetup luksOpen /dev/sda2 lvm
  wait
  mount /dev/mapper/arch-root /mnt
  wait
  arch-chroot /mnt
}

function format() {
  echo "Formatting /dev/sda2"
  cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 --use-random -i 100 /dev/sda2
  cryptsetup luksOpen /dev/sda2 lvm

  pvcreate /dev/mapper/lvm
  vgcreate arch /dev/mapper/lvm

  lvcreate -L 25G arch -n root
  lvcreate -L 8G arch -n swap
  lvcreate -l 100%FREE arch -n home

  mkfs.fat -F32 /dev/sda1
  mkfs.ext4 /dev/mapper/arch-root
  mkswap /dev/mapper/arch-swap
  mkfs.ext4 /dev/mapper/arch-home

  mount /dev/mapper/arch-root /mnt
  mkdir -p /mnt/{home,boot,hostlvm}
  mount /dev/mapper/arch-home /mnt/home
  mount /dev/sda1 /mnt/boot
  sudo swapon -va

  mount --bind /run/lvm /mnt/hostlvm

  readonly PACKAGES=(
    base base-devel bash-completion
    linux linux-headers linux-firmware
    lvm2
    mkinitcpio
    pacman-contrib
    iwd networkmanager dhcpcd sudo efibootmgr grub nano git
  )

  for i in "${PACKAGES[@]}"; do
    pacstrap /mnt ${i} --noconfirm
  done

  genfstab -U /mnt >> /mnt/etc/fstab

  read -r -p "Configure system? [Y/n]" configSystem
  if [[ ! "$configSystem" =~ ^(n|N) ]]; then
    cp -rf configSystem.sh /mnt
    arch-chroot /mnt ./configSystem.sh
  fi
}

# What to do?
if [ "${1}" = "recovery" ];
then
  recovery
else
  format
fi

# Reboot
if [[ "$?" == "0" ]]; then
  echo "Finished successfully."
  read -r -p "Reboot now? [Y/n]" confirmReboot
  if [[ ! "$confirmReboot" =~ ^(n|N) ]]; then
    reboot
  fi
fi