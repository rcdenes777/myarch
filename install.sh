#!/usr/bin/env bash

source colors.sh


echo -e "\n${BOL_GRE}Remontando cowspace com Size=3G${END}"
echo "Remontando cowspace com Size=3G"
mount -o remount,size=2G /run/archiso/cowspace
sleep 2s

echo -e "\n${BOL_GRE}Update the system clock${END}"
sleep 1s
  timedatectl set-ntp true
  timedatectl status
  
 
echo -e "\n${BOL_GRE}Checking the microcode to install${END}"
	CPU=$(grep vendor_id /proc/cpuinfo)
	if [[ $CPU == *"AuthenticAMD"* ]]; then
   	 microcode=amd-ucode
	else
    	microcode=intel-ucode
	fi

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
		sleep 3s
    		sgdisk -Zo "$DISK" &>/dev/null
		sleep 3s
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
		sleep 3s
	elif [[ "$part_type" = "mbr" ]]; then
    		part_type_flag="msdos"
		sleep 3s
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
    
	sleep 3s
	ESP="/dev/$(lsblk $DISK -o NAME,PARTLABEL | grep boot | cut -d " " -f1 | cut -c7-)"
	echo -e "\n${BOL_GRE}Partition boot: ${ESP}${END}"
	sleep 0.5s
	
	BTRFS="/dev/$(lsblk $DISK -o NAME,PARTLABEL | grep archlinux | cut -d " " -f1 | cut -c7-)"
	echo -e "\n${BOL_GRE}Partition Root: $BTRFS${END}"
	sleep 3s
	
	# Informing the Kernel of the changes.
	echo -e "\n${BOL_GRE}Informing the Kernel about the disk changes.$BTRFS${END}"
	sleep 1s
	partprobe "$DISK"

}

verifyBoot_mode() {
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
}

formatting_UEFI_BIOS() {
echo -e "\n${BOL_YEL}Formatting the EFI Partition as FAT32 or BIOS as${END}"

	if [ "$BIOS_TYPE" == "uefi" ]; then
		mkfs.fat -F32 "$ESP"
		leep 3s
	fi
	
	if [ "$BIOS_TYPE" == "bios" ]; then
		mkfs.ext4  "$ESP"
		leep 3s
	fi
}
		
	
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

formatPartitions_nocript() {
  echo -e "\n${BOL_GRE}Formatando btrfs em $BTRFS{END}"
  mkfs.btrfs --force $BTRFS 
  sleep 3s
  #mkfs.btrfs --force --label $PARTNAME $BTRFS
}

formatPartitions_cript() {
  echo -e "\n${BOL_GRE}Formatando EFI e $SSD${END}"
  mkfs.fat -F32 -n EFI /dev/disk/by-partlabel/EFI
  mkfs.btrfs --force --label system /dev/mapper/system
  
}

createSubVolumesBtrfs() {
  echo -e "\n${BOL_GRE}Creating BTRFS subvolumes${END}"
 	btrfs su cr /mnt/@ &>/dev/null
	btrfs su cr /mnt/@/.snapshots &>/dev/null
	#mkdir -p /mnt/@/.snapshots/1 &>/dev/null
	#btrfs su cr /mnt/@/.snapshots/1/snapshot &>/dev/null
	btrfs su cr /mnt/@/boot/ &>/dev/null
	leep 3s
	btrfs su cr /mnt/@/home &>/dev/null
	btrfs su cr /mnt/@/root &>/dev/null
	btrfs su cr /mnt/@/srv &>/dev/null
	btrfs su cr /mnt/@/var_log &>/dev/null
	leep 3s
	btrfs su cr /mnt/@/var_log_journal &>/dev/null
	btrfs su cr /mnt/@/var_crash &>/dev/null
	btrfs su cr /mnt/@/var_cache &>/dev/null
	btrfs su cr /mnt/@/var_tmp &>/dev/null
	btrfs su cr /mnt/@/var_spool &>/dev/null
	leep 3s
	btrfs su cr /mnt/@/var_lib_libvirt_images &>/dev/null
	btrfs su cr /mnt/@/var_lib_machines &>/dev/null
	btrfs su cr /mnt/@/var_lib_sddm &>/dev/null
	btrfs su cr /mnt/@/var_lib_AccountsService &>/dev/null
	btrfs subvolume create /mnt/@swap
	#btrfs su cr /mnt/@/cryptkey &>/dev/null
	leep 3s

	chattr +C /mnt/@/boot
	chattr +C /mnt/@/srv
	chattr +C /mnt/@/var_log
	leep 3s
	chattr +C /mnt/@/var_log_journal
	chattr +C /mnt/@/var_crash
	chattr +C /mnt/@/var_cache
	chattr +C /mnt/@/var_tmp
	leep 3s
	chattr +C /mnt/@/var_spool
	chattr +C /mnt/@/var_lib_libvirt_images
	chattr +C /mnt/@/var_lib_machines
	leep 3s
	chattr +C /mnt/@/var_lib_sddm
	chattr +C /mnt/@/var_lib_AccountsService
	#chattr +C /mnt/@/cryptkey
}

mountPartitions() {
  echo -e "\n${BOL_GRE}Mounting the newly created subvolumes${END}"
  sleep 1s
	umount /mnt
	mount -o ssd,noatime,space_cache,compress=zstd:15 $BTRFS /mnt
	mkdir -p /mnt/{boot,root,home,swap,.snapshots,srv,tmp,/var/log,/var/crash,/var/cache,/var/tmp,/var/spool,/var/lib/libvirt/images,/var/lib/machines,/var/lib/sddm,/var/lib/AccountsService}
	mount -o ssd,noatime,space_cache=v2,autodefrag,compress=zstd:15,discard=async,nodev,nosuid,noexec,subvol=@/boot $BTRFS /mnt/boot
	mount -o ssd,noatime,space_cache=v2,autodefrag,compress=zstd:15,discard=async,nodev,nosuid,subvol=@/root $BTRFS /mnt/root
	leep 3s
	mount -o ssd,noatime,space_cache=v2.autodefrag,compress=zstd:15,discard=async,nodev,nosuid,subvol=@/home $BTRFS /mnt/home
	mount -o ssd,noatime,space_cache=v2,autodefrag,compress=zstd:15,discard=async,subvol=@/.snapshots $BTRFS /mnt/.snapshots
	mount -o ssd,noatime,space_cache=v2.autodefrag,compress=zstd:15,discard=async,subvol=@/srv $BTRFS /mnt/srv
	mount -o ssd,noatime,space_cache=v2,autodefrag,compress=zstd:15,discard=async,nodatacow,nodev,nosuid,noexec,subvol=@/var_log $BTRFS /mnt/var/log

	leep 3s
	# Toolbox (https://github.com/containers/toolbox) needs /var/log/journal to have dev, suid, and exec, Thus I am splitting the subvolume. Need to make the directory after /mnt/var/log/ has been mounted.
	mkdir -p /mnt/var/log/journal
	mount -o ssd,noatime,space_cache=v2,autodefrag,compress=zstd:15,discard=async,nodatacow,subvol=@/var_log_journal $BTRFS /mnt/var/log/journal
	
	mount -o ssd,noatime,space_cache=v2,autodefrag,compress=zstd:15,discard=async,nodatacow,nodev,nosuid,noexec,subvol=@/var_crash $BTRFS /mnt/var/crash
	mount -o ssd,noatime,space_cache=v2,autodefrag,compress=zstd:15,discard=async,nodatacow,nodev,nosuid,noexec,subvol=@/var_cache $BTRFS /mnt/var/cache
	leep 3s
	
# Pamac needs /var/tmp to have exec. Thus I am not adding that flag.
	mount -o ssd,noatime,space_cache=v2,autodefrag,compress=zstd:15,discard=async,nodatacow,nodev,nosuid,subvol=@/var_tmp $BTRFS /mnt/var/tmp
	mount -o ssd,noatime,space_cache=v2,autodefrag,compress=zstd:15,discard=async,nodatacow,nodev,nosuid,noexec,subvol=@/var_spool $BTRFS /mnt/var/spool
	mount -o ssd,noatime,space_cache=v2,autodefrag,compress=zstd:15,discard=async,nodatacow,nodev,nosuid,noexec,subvol=@/var_lib_libvirt_images $BTRFS /mnt/var/lib/libvirt/images
	mount -o ssd,noatime,space_cache=v2,autodefrag,compress=zstd:15,discard=async,nodatacow,nodev,nosuid,noexec,subvol=@/var_lib_machines $BTRFS /mnt/var/lib/machines
	leep 3s
	
# KDE requires /var/lib/sddm and /var/lib/AccountsService to be writeable when booting into a readonly snapshot. Thus we sadly have to split them.
	mount -o ssd,noatime,space_cache=v2,autodefrag,compress=zstd:15,discard=async,nodatacow,nodev,nosuid,noexec,subvol=@/var_lib_sddm $BTRFS /mnt/var/lib/sddm
	mount -o ssd,noatime,space_cache=v2,autodefrag,compress=zstd:15,discard=async,nodatacow,nodev,nosuid,noexec,subvol=@/var_lib_AccountsService $BTRFS /mnt/var/lib/AccountsService

# mount swap for swapfile
	mount -o defaults,noatime,subvol=@swap $BTRFS /mnt/swap
	leep 3s
# The encryption is splitted as we do not want to include it in the backup with snap-pac.
	#mount -o ssd,noatime,space_cache=v2,autodefrag,compress=zstd:15,discard=async,nodatacow,nodev,nosuid,noexec,subvol=@/cryptkey $BTRFS /mnt/cryptkey
} 
  
mountPartitions_UFEI_BIOS() {
 	if [ "$BIOS_TYPE" == "uefi" ]; then
		mkdir -p /mnt/boot/efi
		mount "$ESP" /mnt/boot/efi
		leep 1s
	fi
	
	if [ "$BIOS_TYPE" == "bios" ]; then
		mkdir -p /mnt/boot
		mount "$ESP" /mnt/boot
		leep 1s
	fi
}

cretingSwapfile() {
	read -p "Enter the size for the swapfile (e.g. 4G, 8G, 16G): " swapfile_size

	# Creating Swap file
	echo "Creating Swap file of size $swapfile_size"
	sleep 1s
	touch /mnt/swap/swapfile
	chmod 600 /mnt/swap/swapfile
	chattr +C /mnt/swap/swapfile
	leep 3s
	fallocate /mnt/swap/swapfile -l "$swapfile_size"
	mkswap /mnt/swap/swapfile
	swapon /mnt/swap/swapfile
	leep 3s
}


reflectorMirrors() {
  	echo -e "\n${BOL_GRE}Instalando reflector para obter melhores mirrors${END}"
  	pacman -Sy reflector --noconfirm --needed
  	#reflector --verbose --sort rate -l 5 --save /etc/pacman.d/mirrorlist
	#reflector -c BR --sort rate -a 6 --save /etc/pacman.d/mirrorlist
	reflector --country Brazil   --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
	sleep 90s
	echo -e "\n${BOL_BLU}Mirrors have been successfully updated${END}"
	sleep 1s
	pacman -Syyy --noconfirm
	
}

configurandoPacman(){
  sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
  sed -i 's/#UseSyslog/UseSyslog/' /etc/pacman.conf
  sed -i 's/#Color/Color\\\nILoveCandy/' /etc/pacman.conf
  sed -i 's/Color\\/Color/' /etc/pacman.conf
  sed -i 's/#TotalDownload/TotalDownload/' /etc/pacman.conf
  sed -i 's/#CheckSpace/CheckSpace/' /etc/pacman.conf
  sed -i "s/#VerbosePkgLists/VerbosePkgLists/g" /etc/pacman.conf
  sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 5g" /etc/pacman.conf
}

pacstrapInstall() {
  pacman -Sy archlinux-keyring git --noconfirm --needed
  
  echo -e "\n${BOL_CYA}Instalando base sistema${END}"
  sleep 3s
  pacstrap /mnt base base-devel bash-completion archlinux-keyring 
  
  echo -e "\n${BOL_CYA}Instalando kenel vanillia linux${END}"
  sleep 3s
  pacstrap /mnt linux linux-headers
  
  echo -e "\n${BOL_CYA}Instalando kenel linux-lts${END}"
  sleep 3s
  pacstrap /mnt  linux-lts linux-lts-headers 
  
  echo -e "\n${BOL_CYA}Instalando firmware kenel linux${END}"
  sleep 3s
  pacstrap /mnt  linux-firmware linux-firmware-whence \
  
  echo -e "\n${BOL_CYA}Instalando linux headers, util e libs${END}"
  sleep 3s
  pacstrap /mnt linux-api-headers util-linux util-linux-libs lib32-util-linux
  
  echo -e "\n${BOL_CYA}Instalando bootloader e ferramentas relacionadas${END}"
  sleep 3s
  pacstrap /mnt grub grub-btrfs btrfs-progs grub-theme-vimix os-prober efibootmgr efitools gptfdisk
  
  echo -e "\n${BOL_CYA}Suporte a sistemas de arquivos${END}"
  sleep 3s
  pacstrap /mnt  btrfs-progs snapper dosfstools exfat-utils f2fs-tools fuse fuse-exfat mtpfs
    
  echo -e "\n${BOL_CYA}Xorg${END}"
  sleep 3s
  pacstrap /mnt xorg-server xf86-input-evdev
  
  echo -e "\n${BOL_CYA}Ferramentas de linha de comando${END}"
  sleep 3s
  pacstrap /mnt bash-completion sudo nano nano-syntax-highlighting git curl wget
  
}

genfstabGenerator() {
  genfstab -U /mnt >> /mnt/etc/fstab
  #sed -i "s+LABEL=swap+/dev/mapper/cryptswap+" /mnt/etc/fstab
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
  sed -i "3i DISK=${DISK}" configure.sh
  #sed -i "4i SSD3=${SSD3}" configure.sh
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
  #formatDrive
  #encryptSystem
  #unlockDisk
  #unlockSwap
  #formatSwap
  #formatPartitions_cript
  formatPartitions_nocript
  createSubVolumesBtrfs
  mountPartitions
  cretingSwapfile
  reflectorMirrors
  configurandoPacman
  pacstrapInstall
  genfstabGenerator
  #cryptswapAdd
  #copyWifi
  chrootPrepare
}

if [[ ${1} == "recovery" ]]; then
  recovery
else
  echo -e "\n${BOL_BLU}Iniciando instalação do ArchLinux${END}"
  run "$@" || echo "$@ falhou" && exit
fi
