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
#  a prebuilt binary package in this gitlab; to check if it's already installed
#  look the pacman installed package list. Also, be sure the systemd service
#  was properly loaded by checking 'systemctl status kdump-steamos.service'.
#
#  2. In a crash event, the dmesg log is collected, and by default this happens
#  via the Pstore mechanism, i.e., no extra memory should be reserved and no
#  GRUB change is required. If 'lsmod' shows "ramoops", then Pstore is in use.
#  Besides the dmesg with some extra information (like tasks running, memory
#  usage on crash, etc), more logs are collected like the image build version,
#  running kernel version and dmidecode.
#
#  3. The logs are stored in a ZIP file at "/home/.steamos/offload/var/kdump/";
#  if this ZIP file was successfully submitted to Valve servers, this file is
#  then moved into the sub-folder "sent_logs/". This file is named as:
#  "steamos-SERIAL-STEAM_USER.timestamp.zip", where SERIAL is the machine
#  serial (from dmidecode), STEAM_USER is the Steam account name (based on the
#  last logged Steam user) and timestamp tz is UTC.
#
#  4. (IMPORTANT) Please, test the infrastructure in order to see if a dummy
#  crash log is collected before using it to try debugging complex issues.
#  In order to do that, login to a shell and execute, as root user:
#  'echo 1 > /proc/sys/kernel/sysrq ; echo c > /proc/sysrq-trigger'
#
#  This action will trigger a dummy crash and reboot the system; check if
#  there is a ZIP file with the crash logs in the directory described in (3).
#
#  5. Some tunings are available at "/etc/default/kdump"; for example users
#  can choose Kdump instead of Pstore (USE_PSTORE_RAM), and if using Kdump,
#  collect the full vmcore (FULL_COREDUMP). The vmcore is not stored in the
#  ZIP file, but it's saved in "/home/.steamos/offload/var/kdump/crash/".
#  NOTICE that, if Kdump is used instead of Pstore (either per user's choice
#  or due to some failure in Pstore), a reboot is necessary before kdump is
#  usable, in order to effectively reserve crashkernel memory.
#
#  6. Error and succeeding messages are sent to systemd journal, so running
#  'journalctl | grep kdump' would hopefully bring some information. Also,
#  the ZIP file collected is automatically submitted to Valve servers; see
#  below under DETAILS/LOG SUBMISSION for API details, decisions made, etc.
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
#  due to that...
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
#  * Would be interesting to have a clean-up mechanism, to keep up to N most
#  recent ZIP log files, instead of keeping all of them forever.
#
#  * Hopefully we can fix/prevent the unnecessary re-creation of all initramfs
#  images - it happens due to our package installing files on directory
#  "/usr/lib/dracut/modules.d" which triggers the unfortunate initramfs rebuild.
#
#  * We have a "fragile" way of determining a mount point required for Kdump;
#  this is something to improve maybe, in order to make the Kdump more reliable.
#  Also in the list of fragile things, VDF parsing is...complicated. Something
#  that would be nice to improve as well.
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
#  * Maybe a good idea would be to allow creating the minimum image for any
#  specified kernel, not only for the running one (which is what we do now).
#  Low-priority idea, easy to implement.
#
#
#  LOG SUBMISSION
#  ###########################################################################
#  The logs collected and compressed in the ZIP file are kept in the system,
#  but they provide valuable data to Valve in order to determine issue in the
#  field, and hopefully fix them, so users are happy. Hence, the kdump-steamos
#  is capable now to submit logs to Valve servers, through an API. Below such
#  API is described, but first worth to mention some assumptions / decisions
#  made in the log submission mechanism:
#
#  * First of all, we attempt to verify network connectivity by pinging the
#    URL "steampowered.com" - quick pings (2 packets, 0.5s between each one)
#    are attempted, but if after 99 of such pings network is considered not
#    not reliable, the log submission is aborted, but the ZIP file is kept
#    locally of course.
#
#  * The 'curl' tool is used to submit the requests to Valve servers; for
#    that, some temporary files named ".curl_XXX" are saved in the kdump
#    folder - mentioned in the point (3) above. These files are deleted
#    if the log submission mechanism works fine, or else they're currently
#    kept for debug purposes, along with a new ".curl_err" file.
#
#  * It is assumed that any throttling / anti-DoS mechanism comes from the
#    server portion, so the kdump-steamos doesn't perform any significant
#    validations with this respect, only basic correctness validations.
#
#
#  => The API details: it works by a first POST request to Valve servers,
#  which, when succeed, returns 3 main components in the response. We use
#  these values to perform a PUT request with the ZIP compressed file, and
#  finally a last POST request is necessary to finish the transaction. The
#  POST requests' URL is present in "/etc/default/kdump".
#  Below, the specific format of such requests:
#
#  The first POST takes the following fields:
#
#    steamid = user Steam ID, based on the latest Steam logged user;
#    have_dump_file = 0/1 - should be 1 when sending a ZIP file;
#    dump_file_size = the ZIP file size, in bytes;
#    product = "holo" (hard-coded for now);
#    build = the SteamOS build ID, from '/etc/os-release' file;
#    version = running kernel version;
#    platform = "linux" (hard-coded for now);
#    crash_time = the timestamp (epoch) of log collection/submission;
#    stack = a really concise call trace summary, only functions/addrs;
#    note = summary of the dmesg crash info, specifically a full stack trace;
#    format = "json" (hard-coded for now).
#
#  The response of a succeeding POST will have multiple fields, that can
#  be split in 3 categories:
#
#    PUT_URL = a new URL to be used in the PUT request;
#    GID = special ID used to finish the submission process in the next POST;
#    header name/value pairs = multiple pairs of name/value fields used as
#                              headers in the PUT request.
#
#  After parsing the response, we perform a PUT request to the PUT_URL, with
#  the ZIP file as a "--data-binary" component and the additional headers that
#  were collected in the first POST's response. Finally, we just POST the GID
#  to the finish URL ("gid=GID_NUM") and the process is terminated.
#
#  Notice we heavily use 'jq' tool to parse the JSON response, so we assume
#  this format is the response one and that it's not changing over time.
#
```
