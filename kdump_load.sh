#!/bin/sh
#
#  SPDX-License-Identifier: LGPL-2.1+
#
#  Copyright (c) 2021 Valve.
#
#  Script that loads the panic kdump (from within a systemd service)
#  or if the proper parameters are passed, either creates the minimal
#  kdump initramfs for the running kernel or removes all the previously created.
#  ones. Since it runs on boot time, avoid failing here to not risk a boot hang.
#

if [ ! -f "/etc/default/kdump" ]; then
	exit 0
fi

. /etc/default/kdump

# Fragile way for finding the proper mount point for DEVNODE:
DEVN_MOUNTED=$(mount |grep "${MOUNT_DEVNODE}" | head -n1 | cut -f3 -d\ )
KDUMP_FOLDER="${DEVN_MOUNTED}/${KDUMP_FOLDER}"

if [ "$1" == "initrd" ]; then
	mkdir -p "${KDUMP_FOLDER}"
	rm -f "${KDUMP_FOLDER}/kdump-initrd-$(uname -r).img"

	echo "Creating the kdump initramfs for kernel \"$(uname -r)\" ..."
	dracut --no-early-microcode --host-only -q -m\
	"bash systemd systemd-initrd systemd-sysusers modsign dbus-daemon kdump dbus udev-rules dracut-systemd base fs-lib shutdown"\
	--kver $(uname -r) "${KDUMP_FOLDER}/kdump-initrd-$(uname -r).img"

	exit 0
fi

if [ "$1" == "clear" ]; then
	rm -f ${KDUMP_FOLDER}/kdump-initrd-*
	exit 0
fi

# Stolen from Debian kdump
KDUMP_CMDLINE=$(sed -re 's/(^| )(crashkernel|hugepages|hugepagesz)=[^ ]*//g;s/"/\\\\"/' /proc/cmdline)

KDUMP_CMDLINE="${KDUMP_CMDLINE} panic=-1 oops=panic fsck.mode=force fsck.repair=yes nr_cpus=1 reset_devices"
VMLINUX="$(grep -o 'BOOT_IMAGE=[^ ]*' /proc/cmdline)"

kexec -s -p "${VMLINUX#*BOOT_IMAGE=}" --initrd "${KDUMP_FOLDER}/kdump-initrd-$(uname -r).img" --append="${KDUMP_CMDLINE}" || true
exit 0
