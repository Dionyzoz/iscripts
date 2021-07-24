#!/bin/sh

### OPTIONS AND VARIABLES ###

printhelp() {
# `cat << EOF` means that cat should stop reading when EOF is detected.
cat << EOF
Optional arguments for custom use:

-h      Display this message.
-a      Also install part of Arch Linux

EOF
# Exit once we have printed the help message.
exit 1
}

while getopts ":hp:l" opt; do case $opt in
        h) printhelp ;;
        a) arch=true ;;
        *) printf "Invalid option: -%s\\n" "$OPTARG" && exit 1 ;;
esac done

progsfile="progs.csv"
dotfilesrepo="https://github.com/jorisperrenet/dotfiles.git"

### FUNCTIONS ###

getuserandpass() {
	# Prompts user for new username an password.
    echo "First, please enter a name for the user account."
    read name

	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
        name=$(echo "Username not valid, please enter a valid name for the user account."; read name)
	done

    echo "Enter a password for that user."
    read -s pass1
    echo "Retype password."
    read -s pass2

	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
        echo "Passwords do not match.\\n\\nEnter password again."
        read -s pass1
        echo "Retype password."
        read -s pass2
	done
}

adduserandpass() {
	# Adds user `$name` with password $pass1.
	echo "Adding user \"$name\"..."
	useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
	usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	echo "$name:$pass1" | chpasswd
	unset pass1
}

newperms() { # Set special sudoers settings for install (or after).
	sed -i "/#ISCRIPTS/d" /etc/sudoers
	echo "$* #ISCRIPTS" >> /etc/sudoers
}

installpkg() { pacman --noconfirm --needed -S "$1" > /dev/null 2>&1 ;}

maininstall() {
    echo "Installing ($n of $total) \`$1\`, $2."
    installpkg "$1"
}

aurinstall() {
	[ -f "/usr/bin/$1" ] || (echo "Installing ($n of $total) \`$1\` from the AUR, $2."
    mkdir -p "/home/$name/installs"
    cd "/home/$name/installs"
    git clone "https://aur.archlinux.org/$1.git" >/dev/null 2>&1 &&
    cd "$1" &&
    sudo makepkg --noconfirm -si >/dev/null 2>&1)
}

progsinstallation() {
    # Get the progsfile and delete the header.
    [ -f "$progsfile" ] && cat "$progsfile" | sed '/^#/d' > /tmp/progs.csv

    total=$(wc -l < /tmp/progs.csv)

    # Use , as the delimeter.
    while IFS=, read -r tag program comment; do
        # Indication of how many programs we have installed so far.
        n=$((n+1))

        # Remove the "" from the comment.
        comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"

        case "$tag" in
            "A") aurinstall "$program" "$comment" ;;
            *) maininstall "$program" "$comment" ;;
        esac
    done < /tmp/progs.csv
}

putgitrepo() { # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
    echo "Installing dotfiles..."

    # Create a temporary directory and the destination directory, and
    # make sure they are owned by the current user.
	dir=$(mktemp -d)
    [ ! -d "$2" ] && mkdir -p "$2"
    chown -R "$name":"$name" "$dir" "$2"

	sudo -u "$name" git clone --recursive "$1" "$dir" >/dev/null 2>&1
	sudo -u "$name" cp -rfT "$dir" "$2" >/dev/null 2>&1
}

getwallpaper() {
    curl -o $1 https://w.wallhaven.cc/full/8x/wallhaven-8x782y.jpg
}

### THE ACTUAL SCRIPT ###

# Get and verify username and password.
getuserandpass || error "User exited."
adduserandpass || error "Error adding username and/or password."

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
newperms "%wheel ALL=(ALL) NOPASSWD: ALL"


# Install the programs from the progsfile.
progsinstallation

# Install the dotfiles in the user's home directory.
echo "Installing dotfiles..."
# putgitrepo "$dotfilesrepo" "/home/$name"
# Setup a bare git repository to manage the dotfiles
git clone --bare --config status.showUntrackedFiles=no "$dotfilesrepo" "/home/$name/.local/share/dotfiles"
dfg="/usr/bin/git --git-dir=/home/$name/.local/share/dotfiles --work-tree=/home/$name"
# Setup all the files.
"$dfg" checkout -f
# Initialize the submodules, which has to be done like this in order for
# the bare repository to be able to manage them.
sudo "$dfg" submodule update --init --recursive
# Delete files, but make git ignore the deletion. The files can simply
# be restored with e.g. `dfg checkout README.md`.
rm -f "/home/$name/README.md" "/home/$name/LICENSE"
"$dfg" update-index --assume-unchanged "/home/$name/README.md" "/home/$name/LICENSE"

# Make zsh the default shell for the user.
sudo chsh -s /bin/zsh "$name" > /dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"

# Get the wallpaper so that i3 can set it up.
mkdir -p /home/$name/wallpapers/
getwallpaper "/home/$name/wallpapers/landscape.jpg"

# Run the manual install files
echo "Installing nerdfont, a font"
./manual_install/nerd_font.sh >/dev/null 2>&1

# Configuring the display manager
echo "Configuring the display manager lightdm"
sudo systemctl enable lightdm
sudo sed -i 's/^#greeter-session=.*/greeter-session=lightdm-webkit2-greeter/' /etc/lightdm/lightdm.conf

echo "Installing language servers"
# Python
sudo npm install -g pyright >/dev/null 2>&1
# Typescript
sudo npm install -g typescript typescript-language-server >/dev/null 2>&1


# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
echo "Allowing the user to run important commands"
newperms "%wheel ALL=(ALL) ALL #ISCRIPTS
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/paru,/usr/bin/pacman -Syyuw --noconfirm"
