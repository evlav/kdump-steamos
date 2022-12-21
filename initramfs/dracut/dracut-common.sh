#  Functions to deal with dracut specifics, both for building
#  the initramfs for dracut users, but also with regards to
#  installing dracut specific hooks/scripts.
#
#  IMPORTANT: it is assumed that kdump configuration was loaded
#  before running any of these functions!
#
create_initramfs_dracut() {
	rm -f "${MOUNT_FOLDER}/kdump-initrd-$1.img"

	DRACUT_NO_XATTR=1 dracut --no-early-microcode --host-only -q -m\
	"bash systemd systemd-initrd systemd-sysusers modsign dbus-daemon kdump dbus udev-rules dracut-systemd base fs-lib shutdown"\
	--kver "$1" "${MOUNT_FOLDER}/kdump-initrd-$1.img"

	if [ -s "${MOUNT_FOLDER}/kdump-initrd-$1.img" ]; then
		logger "kdump: created dracut minimal initramfs"
	fi
}

dracut_installation() {
	HOOKS_DIR="/usr/lib/kdump/dracut/"

	DRACUT_DIR="$(pkg-config --variable=dracutmodulesdir dracut 2>/dev/null)"
	if [ -z "${DRACUT_DIR}" ]; then
		DRACUT_DIR="/usr/lib/dracut/modules.d/"
	fi

	if [ ! -d "${DRACUT_DIR}"/55kdump/ ]; then
		install -D -m0755 "${HOOKS_DIR}"/kdump-collect.sh "${DRACUT_DIR}"/55kdump/kdump-collect.sh
		install -D -m0755 "${HOOKS_DIR}"/module-setup.sh "${DRACUT_DIR}"/55kdump/module-setup.sh
		logger "kdump: dracut hooks/scripts installed"
	fi
}

