
# Lenovo Legion 5 Pro (16ACH6H) guide for linux setup

## Table of Contents

1. [Existing guides](#1-existing-guides)
2. [Laptop speakers](#2-laptop-speakers)
3. [Hybernate/Sleep fix](#3-hybernatesleep-fix)
4. [Enable freesync](#4-enable-freesync)
5. [Fixing refresh rate for hybrid mode (Wayland)](#5-fixing-refresh-rate-for-hybrid-mode-wayland)
   - [Getting EDID file](#51-getting-edid-file)
   - [Placing EDID file](#52-placing-edid-file)
   - [Update initramfs](#53-update-initramfs)
     - [Option 1: initramfs-tools](#option-1-initramfs-tools)
     - [Option 2: mkinitcpio.conf](#option-2-mkinitcpioconf)
   - [Optional solution (don't recommend)](#54-optional-solution-dont-recommend)



## 1. Existing guides:
- [Lenovo Legion Linux](https://github.com/johnfanv2/LenovoLegionLinux) is for various sensors, drivers, power modes, fan curves and other legion specific stuff
- https://github.com/cszach/linux-on-lenovo-legion?tab=readme-ov-file


## 2. Laptop speakers
To make laptop speakers have better quality (to match sound in Windows), you can extract impulse response information from Windows. I used [this guide](https://github.com/shuhaowu/linux-thinkpad-speaker-improvements) to extract `.irs` file for my laptop, but any laptop works for this.
To use .irs file set up any kind of sound effects software with convolver (PulseEffects/JamesDSP/...) and import .irs file to the convolver. Remember to select IR optimization if available to reduce sound latency, because raw sample makes latency very noticable.

## 3. Hybernate/Sleep fix
By default, it may not suspend pc correctly, notifying it in `dmesg` that it fails to unload Nvidia drivers. To fix you need to enable Nvidia suspend services. [Source](https://bbs.archlinux.org/viewtopic.php?id=288181)
```sh
sudo systemctl enable nvidia-suspend.service
sudo systemctl enable nvidia-hibernate.service
sudo systemctl enable nvidia-resume.service
```

## 4. Enable freesync
```sh
sudo kernelstub -a "amdgpu.freesync_video=1"
```

## 5. Fixing refresh rate for hybrid mode (Wayland)
Currently, AMD iGPU driver generates wrong EDID file (Extended Display Identification Data), but when on Nvidia graphics discrete mode (mux), or windows - it works correctly. This solution also often fixes missing resolutions or not working displays.

#### 5.1 Getting EDID file
You can get it either from running discrete GPU mode and take it from `/sys/class/drm/*/edid` or boot to Windows and export it from there. I added my laptop's EDID files.

- Use this script to list currently available display ports (disconnect external displays beforehand).
```sh
for p in /sys/class/drm/*/status; do con=${p%/status}; echo -n "${con#*/card?-}: "; cat $p; done
```
Find your laptop's display port name, mine was `eDP-1`, switching distros could change it.

#### 5.2 Placing EDID file
More info in [Arch wiki - Forcing modes and EDID](https://wiki.archlinux.org/title/kernel_mode_setting#Forcing_modes_and_EDID)

This works for Pop! OS (22.04) on Wayland.

- Place EDID file in `/usr/lib/firmware/edid` directory and add to kernel cmd
```sh
sudo cp from-linux.bin /usr/lib/firmware/edid/from-linux.bin
```
- Add EDID file in kernel boot options (either systemd-boot or edit grub, whichever you have)
Systemd-boot:
```sh
sudo kernelstub -a "drm.edid_firmware=eDP-1:edid/from-linux.bin"
```
Grub:
```sh
sudo nvim /etc/default/grub
sudo update-grub
```

#### 5.3 Update initramfs
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


### 5.4 Optional solution (don't recommend)
 You can also directly create new resolution mode in the grub/systemd-boot. You should't use this if EDID method works.


- systemd-boot:
```sh
sudo kernelstub -a "video=eDP-1:2560x1600@165.018764"
```

Caution: after adding this custom profile, it started heavy flickering at 60hz and ghosting at 165hz after trying it once, even in Windows or BIOS afterwards!

To fix this:
- Revert resolution changes in grub/systemd-boot
- You can try this, but wont always work: Disable battery in bios / plug out battery, take out AC, hold power button for few seconds and wait a few minutes.
- I found that after reverting changes just using the pc eventually fixes itself, or leaving it off overnight.

### 6. Shutdown script (KDE Brave fix)
This is not lenovo specific, but rather KDE+Brave. On shutdown/restart it doesn't kill brave correctly, losing the current session. Systemd methods doesn't work, but KDE hook works here.
```sh
mkdir -p ~/.config/plasma-workspace/shutdown/
cp pre-shutdown.sh ~/.config/plasma-workspace/shutdown/pre-shutdown.sh
chmod +x ~/.config/plasma-workspace/shutdown/pre-shutdown.sh
```