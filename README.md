```
#  ###########################################################################
#  ##################### kdumpst: pstore + kdump tooling #####################
#  ###########################################################################
#
#
#  This is the kdumpst infrastructure; the goal is to collect data whenever
#  a kernel crash/panic is detected. There is a lightweight collection, that
#  only grabs dmesg, and a more complete setting to grab the whole (compressed)
#  vmcore. It supports both pstore (for the lightweight collection) and kdump
#  for both collecting dmesg or even the full vmcore. In kdump "mode", both
#  initcpio and dracut initramfs images are supported. The focus is Arch Linux
#  (and spin-off distros), but should work in most systemd-based distros.
#
#
#  ############################  HOW-TO USE IT  ##############################
#
#  1. Install the package with pacman if not available in your system; to check
#  if it's already installed look the pacman installed package list. Also, be
#  sure the systemd service was properly loaded by checking
#  'systemctl status kdumpst-init.service'.
#
#  2. In a crash event, the dmesg log is collected, and by default this happens
#  via the pstore mechanism, i.e., no crashkernel memory needs to be reserved
#  and no GRUB change is required. If 'lsmod' shows "ramoops", then pstore is
#  likely in use (check dmesg for "ramoops" to be sure). Some extra files are
#  collected besides dmesg, like dmidecode output and "/etc/os-release".
#
#  3. It might be necessary to reserve a bit of memory for pstore in the general
#  case, if not pre-reserved due to kernel alignment or through the device-tree;
#  check the output of "grep buffer /proc/iomem" - if empty or too small buffer,
#  one could save PSTORE_MEM_AMOUNT bytes (see the config file) from kernel use
#  with the "mem=" parameter (requires bootloader configuration).
#
#  4. The logs are stored in a ZIP file in the folder at "$MOUNT_FOLDER/logs"
#  (see the config file); this file is named as: "kdumpst-TIMESTAMP.zip",
#  where TIMESTAMP is the current timestamp (UTC timezone).
#
#  5. (IMPORTANT) Please, test the infrastructure in order to see if a dummy
#  crash log is collected before using it to try debugging complex issues.
#  In order to do that, login to a shell and execute, as root user:
#  'echo 1 > /proc/sys/kernel/sysrq ; echo c > /proc/sysrq-trigger'
#
#  This action will trigger a dummy crash and reboot the system; check if
#  there is a ZIP file with the crash logs in the directory described in (3).
#
#  6. Various tunings are available at "/usr/share/kdumpst.d/*" files; for
#  example, the users can choose kdump instead of pstore (USE_PSTORE_RAM),
#  and if using Kdump, collect the full vmcore (FULL_COREDUMP) or not.
#  The vmcore is not stored in the ZIP file, but it's saved in the folder
#  "$MOUNT_FOLDER/crash".
#  NOTICE that, if kdump is used instead of pstore (either per user's choice
#  or due to some failure in pstore), a reboot is necessary before kdump is
#  usable, in order to effectively reserve crashkernel memory.
#
#  7. Error and succeeding messages are sent to systemd journal, so running
#  'journalctl -b | grep kdumpst' would hopefully bring some information.
#
#
#  ##############################  DETAILS  ##################################
#  CAVEATS / INSTRUCTIONS
#  ###########################################################################
#  (a) We automatically edit GRUB config in case pstore fails or if the user's
#  choice is to use kdump. But it requires one reboot in order the crashkernel
#  memory is effectively reserved by kernel.
#
#  In case Kdump is used, the crashkernel necessary memory was empirically
#  determined; setting 192M wasn't enough always, so 256M seems good enough.
#  This amount might change in future kernel versions, requiring tests using
#  the approach suggested in the step (5) above.
#
#
#  TODOs
#  ###########################################################################
#  * The package currently doesn't uninstall the dracut/initcpio hooks, this
#  is something to be implemented soon, either in the install script or as an
#  option of kdumpst-load script.
#
#  * We should explore /etc/grub.d/ instead of messing with the general grub
#  config file directly to add the "crashkernel" kernel parameter.
#
#  * Would be interesting to have a clean-up mechanism, to keep up to N most
#  recent ZIP log files, instead of keeping all of them forever.
#
#  * Pstore ramoops back-end has some limitations that we're discussing with
#  the kernel community - right now we can only collect ONE dmesg and its
#  size is truncated on "record_size" bytes, not allowing a file split like
#  efi-pstore; thankfully we can still save a 2MiB dmesg, which seems enough.
#
```
