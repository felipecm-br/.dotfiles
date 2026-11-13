# Omarchy 4.5 Fresh Install on Apple Silicon

How to wipe the current Linux install on this MacBook Pro 14" (M1 Pro, 2021, 500 GB) and put Omarchy 4.5 on it again. This page covers only the disk and the Mac-side steps. Restoring the dotfiles afterwards is in the [bootstrap checklist](../../.shell/install/README.md#3-fresh-omarchy-install).

## How Omarchy 4.5 installs on a Mac

- **Installer.** A native macOS app, installed with `brew install omacom/mac/omarchy` or from the DMG. No USB stick is needed. It runs a "pinned Asahi-based engine", so Omarchy still sits on the Asahi stack. It is not the older `omarchy-mac` script that installed through Asahi Alarm, which is how the current system was installed.
- **Supported Macs.** M1, M2 and M3 MacBooks and the MacBook Neo. M3 and Neo are marked untested. M4 and later are not supported.
- **Requirements.** macOS 15 or newer and a macOS administrator account. macOS has to stay on the disk, because the app gets its space by shrinking the macOS APFS container.
- **Disk encryption.** The new system encrypts the disk on first boot with a password, and **there is no recovery key**. Store that password in Bitwarden before you reboot.

## Disk split

The app shows a disk bar with macOS, free space and Omarchy, and you set the Omarchy size in whole gigabytes. It recommends leaving macOS about **38 GB free** and warns if your plan leaves less.

| | Before (13 Nov 2026) | Recommended |
| :--- | :--- | :--- |
| macOS | 230 GB | **~110 GB** (never below ~80 GB, so macOS updates have room) |
| Linux | 227 GB, 165 GB used | **~350 GB** (up to ~380 GB if macOS is rarely used) |

Most of the space goes to `~/dev` (43 GB, growing with Rust `target/` directories), `~/.cache` (17 GB) and Docker (about 15 GB). See the `target/` rules in [AGENTS.md](../../AGENTS.md) and use `dev-gc` to keep it under control.

## Steps

1. **Back up off the machine.** `~/backup` lives on the Linux partition that the install erases. Copy it to an external disk or to cloud storage first. The installer README warns that a failed resize "can leave all Omarchy partitions removed and the space unallocated".
2. **Update macOS** to 15 or newer.
3. **Remove the old install.** In the app, choose *Installation → Remove Omarchy…*. That deletes the Omarchy partitions and grows macOS back over them. The app refuses layouts it does not recognise, and a script-based (Asahi Alarm) install may be one of them. In that case remove it by hand from macOS, following the [Asahi partitioning cheatsheet](https://asahilinux.org/docs/sw/partitioning-cheatsheet/). On Linux the current layout looks like this:

   | Linux name | Size | Role | Action |
   | :--- | :--- | :--- | :--- |
   | `nvme0n1p1` | 500 MB | Apple iBoot system container | **keep** |
   | `nvme0n1p2` | 230 GB | macOS APFS container (`disk0s2`) | **keep** |
   | `nvme0n1p3` | 2.3 GB | Asahi stub APFS container | delete |
   | `nvme0n1p4` | 500 MB | Linux EFI (vfat) | delete |
   | `nvme0n1p5` | 227 GB | Linux root (ext4) | delete |
   | `nvme0n1p6` | 5 GB | Apple recovery container | **never delete** |

   Confirm each partition with `diskutil list` in macOS before you delete it, because macOS numbers them differently. Then give the space back to macOS with `sudo diskutil apfs resizeContainer disk0s2 0`. If the resize refuses, a pending macOS update is often the reason. Install it and try again.
4. **Install.** Run the app, set Omarchy to about 350 GB, and let it shrink macOS.
5. **First boot.** Set the encryption password and save it in Bitwarden. Then follow the [bootstrap checklist](../../.shell/install/README.md#3-fresh-omarchy-install).

## Sources

- [Omarchy 4.5 announcement](https://omarchy.org/news/2026/11/omarchy-4-5/)
- [omacom/omarchy-mac-installer README](https://github.com/omacom/omarchy-mac-installer)
- [Asahi Linux partitioning cheatsheet](https://asahilinux.org/docs/sw/partitioning-cheatsheet/)
