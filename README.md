# ubuntu-setup
My setup script for Ubuntu installations (since my latest laptop won't run
Debian stable (kernel is too old to work with network card and I can't update
to the backports kernel without an Internet connection)).

# Requirements
- Ubuntu installed, / and /home partitions set up as btrfs
- Have patched fonts saved and unzipped in ~/fonts directory (default: Hack)
- Have a stable Internet connection to download packages
- Copied the files "jammy-config", "jammy-dconf.txt", "jammy-gsettings.txt" to a ~/Setup directory and customized them for this specific computer

# How to use
I highly recommend that you save your config files for each computer into
~/Setup so that if/when you upgrade to a newer version of this script for the
next version of Ubuntu, that you won't lose the settings/config files that are
needed for this specific computer.

    $ mkdir ~/Setup
    $ cd ~/Setup
    $ git clone https://github.com/tedlava/ubuntu-setup.git
    $ cp -av ubuntu-setup/jammy-config ubuntu-setup/jammy-dconf.txt ubuntu-setup/jammy-gsettings.txt ./
    $ nano jammy-config # Make changes to the config, add/remove packages, or other settings
    $ nano jammy-dconf.txt
    $ nano jammy-gsettings.txt
    $ cd ubuntu-setup/
    $ ./jammy-setup.sh
