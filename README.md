# voidLuksSetup
Bash script for installing Void Linux with disk encryption.

# References
Much of what is done in this script came straight from the official [Void Documentation](https://docs.voidlinux.org/installation/guides/fde.html). I just adapted commands where necessary to make them script-able, as well as made a number of assumptions/personal choices as to what additional configuration/utilities should be added.

I also used the [Arch Wiki](https://wiki.archlinux.org/) as a reference.

# Assumptions
There are a number of assumptions that were made for this script. A (non-exhaustive) list of the more fundatmental ones is:
1. Assumes an x86_64 system
2. Assumes installation from a running Void live image
3. Assumes an EFI/GPT installation
4. Assumes that the entire installation (boot loader, root, home) are on the same drive
5. Assumes the installation will occupy the entire drive (the whole drive will be wiped pior to installation)
6. The installation will use separate partitions (volumes) for swap and /home

There are a number of other smaller assumptions made in various default values populated in the script, but for the most part these are meant to be easily changeable by the user by editing the fields at the start of script file.

# Usage
1. Create a Void live image (instructions here: https://docs.voidlinux.org/installation/live-images/prep.html), can use the base image or whatever 'flavor' you'd like (it won't impact the installation). The login for the live images is user:anon, password: voidlinux
2. From the terminal, run: sudo xbps-install -Suy xbps; sudo xbps-install -Sy git
3. Optionally install a different text editor. sudo xbps-install -Sy *editor*, where editor is the package name of the editor to install. For a console based editor I like nano (rather than the stock vi). If running a graphical live image, you can install something like gedit or kate5. 
4. Run: git clone https://github.com/TJ-Hooker15/voidLuksSetup.git; cd voidLuksSetup
5. Open void_luks_setup.bash in the editor. Edit the fields in the first section based on your configuration, as per the comments in the script. Optionally, you can also edit the fields in the 2nd section.
6. Run: chmod +x void_luks_setup.bash
7. Run: sudo ./void_luks_setup.bash
8. When prompted, enter the desired passwords for LUKS encryption, root user, and non-root user
9. When prompted, select the desired drive for installation
10. Depending what was previously on the installation drive, some warning(s) may be displayed about LUKS and/or filesystem headers being already present on the drive, this is not an issue.
11. Wait for the installation to complete
12. Near the end of the install script there may be some errors printed similar to: "cannot remove '[something]': No such file or directory". This is generally expected, as it is the script trying to disable services that may not have been enabled in the first place.
13. Once the installation has completed, the user will be asked whether to automatically reboot.
