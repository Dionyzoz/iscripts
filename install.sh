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

installpkg() { pacman --noconfirm --needed -S "$1" > /dev/null 2>&1 ;}

maininstall() {
    echo "Installing \`$1\` ($n of $total). $1 $2"
    installpkg "$1"
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
    chown -R "$USER":"$USER" "$dir" "$2"

	sudo -u "$USER" git clone --recursive "$1" "$dir" >/dev/null 2>&1
	sudo -u "$USER" cp -rfT "$dir" "$2" >/dev/null 2>&1
}

getwallpaper() {
    curl -o $1 https://w.wallhaven.cc/full/8x/wallhaven-8x782y.jpg
}

### THE ACTUAL SCRIPT ###

# Install the programs from the progsfile.
progsinstallation

# Install the dotfiles in the user's home directory.
echo "Installing dotfiles..."
# putgitrepo "$dotfilesrepo" "/home/$USER"
# Setup a bare git repository to manage the dotfiles
git clone --bare --config status.showUntrackedFiles=no "$dotfilesrepo" "/home/$USER/.local/share/dotfiles"
alias dfg="/usr/bin/git --git-dir=/home/$USER/.local/share/dotfiles --work-tree=/home/$USER"
# Setup all the files.
dfg checkout -f
# Initialize the submodules, which has to be done like this in order for
# the bare repository to be able to manage them.
dfg submodule update --init --recursive
# Delete files, but make git ignore the deletion. The files can simply
# be restored with e.g. `dfg checkout README.md`.
rm -f "/home/$USER/README.md" "/home/$USER/LICENSE"
dfg update-index --assume-unchanged "/home/$USER/README.md" "/home/$USER/LICENSE"

# Make zsh the default shell for the user.
sudo chsh -s /bin/zsh "$USER" > /dev/null 2>&1
sudo -u "$USER" mkdir -p "/home/$USER/.cache/zsh/"

# Get the wallpaper so that i3 can set it up.
mkdir -p /home/$USER/wallpapers/
getwallpaper "/home/$USER/wallpapers/landscape.jpg"

# Run the manual install files
echo "Installing nerdfont, a font"
./manual_install/nerd_font.sh >/dev/null 2>&1

echo "Installing language servers"
# Python
sudo npm install -g pyright
# Typescript
sudo npm install -g typescript typescript-language-server
