
# Lenovo Legion 5 Pro (16ACH6H) guide for linux setup

## Table of Contents

1. [Existing guides](#1-existing-guides)
2. [Laptop speakers](#2-laptop-speakers)
3. [Hybernate/Sleep fix](#3-hybernatesleep-fix)
4. [Enable freesync](#4-enable-freesync)
5. [Fixing refresh rate for hybrid mode (Wayland)](#5-fixing-refresh-rate-for-hybrid-mode-wayland)
6. [Fixing Brave restore session on shutdown](#6-fixing-brave-restore-session-on-shutdown)



## 1. Existing guides:
- [Lenovo Legion Linux](https://github.com/johnfanv2/LenovoLegionLinux) is for various sensors, drivers, power modes, fan curves and other legion specific stuff.
- [Plasma vantage](https://store.kde.org/p/2150610) is a plasma widget for controling Legion specific settings.
- https://github.com/cszach/linux-on-lenovo-legion?tab=readme-ov-file


## 2. Laptop speakers
To make laptop speakers have better quality (to match sound in Windows), you can extract impulse response information from Windows. I used [this guide](https://github.com/shuhaowu/linux-thinkpad-speaker-improvements) to extract `.irs` file for my laptop, but any laptop works for this.
To use .irs file set up any kind of sound effects software with convolver (EasyEffects/JamesDSP/...) and import .irs file to the convolver. Longer .irs files (500ms+) create noticable playback delay. Personaly I use 100ms sample with fade in and fade out applied to the irs.
#### 2.1 EasyEffects profile
I've added my profile for easy effects. After importing it you need to manually add correct .irs file in the convolver.

## 3. Hybernate/Sleep fix
[Some discussion over this](https://www.reddit.com/r/archlinux/comments/1g68lqc/the_latest_version_of_nvidiautils_now_supports/)
[Since Nvidia driver 570](https://www.nvidia.com/en-us/drivers/details/240524/), when you're using systemd - you can try turning on these settings
```sh
sudo nvim /etc/systemd/sleep.conf

# Unncomment
AllowSuspend=yes
AllowHibernate=yes
AllowSuspendThenHibernate=yes
```
For older drivers some services are off by default.
Pc may not suspend pc correctly, notifying it in `dmesg` that it fails to unload Nvidia drivers. To fix you need to enable Nvidia suspend services. [Source](https://bbs.archlinux.org/viewtopic.php?id=288181)
```sh
sudo systemctl enable nvidia-suspend.service
sudo systemctl enable nvidia-hibernate.service
sudo systemctl enable nvidia-resume.service
```
You can also try [Preserve video memory after suspend](https://wiki.archlinux.org/title/NVIDIA/Tips_and_tricks#Preserve_video_memory_after_suspend)

## 4. Enable freesync
```sh
sudo kernelstub -a "amdgpu.freesync_video=1"
```

## 5. Fixing refresh rate for hybrid mode (Wayland)
Currently, AMD iGPU driver generates wrong EDID file (used for describing displays) but when on Nvidia graphics discrete mode (mux), or windows - it works correctly. This solution also often fixes missing resolutions or not working displays.

Follow [this guide](EDID.md) to use the file during kernel load. 

### 6. Fixing Brave restore session on shutdown
This is not lenovo specific, but rather KDE+Brave. On shutdown/restart it doesn't kill brave correctly, losing the current session. Systemd methods doesn't work, but KDE hook works here.
```sh
mkdir -p ~/.config/plasma-workspace/shutdown/
cp pre-shutdown.sh ~/.config/plasma-workspace/shutdown/pre-shutdown.sh
chmod +x ~/.config/plasma-workspace/shutdown/pre-shutdown.sh
```
Optional: Go to `Settings -> Autostart -> Logout script` to add it from settings app.

### 7. Video hardware decoding in Chromium browsers
[Arch Wiki - Chromium](https://wiki.archlinux.org/title/Chromium#Hardware_video_acceleration)
By default arch install may not have VDPAU driver `libva-nvidia-driver` installed, so some browsers can't use it to accelerate HW video decoding.

You can go through verification steps in the [Arch wiki](https://wiki.archlinux.org/title/Hardware_video_acceleration#Translation_layers) to get it working.
```sh
#verify if VDPAU works
sudo pacman -Sy libva-utils
vainfo # lists supported codecs

#install missing driver if needed
sudo pacman -Sy libva-nvidia-driver
```

After this you can play with browser flags, as VAAPI may need to be enabled.
To test run from terminal:
```sh
brave --enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,VaapiOnNvidiaGPUs,VaapiIgnoreDriverChecks
```

Verify with nvtop and see if `DEC[  0%]` appears next to memory when watching a video.

To persist flags:
`nvim ~/.config/brave-flags.conf` or your equivalent
```sh
--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,VaapiOnNvidiaGPUs,VaapiIgnoreDriverChecks
```

Warning: `libva-nvidia-driver` may break on Nvidia driver updates, as it uses unstable API's to use NVDEC. Follow info [in projects Github](https://github.com/elFarto/nvidia-vaapi-driver)
