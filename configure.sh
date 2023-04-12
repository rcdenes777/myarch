#!/usr/bin/env bash
source colors.sh


# Setting username.
read -r -p "Please enter name for a user account (leave empty to skip): " USERNAME

# Setting hostname.
read -r -p "Please enter the hostname: " HOSTNAME

createUseraAndHost() {
  useradd -m -G wheel -s /bin/bash $USERNAME
  mkdir -p /home/$USERNAME
  echo $HOSTNAME > /etc/hostname
  chown -R $USERNAME:$USERNAME /home/$USERNAME
  echo "127.0.0.1	localhost
  ::1		   localhost
  127.0.1.1  ${HOSTNAME}.localdomain    ${HOSTNAME}" | tee -a /etc/hosts
}

reflectorMirrors() {
#  reflector --verbose -c BR --protocol https --protocol http --sort rate --save /etc/pacman.d/mirrorlist
  sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
  sed -i 's/#UseSyslog/UseSyslog/' /etc/pacman.conf
  sed -i 's/#Color/Color\\\nILoveCandy/' /etc/pacman.conf
  sed -i 's/Color\\/Color/' /etc/pacman.conf
  sed -i 's/#TotalDownload/TotalDownload/' /etc/pacman.conf
  sed -i 's/#CheckSpace/CheckSpace/' /etc/pacman.conf
  sed -i "s/#VerbosePkgLists/VerbosePkgLists/g" /etc/pacman.conf
  sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 5/g" /etc/pacman.conf
}

localeAndTime() {
  echo "KEYMAP=br-abnt2" > /etc/vconsole.conf
  sed -i "s/#pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/g" /etc/locale.gen
  sed -i "s/#pt_BR ISO-8859-1/pt_BR ISO-8859-1/g" /etc/locale.gen
  sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen
  sed -i "s/#en_US ISO-8859-1/en_US ISO-8859-1/g" /etc/locale.gen
  echo "LANG=pt_BR.UTF-8" > /etc/locale.conf
  locale-gen
  ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
  hwclock --systohc
}

mkinitcpioConfigs() {
  #sed -i "s/BINARIES=()/BINARIES=(btrfs)/g" /etc/mkinitcpio.conf
  #sed -i "s/block/block encrypt/g" /etc/mkinitcpio.conf
  sed -i "s/#COMPRESSION=\"zstd\"/COMPRESSION=\"zstd\"/g" /etc/mkinitcpio.conf
  sed -i "s/#COMPRESSION_OPTIONS=()/COMPRESSION_OPTIONS=(-9)/g" /etc/mkinitcpio.conf
  mkinitcpio -P
}

grubConfigs() {
  sed -i 's/GRUB_DEFAULT=0/GRUB_DEFAULT=saved/g' /etc/default/grub
  sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 acpi=noirq"/g' /etc/default/grub
  #sed -i -e 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=UUID='${SSD3_UUID}':cryptsystem"/g' /etc/default/grub
  #sed -i 's/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/g' /etc/default/grub
  #sed -i 's/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/g' /etc/default/grub
  #sed -i 's/#GRUB_DISABLE_SUBMENU=y/GRUB_DISABLE_SUBMENU=y/g' /etc/default/grub
    
  if [ -d /sys/firmware/efi ]; then
	  
	  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
	  grub-mkconfig -o /boot/grub/grub.cfg
  else
	  
	  grub-install --target=i386-pc "$DISK"
	  grub-mkconfig -o /boot/grub/grub.cfg
  fi
  

systemdConfigs() {
  sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/g' /etc/systemd/logind.conf
  sed -i 's/#NAutoVTs=6/NAutoVTs=6/g' /etc/systemd/logind.conf
}

adicionalPackges_install(){
  echo -e "\n${BOL_CYA}Ferramentas de linha de comando 2${END}"
  pacman -S neofetch zsh zsh-syntax-highlighting --noconfirm
  
  echo -e "\n${BOL_CYA}Audio${END}"
  pacman -S pipewire pipewire-alsa pipewire-pulse kpipewire --noconfirm

  echo -e "\n${BOL_CYA}KDE Plasma${END}"
  pacman -S plasma-desktop networkmanager --noconfirm

  echo -e "\n${BOL_CYA}KDE Plasma utilitarios e extras${END}"
  pacman -S konsole ark dolphin dolphin-plugins kate partitionmanager filelight okular plasma-nm kdeplasma-addons yakuake kdegraphics-thumbnailers plasma-workspace-wallpapers kcalc plasma-browser-integration --noconfirm
  
  echo -e "\n${BOL_CYA}Firewall${END}"
  pacman -S ufw gufw --noconfirm
  
  echo -e "\n${BOL_CYA}Gerenciador loguin${END}"
  pacman -S sddm sddm-kcm --noconfirm
  
  echo -e "\n${BOL_CYA}Fonts${END}"
  pacman -S adobe-source-han-sans-otc-fonts adobe-source-han-serif-otc-fonts gnu-free-fonts terminus-font noto-fonts-emoji ttf-dejavu ttf-liberation --noconfirm
  
  echo -e "\n${BOL_CYA}Ferramentas de compressao${END}"
  pacman -S unace unrar p7zip arj cabextract lzip zlib laszip lbzip2 lrzip pbzip2 lzop --noconfirm
  
  echo -e "\n${BOL_CYA}INTERNET${END}"
  pacman -S chromium firefox firefox-i18n-pt-br qbittorrent thunderbird thunderbird-i18n-pt-br --noconfirm
  
  
  echo -e "\n${BOL_CYA}AUDIO E VIDEO${END}"
  pacman -S elisa smplayer vlc ffmpeg ffmpegthumbnailer ffmpegthumbs ffmpeg ffmpegthumbnailer gst-libav gst-plugins-ugly gstreamer gst-plugins-good libdvdread lame libdvbpsi libiec61883 libmad libmpeg2 mjpegtools mpg123 xvidcore --noconfirm
  
  echo -e "\n${BOL_CYA}OPENGLl${END}"
  pacman -S mesa mesa-demos --noconfirm
  
  echo -e "\n${BOL_CYA}LIBREOFFICE COM CORREÇÃO ORTOGRÁFICA${END}"
  pacman -S libreoffice-fresh libreoffice-fresh-pt-br languagetool aspell-pt libmythes  --noconfirm
  
  echo -e "\n${BOL_CYA}INSTALL ADDITIONAL for android${END}"
  pacman -S libmtp android-udev --noconfirm
 
 
 }
yayInstall(){ 
	echo -e "\n${BOL_CYA}Instalando suporte a AUR${END}"
	echo "Instalando suporte a AUR."
	echo "################################################################"
	echo;tput sgr0
	sleep 5s
	sudo pacman -S --noconfirm git go
	git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si
	sleep 1s    
}
sshConfigs() {
  pwd=$(pwd)
    rm -rf /etc/ssh/ssh_config
    cd /etc/ssh
    wget https://raw.githubusercontent.com/openssh/openssh-portable/master/ssh_config
    chown -R root:root ssh_config
  cd $pwd
  sed -i "s/#   StrictHostKeyChecking ask/StrictHostKeyChecking no/g" /etc/ssh/ssh_config
  sed -i "s/#AllowAgentForwarding yes/AllowAgentForwarding yes/g" /etc/ssh/sshd_config
  sed -i "s/#AllowTcpForwarding yes/AllowTcpForwarding yes/g" /etc/ssh/sshd_config
}

systemctlConfigs() {
  systemctl disable NetworkManager
  systemctl enable sddm
  systemctl enable firewalld
  systemctl enable reflector.timer
  systemctl enable snapper-timeline.timer 
  systemctl enable snapper-cleanup.timer 
  systemctl enable grub-btrfs.path
  systemctl enable ufw.service

  #systemctl enable dhcpcd
  #systemctl enable iwd
  #systemctl enable sshd.service
  systemctl enable fstrim.timer
  
}

snapperConfiguration(){
    # Snapper configuration
    umount /.snapshots
    rm -r /.snapshots
    snapper --no-dbus -c root create-config /
    btrfs subvolume delete /.snapshots
    mkdir /.snapshots
    mount -a
    chmod 750 /.snapshots
    echo  "TIMELINE_MIN_AGE="1800"" >> /mnt/etc/snapper/configs/root
    echo  "TIMELINE_LIMIT_HOURLY="1"" >> /mnt//etc/snapper/configs/root
    echo  "TIMELINE_LIMIT_DAILY="1"" >> /mnt//etc/snapper/configs/root
    echo  "TIMELINE_LIMIT_WEEKLY="1"" >> /mnt//etc/snapper/configs/root
    echo  "TIMELINE_LIMIT_MONTHLT="1"" >> /mnt//etc/snapper/configs/root
    echo  "TIMELINE_LIMIT_YEARLY="0"" >> /mnt//etc/snapper/configs/root



}

sudoersConfigs() {
  sed -i "s/root ALL=(ALL:ALL) ALL/root ALL=(ALL:ALL) NOPASSWD: ALL\n${USERNAME} ALL=(ALL:ALL) NOPASSWD: ALL/g" /etc/sudoers
  sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL$/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
  echo "Defaults timestamp_timeout=0" >> /etc/sudoers
}

passwords() {
  clear
  echo -e "\n${BOL_GRE}Digite a senha para ${MAG}${USERNAME}${END}"
  passwd $USERNAME && clear
  echo -e "\n${BOL_GRE}Digite a senha para ${MAG}root${END}"
  passwd root
}

if [[ $USERNAME == mamutal91 ]]; then
  git clone https://github.com/mamutal91/dotfiles /home/mamutal91/.dotfiles
  sed -i 's/https/ssh/g' /home/mamutal91/.dotfiles/.git/config
  sed -i 's/github/git@github/g' /home/mamutal91/.dotfiles/.git/config
fi

run() {
  createUseraAndHost
  reflectorMirrors
  localeAndTime
  mkinitcpioConfigs
  bootloaderConfigs
  grubConfigs
  adicionalPackges_install
  yayInstal
  #sshConfigs
  systemctlConfigs
  snapperConfiguration
  sudoersConfigs
  passwords
}
run "$@" || echo "$@ falhou"
