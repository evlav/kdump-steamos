#!/bin/sh
#
#  SPDX-License-Identifier: LGPL-2.1+
#
#  Copyright (c) 2021 Valve.
#
#  SteamOS kdump module construction/inclusion script for
#  Dracut-based initramfs.
#

# Only include kdump if it is explicitly asked in the argument list
check() {
    return 255
}

installkernel() {
    hostonly='' instmods ext4 
}

install() {
    # First clear all unnecessary firmwares/drivers added by drm in order to
    # reduce the size of this minimal initramfs being created. This should
    # be already done via command-line arguments, but let's play safe and delete
    # from here as well just in case.
    rm -rf $initdir/usr/lib/firmware/amdgpu/
    rm -rf $initdir/usr/lib/modules/*/kernel/drivers/gpu/drm/amd/*

    # Install necessary binaries
    inst date
    inst sync

    mkdir -p $initdir/usr/lib/kdump
    cp -LR --preserve=all /usr/lib/kdump/* $initdir/usr/lib/kdump/
    cp -LR --preserve=all /etc/default/kdump $initdir/usr/lib/kdump/kdump.etc

    inst_hook pre-mount 01 "$moddir/kdump_collect.sh"
}
