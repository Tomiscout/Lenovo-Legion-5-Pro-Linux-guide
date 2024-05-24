
# Lenovo Legion 5 Pro (16ACH6H) guide for linux setup

- [Lenovo Legion Linux](https://github.com/johnfanv2/LenovoLegionLinux) is for various sensors, drivers, power modes, fan curves and other legion specific stuff

## Other guides:
https://github.com/cszach/linux-on-lenovo-legion?tab=readme-ov-file

## Fixing refresh rate for hybrid mode (Wayland)
Currently, AMD iGPU driver generates wrong EDID file (display information metadata), but when on Nvidia graphics discrete mode (mux) - it works correctly.

Solution is to pass correct EDID file - either from running discrete GPU mode and take it from `/sys/class/drm/*/edid` or boot to windows and take it from nvidia panel. I added my laptop's EDID file.

- Use this script to list currently available display ports (mine was eDP-1, switching distros could change this):
```sh
for p in /sys/class/drm/*/status; do con=${p%/status}; echo -n "${con#*/card?-}: "; cat $p; done
```

**Replacing EDID**:
More info in [Arch wiki - Forcing modes and EDID](https://wiki.archlinux.org/title/kernel_mode_setting#Forcing_modes_and_EDID)

This works for Pop! os (22.04), if using early KMS or have any other issues - look to the wiki.

- Place EDID file in `/usr/lib/firmware/edid` directory and add to kernel cmd
```sh
sudo cp from-linux.bin /usr/lib/firmware/edid/from-linux.bin
sudo kernelstub -a "drm.edid_firmware=eDP-1:edid/from-linux.bin"
```

Some people also suggested to turn on freesync here:

```sh
sudo kernelstub -a "amdgpu.freesync_video=1"
```


**Optional solution:** You can also directly create new resolution mode in the grub/systemd-boot


- systemd-boot:
```sh
sudo kernelstub -a "video=eDP-1:2560x1600@165.018764"
```

Caution: after adding 165 hz display (without .018764 precision, havent tried with it afterwards, but assume it was needed) started heavy flickering at 60hz and ghosting at 165hz after trying it once,even in Windows afterwards!

To fix this:
- Revert resolution changes in grub/systemd-boot
- Disable battery in bios (pc turns off), take out AC, hold power button for few seconds and wait a few minutes.Also revert resolution changes before doing this.
