```
#  SPDX-License-Identifier: LGPL-2.1+
#
#  Copyright (c) 2021 Valve.
#
#  Code by Guilherme G. Piccoli <gpiccoli@igalia.com>
#
#
#  ###########################################################################
#  ############################  SteamOS Kdump  ##############################
#  ###########################################################################
#
#  This is the first version of SteamOS Kdump infrastructure. The goal is to
#  collect data whenever a kernel crash is detected. There is a lightweight
#  collection, that only grabs dmesg, and a more complete setting to grab the
#  whole (compressed) vmcore. The tunnings are available at /etc/default/kdump.
#
#  Also, the infrastructure is able to configure and save pstore-RAM logs.
#
#  After installation and a reboot, things should be all set EXCEPT for GRUB
#  config - please check the CAVEATS/INSTRUCTIONS section below. Notice the
#  package is under active development, this version should still be considered
#  a kind of "Proof Of Concept" - improvements are expected in the near future.
#  Thanks for testing!!!
#
#
#  CAVEATS / INSTRUCTIONS
#  ###########################################################################
#  (a) For now, we  don't automatically edit any GRUB config, so the minimum
#  necessary action after installing this package is to add "crashkernel=160M"
#  to your GRUB config in order subsequent boots pick this setting and do reserve
#  the memory, or else kdump cannot work. The memory amount was empirically
#  determined - 128M wasn't enough and 144M is unstable, so 160M seems good enough.
#  If you prefer to rely on pstore-RAM, no GRUB setting should be required; this
#  is currently the default (see /etc/default/kdump).
#
#  (b) It requires (obviously) a RW rootfs - we've used tune2fs in order to make
#  it read-write, since it's RO by default. Also, we assume the nvme partition
#  scheme is default across all versions and didn't change with new updates
#  for example - kdump relies in mounting partitions, etc.
#
#  (c) Due to a post-transaction hook executed by libalpm (90-dracut-install.hook),
#  unfortunately after installing the kdump-steamos package *all* initramfs images
#  are recreated - this is not necessary, we're thinking on how to prevent that,
#  but for now be prepared: the installation take some (long) minutes due to that ={
#
#  (d) Unfortunately makedumpfile from Arch Linux is not available on official
#  repos, only in AUR. So, we're hereby _packing the binary_ with all the scripts,
#  which is a temporary workaround and should be resolved later - already started
#  to "lobby" for package inclusion in the official channels:
#  https://aur.archlinux.org/packages/makedumpfile/#comment-843853
#
#
#  TODOs (for now - we expect to have more after some testing by the colleagues)
#
#  (1) We'd like to be able to automatically edit GRUB and recreate its config
#  file - after some future discussion on the proper parameters, this is expected
#  to be added to the package.
#
#  (2) Hopefully we can fix/prevent the unnecessary re-creation of all initramfs
#  images - it happens due to our pkg installing files on /usr/lib/dracut/modules.d
#  which is a trigger for this initramfs recreation.
#
#  (3) We have a "fragile" way of determining a mount point required for kdump;
#  this is something to improve in order to make the kdump more reliable.
#
#  (4) Add a more reliable reboot mechanism - we had seen issues with "reboot -f"
#  in the past and relying in sysrq reboot as a quirk managed to be a safe option,
#  so this is something to think about here. Should be easy to implement.
#
#  (5) Maybe a good idea would be to allow creating the minimum image for any
#  specified kernel, not only for the running one (which is what we do now).
#  Low-priority idea, easy to implement.
#
#  (6) Pstore ramoops backend has some limitations that we're discussing with
#  the kernel community - right now we can only collect ONE dmesg and its
#  size is truncated on "record_size" bytes, not allowing a file split like
#  efi-pstore; hopefully we can improve that.
#
```
