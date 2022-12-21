#  Functions to deal with initcpio specifics, both for building
#  the initramfs for mkinitcpio users, but also with regards to
#  installing its specific hooks.
#
#  IMPORTANT: it is assumed that kdump configuration was loaded
#  before running any of these functions!
#
create_initramfs_mkinitcpio() {
	rm -f "${MOUNT_FOLDER}/kdump-initrd-$1.img"

	mkinitcpio -A kdump -g "${MOUNT_FOLDER}/kdump-initrd-$1.img" "$1" 1>/dev/null

	if [ -s "${MOUNT_FOLDER}/kdump-initrd-$1.img" ]; then
		logger "kdump: created initcpio minimal initramfs"
	fi
}

mkinitcpio_installation() {
	KDUMP_HOOKS_DIR="/usr/lib/kdump/initcpio/"
	INITCPIO_HOOKS="/usr/lib/initcpio/hooks"
	INITCPIO_INST="/usr/lib/initcpio/install"

	if [ ! -e "${INITCPIO_HOOKS}"/kdump ] || [ ! -e "${INITCPIO_INST}"/kdump ]; then
		install -D -m0644 "${KDUMP_HOOKS_DIR}"/kdump.hook "${INITCPIO_HOOKS}"/kdump
		install -D -m0644 "${KDUMP_HOOKS_DIR}"/kdump.install "${INITCPIO_INST}"/kdump
		logger "kdump: initcpio hooks installed"
	fi
}

