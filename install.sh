#!/usr/bin/env bash

source colors.sh


  
echo -e "\n${BOL_GRE}Select the mirrors${END}"
sleep 1s
  pacman -Syyy --noconfirm
  pacman -S --noconfirm reflector
  #reflector --latest 40  --protocol https --sort rate --save /etc/pacman.d/mirrorlist
  #reflector -c BR --sort rate -a 6 --save /etc/pacman.d/mirrorlist
  reflector --country Brazil   --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
  echo -e "\n${BOL_BLU}Mirror selection completed${END}"
  pacman -Syyy --noconfirm
    
    
echo -e "\n${BOL_GRE}Update the system clock${END}"
sleep 1s
  timedatectl set-ntp true
  timedatectl status
  



read -r -p "${BOL_GRE}You username? ${MAG}enter=${CYA}mamutal91${END}" USERNAME
[[ -z $USERNAME ]] && USERNAME=mamutal91 || USERNAME=$USERNAME
echo -e "  ${YEL}$USERNAME${END}\n"
read -r -p "${BOL_GRE}You hostname? ${MAG}enter=${CYA}odin${END}" HOSTNAME
[[ -z $HOSTNAME ]] && HOSTNAME=odin || HOSTNAME=$HOSTNAME
echo -e "  ${YEL}$HOSTNAME${END}\n"

if [[ $USERNAME == mamutal91 ]]; then
  SSD=/dev/nvme0n1 # ssd m2 nvme
  SSD1=/dev/nvme0n1p1 # EFI (boot)
  SSD2=/dev/nvme0n1p2 # cryptswap
  SSD3=/dev/nvme0n1p3 # cryptsystem
  # Use este
#  SSD=/dev/sda # ssd m2
#  SSD1=/dev/sda1 # EFI (boot)
#  SSD2=/dev/sda2 # cryptswap
#  SSD3=/dev/sda3 # cryptsystem
else
  echo -e "Specify disks!!!
  Examples:\n\n
  SSD=/dev/nvme0n1 # ssd m2 nvme
  SSD1=/dev/nvme0n1p1 # EFI (boot)
  SSD2=/dev/nvme0n1p2 # cryptswap
  SSD3=/dev/nvme0n1p3 # cryptsystem
  STORAGE_NVME=/dev/sdb # ssd
  STORAGE_HDD=/dev/sda # hdd"
  exit 0
fi

}

selectDisk() {
  echo -e "\n${BOL_GRE}Selecionando o disco para instatalçao: sda,sbc,nvme0n1 ${END}"
  sleep 0.5s
  	# Selecting the target for the installation.
	PS3="Select the disk where Arch Linux is going to be installed: "
	select ENTRY in $(lsblk -dpnoNAME|grep -P "/dev/sd|nvme|vd");
	do
    		DISK=$ENTRY
    		echo "Installing Arch Linux on $DISK."
    		break
	done
}


deletionPartition_scheme_old(){
  echo -e "\n${BOL_RED}Deleting old partition scheme${END}"
  sleep 0.5s
	read -r -p "This will delete the current partition table on $DISK. Do you agree [y/N]? " response
	response=${response,,}
	if [[ "$response" =~ ^(yes|y)$ ]]; then
    		wipefs -af "$DISK" &>/dev/null
    		sgdisk -Zo "$DISK" &>/dev/null
	else
    		echo "Quitting."
    		exit
	fi
}


create_GPTorMBR(){
  echo -e "\n${BOL_RED}Create a GPT or MBR partition${END}"
	read -r -p "Do you want to create a GPT or MBR partition table? (Type gpt or mbr) " part_type
	if [[ "$part_type" = "gpt" ]]; then
    		part_type_flag="gpt"
	elif [[ "$part_type" = "mbr" ]]; then
    		part_type_flag="msdos"
	else
    		echo "Invalid option. Exiting script."
   		exit
	fi
}

createNew_partition_scheme(){
  echo -e "\n${BOL_MAG}Criando duas partiçoes, uma de boot de 512MiB e a Raiz / com o restante do espaço${END}"
	# Creating a new partition scheme.
	echo "Creating new $part_type partition scheme on $DISK."
	# Ask for partition name
        read -r -p "Enter Root partition name: " PARTNAME
	parted -s "$DISK" \
    	mklabel $part_type_flag \
    	mkpart ESP 1MiB 512MiB name 1 boot \
    	set 1 esp on \
    	mkpart BTRFS 512MiB 100% name 2 $PARTNAME \
    
	sleep 0.1
	ESP="/dev/$(lsblk $DISK -o NAME,PARTLABEL | grep boot | cut -d " " -f1 | cut -c7-)"
	echo "Partition boot: ${ESP}"
	sleep 1s
	
	BTRFS="/dev/$(lsblk $DISK -o NAME,PARTLABEL | grep archlinux | cut -d " " -f1 | cut -c7-)"
	echo "Partition Root: $BTRFS"
	sleep 1s
	
	# Informing the Kernel of the changes.
	echo "Informing the Kernel about the disk changes."
	sleep 1s
	partprobe "$DISK"

}

verifyBoot_mode() {
  # Formatting the ESP as FAT32.
  
  echo -e "\n${BOL_GRE}Verify the boot mode${END}"
  sleep 1s
  	if [ -d /sys/firmware/efi ]; then
	  	BIOS_TYPE="uefi"
    		echo -e "\n${BOL_BLU}Install UEFI MODE${END}"
    		sleep 1s
	  
  	else
	  	BIOS_TYPE="bios"
   	 	echo -e "\n${BOL_BLU}Install BIOS LEGACY MODE${END}"
    		sleep 1s
 	 fi
formatting_UEFI_BIOS() {
echo -e "\n${BOL_YEL}Formatting the EFI Partition as FAT32 or BIOS as${END}"

	if [ "$BIOS_TYPE" == "uefi" ]; then
		mkfs.fat -F32 "$ESP"
	fi
	
	if [ "$BIOS_TYPE" == "bios" ]; then
		mkfs.ext4 "$ESP"
	fi
}
		
	if [ "$BIOS_TYPE" == "uefi" ]; then
		mkdir -p /mnt/boot/efi
		mount "$ESP" /mnt/boot/efi
	fi
	
	if [ "$BIOS_TYPE" == "bios" ]; then
		mkdir -p /mnt/boot
		mount "$ESP" /mnt/boot
	fi





encryptSystem() {
  echo -e "\n${BOL_GRE}Criptografando partição principal - $SSD3 ${END}"
  cryptsetup luksFormat --align-payload=8192 -s 256 -c aes-xts-plain64 $SSD3
}

unlockDisk() {
  echo -e "\n${BOL_GRE}Destravando partição principal - $SSD3 ${END}"
  cryptsetup open /dev/disk/by-partlabel/cryptsystem system
}

unlockSwap() {
  echo -e "\n${BOL_GRE}Destravando partição swap - $SSD2 ${END}"
  cryptsetup open --type plain --key-file /dev/urandom /dev/disk/by-partlabel/cryptswap swap
}

formatSwap() {
  echo -e "\n${BOL_GRE}Formatando e ativando partições swap - $SSD2 ${END}"
  mkswap -L swap /dev/mapper/swap
  swapon -L swap
}

formatPartitions() {
  echo -e "\n${BOL_GRE}Formatando EFI e $SSD${END}"
  mkfs.fat -F32 -n EFI /dev/disk/by-partlabel/EFI
  mkfs.btrfs --force --label system /dev/mapper/system
}

createSubVolumesBtrfs() {
  echo -e "\n${BOL_GRE}Criando volumes${END}"
  mount -t btrfs LABEL=system /mnt
  btrfs subvolume create /mnt/root
  btrfs subvolume create /mnt/home
  btrfs subvolume create /mnt/snapshots
}

mountPartitions() {
  echo -e "\n${BOL_GRE}Montando volumes${END}"
  o="defaults,x-mount.mkdir"
  o_btrfs="$o,noatime,compress-force=zstd,commit=120,space_cache=v2,ssd"
  umount -R /mnt
  mount -t btrfs -o subvol=root,$o_btrfs LABEL=system /mnt
  mount -t btrfs -o subvol=home,$o_btrfs LABEL=system /mnt/home
  mount -t btrfs -o subvol=snapshots,$o_btrfs LABEL=system /mnt/snapshots
  mkdir -p /mnt/boot
  mount $SSD1 /mnt/boot
}

reflectorMirrors() {
  echo -e "\n${BOL_GRE}Instalando reflector para obter melhores mirrors${END}"
  pacman -Sy reflector --noconfirm --needed
  reflector --verbose --sort rate -l 5 --save /etc/pacman.d/mirrorlist
  sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
  sed -i 's/#UseSyslog/UseSyslog/' /etc/pacman.conf
  sed -i 's/#Color/Color\\\nILoveCandy/' /etc/pacman.conf
  sed -i 's/Color\\/Color/' /etc/pacman.conf
  sed -i 's/#TotalDownload/TotalDownload/' /etc/pacman.conf
  sed -i 's/#CheckSpace/CheckSpace/' /etc/pacman.conf
  sed -i "s/#VerbosePkgLists/VerbosePkgLists/g" /etc/pacman.conf
  sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 20/g" /etc/pacman.conf
}

pacstrapInstall() {
  pacman -Sy archlinux-keyring git --noconfirm --needed
  pacstrap /mnt --noconfirm \
    base base-devel bash-completion archlinux-keyring \
    linux-lts linux-lts-headers linux linux-headers \
    linux-hardened linux-hardened-headers \
    linux-firmware linux-firmware-whence \
    mkinitcpio pacman-contrib archiso git \
    linux-api-headers util-linux util-linux-libs lib32-util-linux \
    btrfs-progs efibootmgr efitools gptfdisk grub grub-btrfs \
    iwd networkmanager dhcpcd sudo nano reflector openssh git curl wget zsh \
    alsa-firmware alsa-utils alsa-plugins pulseaudio pulseaudio-bluetooth pavucontrol \
    sox bluez bluez-libs bluez-tools bluez-utils feh rofi dunst picom \
    stow nano nano-syntax-highlighting neofetch vlc gpicview zsh zsh-syntax-highlighting maim ffmpeg \
    imagemagick slop terminus-font noto-fonts-emoji ttf-dejavu ttf-liberation \
    xorg-server xorg-xrandr xorg-xbacklight xorg-xinit xorg-xprop xorg-server-devel xorg-xsetroot xclip xsel xautolock xorg-xdpyinfo xorg-xinput \
    i3-gaps i3lock alacritty thunar thunar-archive-plugin thunar-media-tags-plugin thunar-volman telegram-desktop
}

genfstabGenerator() {
  genfstab -L -p /mnt >> /mnt/etc/fstab
  sed -i "s+LABEL=swap+/dev/mapper/cryptswap+" /mnt/etc/fstab
}

cryptswapAdd() {
  echo "cryptswap $SSD2 /dev/urandom swap,offset=2048,cipher=aes-xts-plain64,size=256" >> /mnt/etc/crypttab
}

copyWifi() {
  mkdir -p /mnt/var/lib/iwd
  chmod 700 /mnt/var/lib/iwd
  cp -rf /var/lib/iwd/*.psk /mnt/var/lib/iwd
}

chrootPrepare() {
  sed -i "2i USERNAME=${USERNAME}" configure.sh
  sed -i "3i HOSTNAME=${HOSTNAME}" configure.sh
  sed -i "4i SSD2=${SSD2}" configure.sh
  sed -i "5i SSD3=${SSD3}" configure.sh
  chmod +x colors.sh && cp -rf colors.sh /mnt
  chmod +x configure.sh && cp -rf configure.sh /mnt && clear && sleep 5
  arch-chroot /mnt ./configure.sh
  if [[ $? -eq 0 ]]; then
    echo -e "\n\nFinished SUCCESS\n"
    read -r -p "Reboot now? [Y/n]" confirmReboot
    if [[ ! $confirmReboot =~ ^(n|N) ]]; then
      umount -R /mnt
      systemctl reboot
    else
      arch-chroot /mnt
    fi
  else
    echo "${BOL_RED}Failed!!!${END}"
    exit 1
  fi
}

recovery() {
  unlockDisk
  unlockSwap
  formatSwap
  mountPartitions
  sleep 5
  arch-chroot /mnt
}

run() {
  selectDisk
  deletionPartition_scheme_old
  create_GPTorMBR
  createNew_partition_scheme
  verifyBoot_mode
  formatting_UEFI_BIOS
  
  
  
  formatDrive
  encryptSystem
  unlockDisk
  unlockSwap
  formatSwap
  formatPartitions
  createSubVolumesBtrfs
  mountPartitions
  reflectorMirrors
  pacstrapInstall
  genfstabGenerator
  cryptswapAdd
  copyWifi
  chrootPrepare
}

if [[ ${1} == "recovery" ]]; then
  recovery
else
  echo -e "\n${BOL_BLU}Iniciando instalação do ArchLinux${END}"
  run "$@" || echo "$@ falhou" && exit
fi
