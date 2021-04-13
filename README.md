# uvi - Universal Void Installer
Universal bash script for installing Void Linux even with disk encryption. Also performs some post-install configuration, such as installing graphics drivers, a graphical DE, and other applications, enabling/disabling services, creating a non-root user, etc. The script is designed to be user-configurable, by modifying a number of text fields near the start of the script prior to execution.

# References
Much of what is done in this script came almost straight from the official [Void Documentation](https://docs.voidlinux.org/installation/guides/fde.html). I just adapted commands where necessary to make them script-able, as well as made a number of assumptions/personal choices as to what additional configuration/utilities should be added.

I also used the [Arch Wiki](https://wiki.archlinux.org/) as a reference.

# Assumptions
A (non-exhaustive) list of the more fundatmental assumptions made by this script:
1. Assumes an x86_64 system (basically any desktop/laptop within the last ~15 years).
2. Assumes installation from a running Void live image
3. Assumes an EFI/GPT installation (I believe this should be compatible with the vast majority of systems that are less than ~10 years old)
4. Assumes that the entire installation (boot loader, root, home) is on the same drive
5. Assumes the installation will occupy the entire drive (the whole drive will be wiped pior to installation)
6. The installation will use a separate partition (volume) for swap (and optionally for home), in addition to the root partition (volume)

There are a number of other smaller assumptions made in various default values populated in the script, but for the most part these are meant to be easily changeable by the user by editing the fields located near the start of the script file.

# Usage
1. Create a Void live image (instructions [here](https://docs.voidlinux.org/installation/live-images/prep.html)). You can use the base image or whichever graphical 'flavor' you'd like (it won't impact the new Void install you're creating).
2. Boot the live image, the login will be user:anon, password: voidlinux
3. From the terminal, run: *sudo xbps-install -Suy xbps*
4. Download the script. Either do so manually, or use git: *sudo xbps-install -Suy git; git clone https<nolink>://github.com/TJ-Hooker15/voidLuksSetup.git*
5. Optionally, install your desired text editor (the pre-installed editor(s) available will vary depending on which live image you're using): *sudo xbps-install -Suy [editor]*, where [editor] is the package name of the editor to install. For a console based editor I like nano. If running a graphical live image, you can install something like gedit or kate5. 
6. Open void_luks_setup.bash in the editor (e.g. *nano void_luks_setup.bash*). Edit the fields in the first section based on your configuration, as per the comments in the script. Optionally, you can also edit the fields in the next two sections as well. Even if you don't configure the latter two sections prior to installation, it should generally be fairly easy to alter in the future by installing/removing packages and enabling/disabling services once you're up and running.
7. Run: *chmod +x uvi.bash; sudo ./uvi.bash*
9. When prompted, enter the desired passwords for LUKS encryption, root user, and non-root user
10. When prompted, select the desired drive for installation
11. Depending on what was previously on the installation drive, some warning(s) may be displayed about LUKS and/or filesystem signatures being already present on the drive, this is not an issue.
12. Wait for the installation to complete
14. Once the installation has completed, the user will be asked whether to automatically reboot.
