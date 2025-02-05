This is a guide on how to install custom edid file to linux.

#### 1. Getting EDID file


Use this script to list currently available display ports (disconnect external displays beforehand).
```sh
for p in /sys/class/drm/*/status; do con=${p%/status}; echo -n "${con#*/card?-}: "; cat $p; done
```
Find your laptop's display port name. For laptop displays its usually `eDP-1`
Extract the file
```sh
sudo cp /sys/class/drm/eDP-1/edid ~/edid.bin
```

For me when running in Nvidia discrete GPU mode - resolutions and refresh rates were fine, so you can extract it its same for you. 

Also it's possible to export it from Windows, but need to additionaly patch the file with updated checksum, or linux kernel wont load it. 

I've included my laptop's EDID files.

#### 2. Placing EDID file
More info in [Arch wiki - Forcing modes and EDID](https://wiki.archlinux.org/title/kernel_mode_setting#Forcing_modes_and_EDID)

This works for Pop! OS (22.04) on Wayland.

1. Place EDID file in `/usr/lib/firmware/edid` directory and add to kernel cmd
```sh
sudo mkdir -p /usr/lib/firmware/edid/
sudo cp from-linux.bin /usr/lib/firmware/edid/from-linux.bin
```

#### 3 Update initramfs
We need to move edid file to initramfs.
#### initramfs-tools (Debian, Ubuntu, PopOS)
Create hook file `/etc/initramfs-tools/hooks/edid`
```sh
sudo nvim /etc/initramfs-tools/hooks/edid
```
Add this script
```bash
#!/bin/sh

PREREQ=""

prereqs() {
    echo "$PREREQ"
}

case "$1" in
    prereqs)
        prereqs
        exit 0
        ;;
esac

. /usr/share/initramfs-tools/hook-functions

copy_files() {
    local src_dir="/lib/firmware/edid/"
    local dest_dir="${DESTDIR}/usr/lib/firmware/edid/"

    if [ -d "$src_dir" ]; then
        mkdir -p "$dest_dir"
        find "$src_dir" -type f | while read -r file; do
            cp -a "$file" "$dest_dir"
        done
    fi
}

copy_files
```

Add execution rights for this hook:
```sh
sudo chmod +x edid
```

Update initramfs and reboot
```sh
sudo update-initramfs -u
sudo reboot
```

#### mkinitcpio (Arch)
[Reference](https://www.reddit.com/r/pop_os/comments/soo7eh/comment/j40hyfa/)

You need to edit your /etc/mkinitcpio.conf (e.g. via sudo nano /etc/mkinitcpio.conf) and add a new hook (I called it `edid` at the very end of this line):
```
HOOKS=(base udev autodetect keyboard keymap modconf block filesystems fsck edid)
```
Now that mkinitpio will call our hook (edid), we need to actually create the hook. To do so, create the file `/etc/initcpio/install/edid` and place this script inside:
```bash
#! /usr/bin/bash

build() {
  msg ":: Copying EDIDs from /usr/lib/firmware/edid/"
  add_file /usr/lib/firmware/edid/*
}

help() {
  echo "This hook copies EDIDs into initramfs."
}
```
Add execution rights for this hook:
```sh
sudo chmod +x edid
```

Finally, invoke mkinitcpio and reboot:
```sh
sudo mkinitcpio -P
sudo reboot
```

#### dracut (Fedora, RHEL, Endeavor OS)
[Source](https://ryan.lovelett.me/posts/install-patched-edid-on-fedora/)

Create config file to install edid file
```sh
sudo tee "/etc/dracut.conf.d/00-legion5-edid.conf" > /dev/null <<'EOF'
install_items+="/usr/lib/firmware/edid/from-linux.bin"
EOF
```
Then regenerate dracut
```sh
sudo dracut -f
```

### 4. Add EDID file in [kernel boot options](https://wiki.archlinux.org/title/Kernel_parameters)
- Grub:
```sh
sudo nvim /etc/default/grub
sudo update-grub
```
- Systemd-boot (Pop-os with kernelstub):
```sh
sudo kernelstub -a "drm.edid_firmware=eDP-1:edid/from-linux.bin"
```

- Systemd-boot (manual)
```sh
sudo ls /efi/loader/entries # List boot entries and select first one (not fallback)
sudo nvim /efi/loader/entries/<your_entry>.conf
# Add this to the end of your "options" line
options ... drm.edid_firmware=eDP-1:edid/from-linux.bin
```



# Optional solution, don't recommend
 You can also directly create new resolution mode in the grub/systemd-boot. You should't use this if EDID method works.


systemd-boot:
```sh
sudo kernelstub -a "video=eDP-1:2560x1600@165.018764"
```

Caution: after adding this custom profile, it can start heavy flickering, that will create artifacts on the monitor. This can persist even in Windows or BIOS afterwards!

To fix this:
- Revert resolution changes in grub/systemd-boot
- You can try this, but wont always work: Disable battery in bios / plug out battery, take out AC, hold power button for few seconds and wait a few minutes.
- I found that after reverting changes just using the pc eventually fixes itself, or leaving it off overnight.
