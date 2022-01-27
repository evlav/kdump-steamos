```
#  SPDX-License-Identifier: LGPL-2.1+
#
#  Copyright (c) 2021 Valve.
#
#  Maintained by Guilherme G. Piccoli <gpiccoli@igalia.com>
#
#
#  ###########################################################################
#  ############################  SteamOS Kdump  ##############################
#  ###########################################################################
#
#
#  This is the SteamOS Kdump/Pstore infrastructure; the goal is to collect
#  data whenever a kernel crash is detected. There is a lightweight
#  collection, that only grabs dmesg, and a more complete setting to grab the
#  whole (compressed) vmcore. See the DETAILS section below for more info.
#
#
#  ############################  HOW-TO USE IT  ##############################
#
#
#  1. Install the package with pacman if not available in your image - there's
#  a pre-built binary package in this gitlab; to check if it's already installed
#  look the pacman installed package list. Also, be sure the systemd service was
#  properly loaded by checking 'systemctl status kdump-steamos.service'.
#
#  2. Only the dmesg is collected, and by default this happens via the Pstore
#  mechanism, i.e., no extra memory should be reserved and no GRUB change is
#  required. If 'lsmod' shows "ramoops", then Pstore is in use.
#
#  3. The logs are stored in a ZIP file at "/home/.steamos/offload/var/kdump/";
#  besides the dmesg with some extra information, the image build version,
#  running kernel version and dmidecode are stored in this ZIP file as well.
#  This file is named as: "steamos-SERIAL-STEAM_USER.timestamp.zip", where
#  SERIAL is the machine serial (from dmidecode), STEAM_USER is the Steam
#  account name (based on the last logged Steam user) and timestamp tz is UTC.
#
#  4. (IMPORTANT) Please, test the infrastructure in order to see if a dummy
#  crash log is collected before using it to try debugging complex issues.
#  In order to do that, login to a shell and execute, as root user:
#  'echo 1 > /proc/sys/kernel/sysrq ; echo c > /proc/sysrq-trigger'
#
#  This action will trigger a dummy crash and reboot the system; check if there
#  is a ZIP file with the crash logs in the directory described in (3).
#
#  5. Some tunnings are available at "/etc/default/kdump"; for example users
#  can choose Kdump instead of Pstore (USE_PSTORE_RAM), and if using Kdump,
#  collect the full vmcore (FULL_COREDUMP). The vmcore is not stored in the
#  ZIP file, but it's saved in "/home/.steamos/offload/var/kdump/crash/".
#  NOTICE that, if Kdump is used instead of Pstore, the following flags are
#  needed in GRUB cmdline: "crashkernel=192M crash_kexec_post_notifiers" and
#  a regular reboot is necessary.
#
#
#  ##############################  DETAILS  ##################################
#
#  CAVEATS / INSTRUCTIONS
#  ###########################################################################
#  (a) Currently, we don't automatically edit GRUB config; see TODO (1) below.
#  This is not required if Pstore is used (which is the default).
#
#  In case Kdump is used, boot-time reserved memory is required, check step (5)
#  in the HOW-TO above. The memory amount was empirically determined - setting
#  144M wasn't enough and 160M is unstable, so 192M seems good enough. This
#  amount might change in future kernel versions, requiring tests using the
#  approach suggested in the step (4) above.
#
#  (b) The kdump-steamos package requires a RW rootfs in case it's not currently
#  embedded in your image. Users can make use of 'tune2fs' or 'steamos-readonly'
#  in order to make the rootfs RW, since it's RO by default. Also, we assume the
#  nvme partitioning  scheme is default across all versions (A/B, nvme0n1p4 / p5
#  are the root ones, etc) and didn't change with new updates, for example. Both
#  Kdump and Pstore facilities relies in mounting partitions.
#
#  (c) Due to a post-transaction hook exec'ed by libalpm (90-dracut-install.hook)
#  unfortunately after installing the kdump-steamos package *all* initramfs
#  images are recreated - this is not necessary, we're thinking how to prevent
#  that, but for now be prepared: the installation take some (long) minutes only
#  due to that ={
#
#  (d) Unfortunately makedumpfile from Arch Linux is not available on official
#  repos, only in AUR. But it is available on Holo, so we make use of that.
#  Also, a discussion was started to get it included on official repos:
#  https://lists.archlinux.org/pipermail/aur-general/2022-January/036767.html
#  https://aur.archlinux.org/packages/makedumpfile/#comment-843853
#
#
#  TODOs
#  ###########################################################################
#  (1) We'd like to be able to automatically edit GRUB and recreate its config
#  file - implementation tests are ongoing.
#
#  (2) The log submission mechanism is incomplete - we save the logs as a local
#  ZIP file (as discussed in the HOW-TO), but they aren't submitted to a remote
#  Valve server. There's an API in-place, so the implementation is starting.
#
#  (3) Hopefully we can fix/prevent the unnecessary re-creation of all initramfs
#  images - it happens due to our package installing files on directory
#  "/usr/lib/dracut/modules.d" which triggers the unfortunate initramfs rebuild.
#
#  (4) We have a "fragile" way of determining a mount point required for Kdump;
#  this is something to improve maybe, in order to make the Kdump more reliable.
#
#  (5) Pstore ramoops backend has some limitations that we're discussing with
#  the kernel community - right now we can only collect ONE dmesg and its
#  size is truncated on "record_size" bytes, not allowing a file split like
#  efi-pstore; thankfully we still can collect 2MiB dmesg, but hopefully we can
#  improve that upstream.
#
#  (6) Add a more reliable reboot mechanism - we had seen issues in the past
#  with "reboot -f", and relying in sysrq reboot as a quirk managed to be a safe
#  option, so this is something to think about. Should be easy to implement.
#
#  (7) Maybe a good idea would be to allow creating the minimum image for any
#  specified kernel, not only for the running one (which is what we do now).
#  Low-priority idea, easy to implement.
#
```
