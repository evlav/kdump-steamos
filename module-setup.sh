#!/bin/sh
#
#  SPDX-License-Identifier: LGPL-2.1+
#
#  Copyright (c) 2021 Valve.
#
#  SteamOS kdump module construction/inclusion script for
#  Dracut-based initramfs.
#

#  Only include kdump if it is explicitly asked in the argument list
check() {
    return 255
}

installkernel() {
    hostonly='' instmods ext4 
}

install() {
    #  Having a valid /etc/default/kdump is essential for kdump.
    if [ ! -s "/etc/default/kdump" ]; then
        return 1
    fi

    . /etc/default/kdump

    #  First clear all unnecessary firmwares/drivers added by drm in order to
    #  reduce the size of this minimal initramfs being created. This should
    #  be already done via command-line arguments, but let's play safe and delete
    #  from here as well just in case.
    rm -rf $initdir/usr/lib/firmware/amdgpu/
    rm -rf $initdir/usr/lib/modules/*/kernel/drivers/gpu/drm/amd/*

    #  Install necessary binaries
    inst date
    inst sync
    inst makedumpfile

    mkdir -p $initdir/usr/lib/kdump

    #  Determine the numerical devnode for kdump, and save it on initrd;
    #  notice that partset link is not available that early in boot time.
    DEVN="$(readlink -f "${MOUNT_DEVNODE}")"
    echo "${DEVN}" > $initdir/usr/lib/kdump/kdump.devnode

    cp -LR --preserve=all /usr/lib/kdump/* $initdir/usr/lib/kdump/
    cp -LR --preserve=all /etc/default/kdump $initdir/usr/lib/kdump/kdump.etc

    inst_hook pre-mount 01 "$moddir/kdump-collect.sh"
}
