# Installing Arch Linux

## Downloading and verifying the iso
Visit the [download](https://archlinux.org/download/) page and download Arch Linux. Verify the signature with the `md5sum` and `sha1sum` command (the correct sums are listed on the page).

On an existing Arch Linux installation run:
```bash
pacman-key -v archlinux-<VERSION>-x86_64.iso.sig
```
When there is no existing Arch Linux installation visit the [installation guide](https://wiki.archlinux.org/title/installation_guide#Pre-installation) of Arch Linux.

Put in the USB flash drive with the iso (where you want to install it ofcourse).
Boot in the drive to install Arch Linux.

Now, when the tty is loaded we can begin with the installation.

## Installation
A dvorak keyboard layout can be set with `loadkeys dvorak`

Then, for connecting to a network.
```bash
iwctl  # the iwd interactive prompt is now displayed
station list devices
station <DEVICE> get-networks
station <DEVICE> connect <SSID>  # then enter the password of the network
exit
```

This is the point where you can use a script to do the rest, if you want this, look at the Automated install section. In the Manual install section the installation is described further.


## Manual install
To verify the boot mode, list the efivars directory:
```bash
ls /sys/firmware/efi/efivars
```
If this results in an error, you might want to consider an BIOS boot system instead of an UEFI system. To install this look at the **bold** words. At the end of this section look at the subsection BIOS boot system for the correct replacements.

First for the system clock:
```bash
timedatectl set-ntp true
```

Then we are going to make partitions, we do this by using `fdisk`.
To print the current "setup" use `fdisk -l`.
To partition the disk, run `fdisk /dev/<DISK>`, where `<DISK>` is for example `sda` or `nvme0n1`.
In this menu, use `p` to print the current partition table, now by using `n` for creating a new partition and `t` for changing the type, make the following partitions:
1. **EFI system partition** of `+550M` (type `1`), the name of the EFI partition will be `<EFI>` from now on, e.g. `/dev/sda1`.
2. Swap partition of `+(#RAM)` (type `19`), the name of the partition will be `<SWAP>` from now on, e.g. `/dev/sda2`.
3. Root partition of the rest of the space (default size and type), the name of the partition will be `<ROOT>` from now on, e.g. `/dev/sda3`.
Then use `w` to write the changes of `p`.
```bash
# What I did for the EFI system partition (empty lines are returns)
n


+550M
t

1
```

**Formatting the partitions:**
```bash
mkfs.fat -F32 <EFI>
mkfs.ext4 <ROOT>
mkswap <SWAP>
swapon <SWAP>
```
**Mounting the partitions:**
```bash
mount <ROOT> /mnt
mkdir -p /mnt/boot
mount <EFI> /mnt/boot
```

Then, to install packages, run:
```bash
pacstrap /mnt base base-devel linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
ln -sf /usr/share/zoneinfo/<REGION>/<CITY> /etc/localtime
hwclock --systohc
pacman -S networkmanager network-manager-applet  # for wi-fi
pacman -S vi  # for editing
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
```
When setting the keyboard layout add `KEYMAP=dvorak` to `/etc/vconsole.conf`.
Choose a hostname and put it in `/etc/hostname` by running `echo "<HOSTNAME>" >> /etc/hostname`.
Edit the file `/etc/hosts` and put the [following](https://wiki.archlinux.org/title/installation_guide#Network_configuration) in:
```text
127.0.0.1	localhost
::1		localhost
127.0.1.1	<HOSTNAME>.localdomain	<HOSTNAME>
```
Then continue by running `mkinitcpio -P` and `passwd`.

Now, for the bootloader install the **following packages**:
```bash
pacman -S grub efibootmgr
```

Then **run**
```bash
grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB
```

Again, when needing dual boot, mount the e.g. windows EFI system partition like so:
```bash
mkdir -p /mnt2
mount <WINDOWS EFI SYSTEM PARTITION> /mnt2
pacman -S os-prober
os-prober
echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
```

Then finish the installation by running
```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

Exit chroot (the command is `exit`) and reboot (the command is `reboot`) you can remove the installation medium.

You can now login with `root` and the password you set when running `passwd`.
To connect to wi-fi use the GUI `nmtui`, but first run `systemctl start NetworkManager` and `systemctl enable NetworkManager`.

After doing this you can install everything by running the iscripts. For the iscripts look for the section Installing with iscripts below.


### BIOS boot system
EFI system partition)       Instead create a BIOS boot system of `+1M` (type `4`).
Formatting the partitions)  Instead of a fat signature of the EFI partition do nothing.
Mounting the partitions)    Instead of mounting the EFI partition do nothing. The directory `/mnt/boot` does not need to be made as well.
following packages)         Do not install efibootmgr.
run)                        instead, run
```bash
grub-install --target=i386-pc <DISK>
```

## Automated install
Use curl to get the script, I have no script yet.


# Installing with iscripts

On a fresh installation, take the following steps to end up with my configurations:

1. Use pacman to install git
```bash
pacman -S git
```
2. Run the executable in this repository
```bash
git clone https://github.com/jorisperrenet/iscripts.git
cd iscripts
./install.sh
```
3. Reboot and boot into `i3`.
4. Follow the steps in my [dotfiles repo](https://github.com/jorisperrenet/dotfiles) to complete
   the installation for certain programs using plugin managers.
5. Generate ssh-keys to set up on GitHub, GitLab and what not.
```bash
ssh-keygen -t rsa -b 2048 -C "email@example.com"
```
