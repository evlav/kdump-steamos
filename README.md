```
#  ###########################################################################
#  ########################## Arch Kdump / Pstore  ###########################
#  ###########################################################################
#
#
#  This is the Arch Kdump/Pstore infrastructure; the goal is to collect
#  data whenever a kernel crash is detected. There is a lightweight
#  collection, that only grabs dmesg, and a more complete setting to grab the
#  whole (compressed) vmcore. See the DETAILS section below for more info.
#
#
#  ############################  HOW-TO USE IT  ##############################
#
#  1. Install the package with pacman if not available in your system; to check
#  if it's already installed look the pacman installed package list. Also, be
#  sure the systemd service was properly loaded by checking
#  'systemctl status kdump-init.service'.
#
#  2. In a crash event, the dmesg log is collected, and by default this happens
#  via the Pstore mechanism, i.e., no extra memory should be reserved and no
#  GRUB change is required. If 'lsmod' shows "ramoops", then Pstore is in use.
#  Some extra files are collected besides dmesg, like dmidecode output and the
#  "/etc/os-release" file.
#
#  3. The logs are stored in a ZIP file in the folder at "$MOUNT_FOLDER/logs"
#  (see the config file); this file is named as: "kdump-TIMESTAMP.zip",
#  where TIMESTAMP is the current timestamp (tz is UTC).
#
#  4. (IMPORTANT) Please, test the infrastructure in order to see if a dummy
#  crash log is collected before using it to try debugging complex issues.
#  In order to do that, login to a shell and execute, as root user:
#  'echo 1 > /proc/sys/kernel/sysrq ; echo c > /proc/sysrq-trigger'
#
#  This action will trigger a dummy crash and reboot the system; check if
#  there is a ZIP file with the crash logs in the directory described in (3).
#
#  5. Various tunings are available at "/usr/share/kdump.d/*" files; for
#  example, the users can choose Kdump instead of Pstore (USE_PSTORE_RAM),
#  and if using Kdump, collect the full vmcore (FULL_COREDUMP). The vmcore is
#  not stored in the ZIP file, but it's saved in "$MOUNT_FOLDER/crash".
#  NOTICE that, if Kdump is used instead of Pstore (either per user's choice
#  or due to some failure in Pstore), a reboot is necessary before kdump is
#  usable, in order to effectively reserve crashkernel memory.
#
#  6. Error and succeeding messages are sent to systemd journal, so running
#  'journalctl -b | grep kdump' would hopefully bring some information.
#
#
#  ##############################  DETAILS  ##################################
#  CAVEATS / INSTRUCTIONS
#  ###########################################################################
#  (a) We automatically edit GRUB config in case Pstore fails or if the user's
#  choice is to use Kdump. But it requires one reboot in order the crashkernel
#  memory is effectively reserved by kernel.
#
#  In case Kdump is used, the crashkernel necessary memory was empirically
#  determined; setting 144M wasn't enough, 160M is unstable, so 192M seems
#  good enough. This amount might change in future kernel versions, requiring
#  tests using the approach suggested in the step (4) above.
#
#
#  TODOs
#  ###########################################################################
#  * Would be interesting to have a clean-up mechanism, to keep up to N most
#  recent ZIP log files, instead of keeping all of them forever.
#
#  * Pstore ramoops back-end has some limitations that we're discussing with
#  the kernel community - right now we can only collect ONE dmesg and its
#  size is truncated on "record_size" bytes, not allowing a file split like
#  efi-pstore; thankfully we still can collect 2MiB dmesg, but hopefully we can
#  improve that upstream.
#
#  * Add a more reliable reboot mechanism - we had seen issues in the past
#  with "reboot -f", and relying in sysrq reboot as a quirk managed to be a safe
#  option, so this is something to think about. Should be easy to implement.
#
```
