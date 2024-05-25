
# Lenovo Legion 5 Pro (16ACH6H) guide for linux setup

- [Lenovo Legion Linux](https://github.com/johnfanv2/LenovoLegionLinux) is for various sensors, drivers, power modes, fan curves and other legion specific stuff

## Other guides:
https://github.com/cszach/linux-on-lenovo-legion?tab=readme-ov-file

## Fixing refresh rate for hybrid mode (Wayland)
Currently, AMD iGPU driver generates wrong EDID file (Extended Display Identification Data), but when on Nvidia graphics discrete mode (mux), or windows - it works correctly. This solution also often fixes missing resolutions or not working displays.

#### 1. Getting EDID file
You can get it either from running discrete GPU mode and take it from `/sys/class/drm/*/edid` or boot to Windows and export it from there. I added my laptop's EDID files.

- Use this script to list currently available display ports (disconnect external displays beforehand).
```sh
for p in /sys/class/drm/*/status; do con=${p%/status}; echo -n "${con#*/card?-}: "; cat $p; done
```
Find your laptop's display port name, mine was `eDP-1`, switching distros could change it.

#### 2. Placing EDID file
More info in [Arch wiki - Forcing modes and EDID](https://wiki.archlinux.org/title/kernel_mode_setting#Forcing_modes_and_EDID)

This works for Pop! OS (22.04) on Wayland.

- Place EDID file in `/usr/lib/firmware/edid` directory and add to kernel cmd
```sh
sudo cp from-linux.bin /usr/lib/firmware/edid/from-linux.bin
```
- Add EDID file in kernel boot options (either systemd-boot or edit grub, whichever you have)
```sh
sudo kernelstub -a "drm.edid_firmware=eDP-1:edid/from-linux.bin"
```

#### 3. Update initramfs
Ubuntu based distros use initramfs-tools, while others may use mkinitcpio.conf
#### Option 1: initramfs-tools
Create hook file `/etc/initramfs-tools/hooks/edid`
```sh
sudo vim /etc/initramfs-tools/hooks/edid
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

#### Option 2: mkinitcpio.conf
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


**Optional solution (dont recommend):** You can also directly create new resolution mode in the grub/systemd-boot. You should't use this if EDID method works.


- systemd-boot:
```sh
sudo kernelstub -a "video=eDP-1:2560x1600@165.018764"
```

Caution: after adding this custom profile, it started heavy flickering at 60hz and ghosting at 165hz after trying it once, even in Windows or BIOS afterwards!

To fix this:
- Revert resolution changes in grub/systemd-boot
- You can try this, but wont always work: Disable battery in bios / plug out battery, take out AC, hold power button for few seconds and wait a few minutes.
- I found that after reverting changes just using the pc eventually fixes itself, or leaving it off overnight.


## Enable freesync
```sh
sudo kernelstub -a "amdgpu.freesync_video=1"
```
