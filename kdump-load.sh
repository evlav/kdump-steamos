#!/bin/bash
#
#  SPDX-License-Identifier: LGPL-2.1+
#
#  Copyright (c) 2021 Valve.
#  Maintainer: Guilherme G. Piccoli <gpiccoli@igalia.com>
#
#  Script that loads the panic kdump (from within a systemd service) and/or
#  configures the Pstore-RAM mechanism. If the proper parameters are passed
#  also, either it creates the minimal kdump initramfs for the running kernel
#  or removes all the previously created ones. Since it runs on boot time,
#  avoid failing here to not risk a boot hang.
#

#  This function has 2 purposes: if 'kdump' is passed as argument and we don't
#  have crashkernel memory reserved, we edit grub config file and recreate
#  grub.cfg, so next boot has it reserved; in this case, we also  bail-out,
#  since kdump can't be loaded anyway.
#
#  If 'pstore' is passsed as argument, we try to unset crashkernel iff it's
#  already set AND the pattern in grub config is the one added by us - if the
#  users set crashkernel themselves, we don't mess with that.
grub_update() {
	GRUBCFG="/etc/default/grub"
	CRASHK="$(cat /sys/kernel/kexec_crash_size)"
	SED_ADD="s/^GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"crashkernel=192M crash_kexec_post_notifiers /g"

	if [ "${GRUB_AUTOSET}" -eq 1 ]; then
		if [ "$1" = "kdump" ] && [ "${CRASHK}" -eq 0 ]; then
			sed -i "${SED_ADD}" "${GRUBCFG}"
			update-grub 1>/dev/null
			sync "/boot/grub/grub.cfg" 2>/dev/null
			sync "/efi/EFI/steamos/grub.cfg" 2>/dev/null

			logger "kdump: kexec cannot work, no reserved memory in this boot..."
			logger "kdump: but we automatically set crashkernel for next boot."
			exit 0
		fi

		if [ "$1" = "pstore" ] && [ "${CRASHK}" -ne 0 ]; then
			sed -i "s/\"crashkernel=192M crash_kexec_post_notifiers /\"/g" "${GRUBCFG}"
			update-grub 1>/dev/null
			sync "/boot/grub/grub.cfg" 2>/dev/null
			sync "/efi/EFI/steamos/grub.cfg" 2>/dev/null
			logger "kdump: clearing crashkernel memory previously set..."
		fi
	fi
}

#  This function is responsible for creating the kdump initrd, either
#  via command-line call or in case initrd doesn't exist during kdump load.
create_initrd() {
	rm -f "${KDUMP_FOLDER}/kdump-initrd-$(uname -r).img"

	echo "Creating the kdump initramfs for kernel \"$(uname -r)\" ..."
	DRACUT_NO_XATTR=1 dracut --no-early-microcode --host-only -q -m\
	"bash systemd systemd-initrd systemd-sysusers modsign dbus-daemon kdump dbus udev-rules dracut-systemd base fs-lib shutdown"\
	--kver "$(uname -r)" "${KDUMP_FOLDER}/kdump-initrd-$(uname -r).img"
}

#  This routine performs a clean-up by deleting the old/useless remaining
#  kdump initrd files.
cleanup_unused_initrd() {
	INSTALLED_KERNELS="${KDUMP_FOLDER}/.installed_kernels"

	find /lib/modules/* -maxdepth 0 -type d -exec basename {} \;>"${INSTALLED_KERNELS}"

	find "${KDUMP_FOLDER}"/* -name "kdump-initrd*" -type f -print0 | while IFS= read -r -d '' file
	do
		FNAME="$(basename "${file}" .img)"
		KVER="${FNAME#kdump-initrd-}"
		if ! grep -q "${KVER}" "${INSTALLED_KERNELS}" ; then
			rm -f "${KDUMP_FOLDER}/${FNAME}.img"
			logger "kdump: removed unused file \"${FNAME}.img\""
		fi
	done

	rm -f "${INSTALLED_KERNELS}"
}


if [ ! -s "/usr/share/kdump/kdump.conf" ]; then
	logger "kdump: /usr/share/kdump/kdump.conf is missing, aborting."
	exit 0
fi

. /usr/share/kdump/kdump.conf

#  Find the proper mount point expected for kdump collection:
DEVN_MOUNTED="$(findmnt "${MOUNT_DEVNODE}" -fno TARGET)"

#  Create the kdump folder here, as soon as possible, given the
#  importance of such directory in all kdump/pstore steps.
KDUMP_FOLDER="${DEVN_MOUNTED}/${KDUMP_FOLDER}"
mkdir -p "${KDUMP_FOLDER}"

echo "${KDUMP_FOLDER}" > "${KDUMP_MNT}"
sync "${KDUMP_MNT}"

#  Notice that at this point it's required to have the full
#  KDUMP_FOLDER, so this must remain after the DEVNODE operations above.
if [ "$1" = "initrd" ]; then
	create_initrd
	exit 0
fi

if [ "$1" = "clear" ]; then
	rm -f "${KDUMP_FOLDER}"/kdump-initrd-*
	exit 0
fi

#  Pstore-RAM load; if it is configured via /usr/share/kdump/kdump.conf and fails
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
		if modprobe ramoops mem_address=0x"${MEM_START}" mem_size=${MEM_REQUIRED} record_size=${RECORD_SIZE}; then
			#  If Pstore is set, update grub.cfg to avoid reserving crashkernel memory.
			logger "kdump: pstore-RAM was loaded successfully"
			cleanup_unused_initrd
			grub_update pstore
			exit 0
		fi
		logger "kdump: pstore-RAM load failed...will try kdump"
	fi
		#  Fallback to kdump load - if we fail when configuring pstore, better
		#  trying kdump; in case we have crashkernel memory reserved, lucky us.
		#  If not, we're going to set that automatically on grub_update().
		#  Notice that if it's not set, we bail-out in grub_update() - there's
		#  no point in continuing since kdump cannot work.
fi

cleanup_unused_initrd
grub_update kdump

#  Stolen from Debian kdump
KDUMP_CMDLINE=$(sed -re 's/(^| )(crashkernel|hugepages|hugepagesz)=[^ ]*//g;s/"/\\\\"/' /proc/cmdline)

KDUMP_CMDLINE="${KDUMP_CMDLINE} panic=-1 oops=panic fsck.mode=force fsck.repair=yes nr_cpus=1 reset_devices"
VMLINUX="$(grep -o 'BOOT_IMAGE=[^ ]*' /proc/cmdline)"

#  In case we don't have a valid initrd, for some reason, try creating
#  one before loading kdump (or else it will fail).
INITRD_FNAME="${KDUMP_FOLDER}/kdump-initrd-$(uname -r).img"
if [ ! -s "${INITRD_FNAME}" ]; then
	create_initrd
fi

if ! kexec -s -p "${VMLINUX#*BOOT_IMAGE=}" --initrd "${INITRD_FNAME}" --append="${KDUMP_CMDLINE}"; then
	logger "kdump: kexec load failed"
	exit 0
fi
logger "kdump: panic kexec loaded successfully"
