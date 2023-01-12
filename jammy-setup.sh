#!/bin/bash

# Unfortunately, my new laptop needs a more recent kernel than what Debian
# stable currently offers.  A backported kernel would work, but unfortunately I
# also need a backported kernel in order for my too-new network card to work!
# And I cannot install a backported kernel without an Internet connection!  The
# solution for now, is to switch back to Ubuntu until Debian Bookworm is
# released (summer 2023), which is a long time...  I also tried Debian Testing
# (Bookworm) and Sid, and even though both of those will install just fine, I
# really don't like all of the changes that come with those testing/unstable
# versions.  Over the last two days, in both testing and unstable, video
# playback was completely broken in both totem AND vlc!  WTF...  Stable +
# backports is really the best solution, but I can't seem to figure that out,
# so I'm making a setup script for Ubuntu to automate some of the dumb shit,
# like removing/disabling snaps.


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
echo "Ted's Ubuntu Setup Script"
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


while getopts ':hi' opt; do
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


if [ ! -f "$status_dir/setup_part_1" ] && [ ! -f "$status_dir/setup_part_2" ]; then
	if [ -z "$skip_to_ext" ]; then
		if [ ! -f "$status_dir/reqs_confirmed" ]; then
			echo 'This script automates some common settings that I use for'
			echo 'every Ubuntu installation while still allowing for some changes'
			echo 'through interactive questions.  You will be asked to enter your'
			echo 'password to sudo.'
			echo
			echo 'The script may require a few reboots, you will be prompted each'
			echo 'time.  After the script reboots your system, please re-run the'
			echo 'same script again and it should resume automatically.'


			# Query user for requirements before proceeding
			echo
			echo 'Requirements:'
			echo "    - Ubuntu installed, / and /home partitions set up as btrfs"
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


		# Create temporary downloads directory
		if [ ! -d "$script_dir/downloads" ]; then
			echo
			echo 'Create temporary downloads directory to hold packages...'
			confirm_cmd "mkdir $script_dir/downloads"
		fi


		# Remove old configuration in .dotfiles
		if [ -n "$rm_dotfiles" ] && [ ! -f "$status_dir/dotfiles_removed" ]; then
			echo
			echo 'Removing old .dotfiles (from prior Linux installation)...'
			confirm_cmd "sudo rm -rf $HOME/.*"
			confirm_cmd "cp -av /etc/skel/. $HOME/"
			touch "$status_dir/dotfiles_removed"
			echo
		fi


		# Disable suspend while on AC power
		if [ ! -f "$status_dir/disabled_ac_suspend" ]; then
			echo
			echo 'Disable suspend while on AC power...'
			confirm_cmd "gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'"
			touch "$status_dir/disabled_ac_suspend"
		fi


		# Run commands as root (with sudo)
		sudo home="$HOME" interactive="$interactive" gdmsession="$GDMSESSION" bash "$release_name"-as-root
		if [ "$?" != '0' ]; then
			exit
		fi
	fi


	# Set up ffmpegthumbnailer
	echo
	echo 'Setting up ffmpegthumbnailer for video thumbnails in nautilus...'
	confirm_cmd "mkdir $HOME/.local/share/thumbnailers"
	confirm_cmd "ln -s /usr/share/thumbnailers/ffmpegthumbnailer.thumbnailer $HOME/.local/share/thumbnailers/ffmpegthumbnailer.thumbnailer"
	confirm_cmd "rm -rf $HOME/.cache/thumbnails/*"


	# Make sure user is in a Gnome session instead of an Ubuntu session
	if [ "$GDMSESSION" != 'gnome' ] && [ "$GDMSESSION" != 'gnome-xorg' ]; then
		echo
		echo 'The next section requires you to switch to the vanilla Gnome desktop,'
		echo 'NOT the customized Ubuntu desktop.  Please logout, click on your name,'
		echo 'then click on the gear icon (bottom right corner) to change the desktop'
		echo 'session that you will log into.'
		echo
		echo '    *** Please switch to "Gnome" or "Gnome on Xorg" when you login next time!'
		echo
		echo 'When you log back in, please re-run the script to continue from here...'
		echo
		exit
	fi


	# Open display settings to possibly change scaling
	echo
	echo 'Newer computers with HiDPI displays may need to adjust scaling settings. When'
	echo 'you are finished, close the window to continue with the setup script...'
	echo
	read -p 'Press ENTER to open Display Settings...'
	confirm_cmd 'gnome-control-center display'
	
	
	# Change default apps (VLC instead of Videos/Totem)
	echo
	echo 'The default Gnome Videos player never seems to do very well.  Switch the default'
	echo 'video player to VLC, then close the window to continue the setup script...'
	echo
	read -p 'Press ENTER to open Display Settings...'
	confirm_cmd 'gnome-control-center default-apps'

	# Install Gnome extensions
	echo
	if [ -n "${extension_urls[*]}" ]; then
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
	fi


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
	# confirm_cmd in while loop won't work since it also uses 'read', so
	# confirmation must be asked beforehand if $interactive is true
	if [ -n "$interactive" ]; then
		echo -e "Load all settings from gsettings.txt using:\n    $ gsettings set \$schema \$key \"\$val\""
		read -p 'Proceed? [Y/n] '
	fi
	if [ -z "$interactive" ] || [ -z "$REPLY" ] || [ "${REPLY,}" == 'y' ]; then
		while read -r schema key val; do
			echo -e "\nExecuting command...\n    $ gsettings set $schema $key \"$val\"\n"
			gsettings set $schema $key "$val"
		done < "$gsettings_path"
	fi
	echo


	# Load dconf settings
	echo
	echo "Applying $release_name-dconf.txt to Gnome..."
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
	confirm_cmd "sh -c 'curl -fLo \"${XDG_DATA_HOME:-$HOME/.local/share}\"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'"
	echo
	echo 'About to install Neovim plugins.  When Neovim is finished, please exit'
	echo 'Neovim by typing ":qa" and pressing ENTER.'
	echo
	echo '    *** Do NOT close the terminal window! ***'
	echo
	read -p 'Press ENTER to proceed with Neovim plugin installation. '
	confirm_cmd "nvim -c PlugInstall"
	echo


	# Load Nautilus mime types for Neovim
	echo
	echo 'Loading Nautilus mime types (open all text files with Neovim)...'
	confirm_cmd "cp -av mimeapps.list $HOME/.config/"
	echo


	# Reboot
	echo
	echo 'The script needs to reboot your system.  When it is finished rebooting,'
	echo 'please re-run the same script and it will resume from where it left off.'
	echo
	touch "$status_dir/setup_part_1"
	read -p 'Press ENTER to reboot...'


	# Load patched font JUST before reboot since it makes the terminal difficult to read
	if [ -n "$patched_font" ]; then
		confirm_cmd "gsettings set org.gnome.desktop.interface monospace-font-name '$patched_font'"
	fi
	systemctl reboot
	sleep 5


elif [ -f "$status_dir/setup_part_1" ] && [ ! -f "$status_dir/setup_part_2" ]; then
	# Enable Gnome extensions
	if [ -n "${extension_urls[*]}" ]; then
		echo
		echo 'Enabling recently installed Gnome extensions...'
		echo
		for extension in "${extension_urls[@]}"; do
			ext_uuid=$(curl -s $extension | grep -oP 'data-uuid="\K[^"]+')
			confirm_cmd "gnome-extensions enable ${ext_uuid}"
		done
	fi


	# Install flatpaks
	if [ -n "${flatpaks[*]}" ]; then
		echo
		echo 'Installing Flatpak applications...'
		echo
		confirm_cmd "flatpak -y install ${flatpaks[@]}"
		if [ ! -d "$HOME/dotfiles/var" ]; then
			confirm_cmd "mkdir -p $HOME/dotfiles/var"
		fi
		confirm_cmd "ln -s $HOME/dotfiles/var $HOME/.var" # Symlinked .var doesn't work with Steam, but Steam runs better as a native .deb anyway!
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
	confirm_cmd "sudo timeshift --create --comments 'Ubuntu GNOME (${release_name}) setup script completed' --yes"
	echo


	# Settings to fix after this script...
	echo
	echo 'There are a few items that need to be setup through a GUI, or at least that'
	echo "I haven't figured out how to do them through a bash script yet..."
	echo
	echo '    - Set user picture'
	echo '    - Connect to online accounts'
	echo '    - Set up Firefox:'
	echo '          - Set up Firefox Sync, customize toolbar, restore synced tabs, etc.'
	echo '          - Open Settings: DRM enabled, search with DuckDuckGo, remove Bing'
	echo '          - about:config >> media.webrtc.hw.h264.enabled = true'
	echo '                (for HW acceleration during video conferencing)'
	if [ -n "$ssd" ]; then
		echo '          * For SSD:'
		echo '                - about:config >> browser.cache.disk.enable = false'
		echo '                - about:config >> browser.sessionstore.interval = 15000000'
		echo "          (add three 0's; this setting is how often Firefox saves sessions to"
		echo '          disk in case of a browser crash, not really needed with Firefox Sync)'
	fi
	echo
	touch "$status_dir/setup_part_2"


elif [ -f "$status_dir/setup_part_1" ] && [ -f "$status_dir/setup_part_2" ]; then
	echo
	echo "Ted's Ubuntu Setup Script has finished.  If you want to run it again,"
	echo "please delete the status directory at \"$status_dir/\", and then"
	echo 're-run the script.'
	echo
fi
