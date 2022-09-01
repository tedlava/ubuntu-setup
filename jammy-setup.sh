#!/bin/bash

# The purpose of this script is to automate the post-installation configuration
# to achieve my personal ideal setup.  Since I have several computers, I often
# find myself repeating these steps many times, since I have a tendency to
# experiment a little too much and have a bad habit of distro-hopping!  However,
# if I ever learn to kick the distro-hopping habit/hobby, there's a chance
# that I might make this awesome script and then never end up using it again!
# Of course, this might make it even easier to experiment with all the distros
# since I now have an easy way of restoring my Debian back to it's ideal state,
# so it also might make my distro-hopping even worse...  WTF...


# Change to script directory to use files as flag variables for saving the
# current state of the script
script_rel_dir=$(dirname "${BASH_SOURCE[0]}")
cd $script_rel_dir
script_dir=$(pwd)


release_name=$(echo $0 | cut -d'-' -f1 | cut -d'/' -f2)


# Load variables from config file and paths for gsettings and dconf configs
if [ -f "$HOME/Setup/$release_name-config" ]; then
	source $HOME/Setup/$release_name-config
	gsettings_path="$HOME/Setup/$release_name-gsettings.txt"
	dconf_settings_path="$HOME/Setup/$release_name-dconf.txt"
else
	source $script_dir/$release_name-config
	gsettings_path="$script_dir/$release_name-gsettings.txt"
	dconf_settings_path="$script_dir/$release_name-dconf.txt"
fi


function confirm_cmd {
	local cmd="$*"
	if [ -n "$interactive" ]; then
		echo -e "\nAbout to execute command...\n    $ $cmd"
		read -p 'Proceed? [Y/n] '
		if [ -z "$REPLY" ] || [ "${REPLY,}" == 'y' ]; then
			eval $cmd
		fi
	else
		echo -e "\nExecuting command...\n    $ $cmd\n"
		eval $cmd
	fi
}


function contains {
	local -n array=$1
	for i in "${array[@]}"; do
		if [ "$i" == "$2" ]; then
			echo $i
		fi
	done
}


echo
echo "Ted's Debian Setup Script"
echo '========================='
echo
echo "    Release: ${release_name^}"
echo


if [ "$(id -u)" -eq 0 ]; then
	echo
	echo 'Please run this shell script as a normal user (with sudo privileges).'
	echo "Some commands (such as gnome-extensions) need to connect to the user's"
	echo "Gnome environment and won't work if run as root."
	echo
	exit
fi


while getopts ':hie' opt; do
	case $opt in
	h)
		echo
		echo 'Help!'
		echo
		exit
		;;
	i)
		echo
		echo 'Full interactive mode!  You will be prompted for confirmation before'
		echo 'running EVERY SINGLE command!'
		echo
		interactive=1
		;;
	e)
		echo
		echo 'Skip to Gnome extensions!'
		echo
		skip_to_ext=1
		;;
	\?)
		echo
		echo 'You entered an incorrect option...'
		echo
		exit
		;;
	esac
done


# Interactive mode?
if [ -z "$interactive" ]; then
	echo
	echo 'Do you want to run the script in full interactive mode, which will ask for'
	read -p 'confirmation for every command that may alter your system? [y/N] '
	echo
	if [ "${REPLY,}" == 'y' ]; then
		interactive=1
	fi
fi


if [ ! -f "$status_dir/deb_setup_part_1" ] && [ ! -f "$status_dir/deb_setup_part_2" ]; then
	if [ -z "$skip_to_ext" ]; then
		if [ ! -f "$status_dir/reqs_confirmed" ]; then
			echo 'This script automates some common settings that I use for'
			echo 'every Debian installation while still allowing for some changes'
			echo 'through interactive questions.  You will be asked to enter your'
			echo 'password to sudo.'
			echo
			echo 'The script may require a few reboots, you will be prompted each'
			echo 'time.  After the script reboots your system, please re-run the'
			echo 'same script again and it should resume automatically.'


			# Query user for requirements before proceeding
			echo
			echo 'Requirements:'
			echo "    - Debian Stable installed, / and /home partitions set up as btrfs"
			echo '    - Have patched fonts saved and unzipped in ~/fonts directory (default: Hack)'
			echo '    - Have a stable Internet connection to download packages'
			echo "    - Copied the files \"$release_name-config\", \"$release_name-gsettings.txt\", \"$release_name-dconf.txt\""
			echo '          to a ~/Setup directory and customized them for this specific computer'
			echo
			read -p 'Have all of the above been completed? [y/N] '
			if [ "${REPLY,}" != 'y' ]; then
				echo
				echo 'Please do those first, then run this script again!'
				echo
				exit
			fi

			# Create status directory
			if [ ! -d "$status_dir" ]; then
				echo
				echo "Create status directory to hold script's state between reboots..."
				confirm_cmd "mkdir $status_dir"
			fi

			touch "$status_dir/reqs_confirmed"
			echo
		fi


		# If NOT installing NVIDIA driver, check for Wayland (nvidia-driver package will disable Wayland, at least for now)
		if [ -z "$(echo "${apt_installs[@]}" | grep nvidia)" ] && [ -n "$WAYLAND_DISPLAY" ]; then
			wayland=1
		fi


		# Create temporary downloads directory
		if [ ! -d "$script_dir/downloads" ]; then
			echo
			echo 'Create temporary downloads directory to hold packages...'
			confirm_cmd "mkdir $script_dir/downloads"
		fi


		# Run commands as root (with sudo)
		sudo home="$HOME" interactive="$interactive" wayland="$wayland" bash "$release_name"-as-root
	fi


	# Install Gnome extensions
	echo
	echo 'Installing Gnome extensions...'
	echo
	gnome_ver=$(gnome-shell --version | cut -d' ' -f3)
	base_url='https://extensions.gnome.org'
	for extension in "${extension_urls[@]}"; do
		ext_uuid=$(curl -s $extension | grep -oP 'data-uuid="\K[^"]+')
		info_url="$base_url/extension-info/?uuid=$ext_uuid&shell_version=$gnome_ver"
		download_url="$base_url$(curl -s "$info_url" | sed -e 's/.*"download_url": "\([^"]*\)".*/\1/')"
		confirm_cmd "curl -L '$download_url' > '$script_dir/downloads/$ext_uuid.zip'"
		ext_dir="$HOME/.local/share/gnome-shell/extensions/$ext_uuid"
		confirm_cmd "gnome-extensions install $script_dir/downloads/$ext_uuid.zip"
		# Move all indicators to the right of the system-monitor indicator on the panel
		if [ -z $(echo "$ext_uuid" | grep 'system-monitor') ]; then
			confirm_cmd "sed -i 's/\(Main.panel.addToStatusArea([^,]*,[^,]*\)\(, [0-9]\)\?);/\1, 2);/' $ext_dir/extension.js"
		fi
	done
	echo


	# Set up fonts
	echo
	echo 'Setting up links to detect fonts...'
	echo
	confirm_cmd "ln -s $HOME/fonts $HOME/.local/share/fonts"
	confirm_cmd 'fc-cache -fv'
	echo


	# Load gsettings
	echo
	echo "Applying $release_name-gsettings.txt to Gnome..."
	echo
	if [ -n "$interactive" ]; then
		echo -e "Load all settings from gsettings.txt using:\n    $ gsettings set \$schema \$key \"\$val\""
		read -p 'Proceed? [Y/n] '
	fi
	if [ -z "$interactive" ] || [ -z "$REPLY" ] || [ "${REPLY,}" == 'y' ]; then
		while read -r schema key val; do # confirm_cmd in while loop won't work since it also uses 'read'
			echo -e "\nExecuting command...\n    $ gsettings set $schema $key \"$val\"\n"
			gsettings set $schema $key "$val"
		done < "$gsettings_path"
	fi
	echo


	# Load dconf settings
	echo
	echo "Applying $release_name-dconf.txt to Gnome..."
	echo
	confirm_cmd "dconf load / < $dconf_settings_path"
	echo


	# Ignore suspend on closing lid tweak
	if [ -n "$ignore_lid_switch" ]; then
		echo
		echo 'Applying tweak to ignore suspend on lid closing...'
		if [ ! -d "$HOME/.config/autostart" ]; then
			confirm_cmd "mkdir $HOME/.config/autostart"
		fi
		confirm_cmd 'echo -e "[Desktop Entry]\\nType=Application\\nName=ignore-lid-switch-tweak\\nExec=/usr/libexec/gnome-tweak-tool-lid-inhibitor\\n" > $HOME/.config/autostart/ignore-lid-switch-tweak.desktop'
		echo
	fi


	# Set up Neovim
	# Clone neovim-config from GitHub
	echo
	echo 'Setting up Neovim config (init.vim)...'
	echo
	if [ ! -d "$HOME/dotfiles" ]; then
		confirm_cmd "mkdir $HOME/dotfiles"
	fi
	confirm_cmd "git -C $HOME/dotfiles/ clone https://github.com/tedlava/neovim-config.git"
	confirm_cmd "mkdir $HOME/.config/nvim"
	confirm_cmd "ln -s $HOME/dotfiles/neovim-config/init.vim $HOME/.config/nvim/"
	echo
	echo 'Installing vim-plug into Neovim...'
	echo
	confirm_cmd "sh -c 'curl -fLo \"${XDG_DATA_HOME:-$HOME/.local/share}\"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'"
	echo
	echo 'About to install Neovim plugins.  During initial start up of Neovim, there may'
	echo "be errors due to settings for plugins that aren't installed yet.  Just type"
	echo 'SPACE to page through the errors so that Neovim can finish installing them.'
	echo 'When Neovim is finished, please exit Neovim by typing ":qa" and pressing ENTER.'
	echo
	echo '    *** Do NOT close the terminal window! ***'
	echo
	read -p 'Press ENTER to proceed with Neovim plugin installation. '
	confirm_cmd "nvim -c PlugInstall"
	echo


	# Load Nautilus mime types for Neovim
	echo
	echo 'Loading Nautilus mime types (open all text files with Neovim)...'
	echo
	confirm_cmd "cp -av mimeapps.list $HOME/.config/"
	echo


	# Reboot
	echo
	echo 'The script needs to reboot your system.  When it is finished rebooting,'
	echo 'please re-run the same script and it will resume from where it left off.'
	echo
	touch "$status_dir/deb_setup_part_1"
	if [ -n "$wayland" ]; then
		echo
		echo '    *** Please switch to "Gnome on Xorg" when you login next time!'
		echo
	fi
	read -p 'Press ENTER to reboot...'
	# Load patched monospace font immediately before reboot since it makes the terminal difficult to read
	if [ -n "$patched_font" ]; then
		confirm_cmd "gsettings set org.gnome.desktop.interface monospace-font-name '$patched_font'"
	fi
	systemctl reboot
	sleep 5


elif [ -f "$status_dir/deb_setup_part_1" ] && [ ! -f "$status_dir/deb_setup_part_2" ]; then
	# Enable Gnome extensions
	echo
	echo 'Enabling recently installed Gnome extensions...'
	echo
	for extension in "${extension_urls[@]}"; do
		ext_uuid=$(curl -s $extension | grep -oP 'data-uuid="\K[^"]+')
		confirm_cmd "gnome-extensions enable ${ext_uuid}"
	done


	# Install flatpaks
	if [ -n "${flatpaks[*]}" ]; then
		echo
		echo 'Installing Flatpak applications...'
		echo
		confirm_cmd "flatpak -y install ${flatpaks[@]}"
		if [ ! -d "$HOME/dotfiles/var" ]; then
			confirm_cmd "mkdir -p $HOME/dotfiles/var"
		fi
		confirm_cmd "ln -s $HOME/dotfiles/var $HOME/.var"
		echo
	fi


	# Remove downloads directory
	echo
	echo 'All 3rd-party .deb packages and Gnome extension .zip files were saved to the'
	read -p "$script_dir/downloads directory.  Delete this directory? [Y/n] "
	if [ -z "$REPLY" ] || [ "${REPLY,}" == 'y' ]; then
		confirm_cmd "rm -rfv $script_dir/downloads"
	fi
	echo


	# Final apt upgrade check (sometimes needed for nvidia)
	echo 'Final check for apt upgrades and clean up...'
	confirm_cmd 'sudo apt update && sudo apt -y upgrade && sudo apt -y autopurge && sudo apt -y autoclean'


	# Create timeshift snapshot after setup script is complete
	echo
	echo 'Create a timeshift snapshot in case you screw up this awesome setup...'
	confirm_cmd "sudo timeshift --create --comments 'Debian ${release_name^} setup script completed' --yes"
	echo


	# Settings to fix after this script...
	echo
	echo 'There are a few items that need to be setup through a GUI, or at least that'
	echo "I haven't figured out how to do them through a bash script yet..."
	echo
	echo '    - Set user picture'
	echo '    - Connect to online accounts'
	echo '    - Run "sudo dmesg" and look for RED text, which may require more firmware'
	echo '          than what was installed through this script'
	echo '    - Set up Firefox:'
	echo '          - about:config >> media.webrtc.hw.h264.enabled = true'
	echo '                (for HW acceleration during video conferencing)'
	echo '          - Set up Firefox Sync, customize toolbar, restore synced tabs, etc.'
	echo '          - Open Settings: DRM enabled, search with DuckDuckGo, remove Bing'
	if [ -n "$ssd" ]; then
		echo '          * For SSD:'
		echo '                - about:config >> browser.cache.disk.enable = false'
		echo '                - about:config >> browser.sessionstore.interval = 15000000'
		echo "          (add three 0's; this setting is how often Firefox saves sessions to"
		echo '          disk in case of a browser crash, not really needed with Firefox Sync)'
	fi
	echo
	touch "$status_dir/deb_setup_part_2"


elif [ -f "$status_dir/deb_setup_part_1" ] && [ -f "$status_dir/deb_setup_part_2" ]; then
	echo
	echo "Ted's Debian Setup Script has finished.  If you want to run it again,"
	echo "please delete the status directory at \"$status_dir/\", and then"
	echo 're-run the script.'
	echo
fi
