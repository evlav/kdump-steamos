#!/bin/bash
#
#  SPDX-License-Identifier: LGPL-2.1+
#
#  Copyright (c) 2021 Valve.
#
#  Script that loads the panic kdump (from within a systemd service) and/or
#  configures the Pstore-RAM mechanism. If the proper parameters are passed
#  also, either it creates the minimal kdump initramfs for the running kernel
#  or removes all the previously created ones. Since it runs on boot time,
#  avoid failing here to not risk a boot hang.
#

if [ ! -f "/etc/default/kdump" ]; then
	logger "kdump-steamos: /etc/default/kdump not present - aborting..."
	exit 0
fi

. /etc/default/kdump

#  Fragile way for finding the proper mount point for DEVNODE:
DEVN_MOUNTED=$(mount |grep "${MOUNT_DEVNODE}" | head -n1 | cut -f3 -d\ )
KDUMP_FOLDER="${DEVN_MOUNTED}/${KDUMP_FOLDER}"

echo "${KDUMP_FOLDER}" > "${KDUMP_MNT}"
sync "${KDUMP_MNT}"

if [ "$1" = "initrd" ]; then
	mkdir -p "${KDUMP_FOLDER}"
	rm -f "${KDUMP_FOLDER}/kdump-initrd-$(uname -r).img"

	echo "Creating the kdump initramfs for kernel \"$(uname -r)\" ..."
	dracut --no-early-microcode --host-only -q -m\
	"bash systemd systemd-initrd systemd-sysusers modsign dbus-daemon kdump dbus udev-rules dracut-systemd base fs-lib shutdown"\
	--kver "$(uname -r)" "${KDUMP_FOLDER}/kdump-initrd-$(uname -r).img"

	exit 0
fi

if [ "$1" = "clear" ]; then
	rm -f "${KDUMP_FOLDER}"/kdump-initrd-*
	exit 0
fi

#  Pstore-RAM load; if it is configured via /etc/default/kdump and fails
#  to configure pstore, we still try to load the kdump. We try to reserve
#  here a 5MiB memory region.
#  Notice that we assume ramoops is a module here - if built-in, we should
#  properly load it through command-line parameters.
if [ "${USE_PSTORE_RAM}" -eq 1 ]; then
	MEM_REQUIRED=5242880  # 5MiB
	RECORD_SIZE=0x200000  # 2MiB
	RANGE=$(grep "RAM buffer" /proc/iomem | head -n1 | cut -f1 -d\ )

	MEM_END=$(echo "$RANGE" | cut -f2 -d-)
	MEM_START=$(echo "$RANGE" | cut -f1 -d-)
	MEM_SIZE=$(( 16#${MEM_END} - 16#${MEM_START} ))

	if [ ${MEM_SIZE} -ge ${MEM_REQUIRED} ]; then
		if modprobe ramoops mem_address=0x${MEM_START} mem_size=${MEM_REQUIRED} record_size=${RECORD_SIZE}; then
			logger "kdump-steamos: pstore-RAM was loaded successfully"
			exit 0
		fi
		logger "kdump-steamos: pstore-RAM load failed...will try kdump"
	fi
		#  Fallbacks to kdump load - if we fail when configuring pstore, better try kdump;
		#  who knows and we may be lucky enough to have some crashkernel reserved memory...
fi

#  TODO: insert code here to validate that crashkernel is configured and
#  memory is reserved; if not, set it on grub.cfg and recreate the EFI grub
#  config file, warning users that in the current boot kdump is not set.

#  Stolen from Debian kdump
KDUMP_CMDLINE=$(sed -re 's/(^| )(crashkernel|hugepages|hugepagesz)=[^ ]*//g;s/"/\\\\"/' /proc/cmdline)

KDUMP_CMDLINE="${KDUMP_CMDLINE} panic=-1 oops=panic fsck.mode=force fsck.repair=yes nr_cpus=1 reset_devices"
VMLINUX="$(grep -o 'BOOT_IMAGE=[^ ]*' /proc/cmdline)"

if ! kexec -s -p "${VMLINUX#*BOOT_IMAGE=}" --initrd "${KDUMP_FOLDER}/kdump-initrd-$(uname -r).img" --append="${KDUMP_CMDLINE}"; then
	logger "kdump-steamos: kdump load failed"
	exit 0
fi
logger "kdump-steamos: kdump was loaded successfully"
