#  SPDX-License-Identifier: LGPL-2.1+
#
#  Copyright (c) 2021 Valve.
#  Maintainer: Guilherme G. Piccoli <gpiccoli@igalia.com>

pkgname=kdump-steamos
pkgver=0.5
pkgrel=1
pkgdesc="Kdump scripts to collect vmcore/dmesg in a small dracut-based initramfs"
depends=('curl' 'dmidecode' 'dracut' 'jq' 'kexec-tools' 'makedumpfile' 'systemd' 'zip' 'zstd')
arch=('x86_64')
license=('GPL2')
install=kdump-steamos.install

source=('20-kdump-steamos.conf'
        'kdump_collect.sh'
        'kdump.etc'
        'kdump_load.sh'
        'kdump-steamos.install'
        'kdump-steamos.service'
        'module-setup.sh'
        'README.md'
        'submit_report.sh'
        'submitter_load.sh')

sha256sums=('dbedff54addfb5dce51614c73df04c90fca9f27d0d3a690243259ccbbfcca07c'
            '2514f79a496f76af847e262eadd55a5c2f8d95375cc513efa8cadd4cd98fe1d2'
            '4267a2b52ba3016a541d8d6149fc5d4974dd92fb8844439eaa81bd9cde6aa735'
            '7956c6cf1ce5c5e9aaf573ceee8c6ac2a0cad7e0cfa8f5b21adaa20f9f3db929'
            '06b38bd9f09da5fb22a765b6f1945fc349cc5f9d13cd32c9218b9b60b40a9010'
            '12a9124b907f208471ba7aaac0f3261cbbd34a168cce3260fa9e7793994beebd'
            '26bc2b64af0d468f050c0e0dd9e2053176d56886edad9146bc495797bf2c5810'
            '84723f6448e8b914d110078d71d4c3e114ac5637be53a1a91423728f6bb611d7'
            '37620d55624a26d87b2f3018d3e3f2f5ba909fbfcb9da5a28ead318ba0450a36'
            'cbb207ecc0f6bacefbeed41f0d4910daac6500ac2345366e1f95f09a7653c65a')

package() {
	install -D -m0644 kdump.etc "$pkgdir/etc/default/kdump"

	install -D -m0644 kdump-steamos.service "$pkgdir/usr/lib/systemd/system/kdump-steamos.service"
	install -D -m0644 20-kdump-steamos.conf "$pkgdir/usr/lib/sysctl.d/20-kdump-steamos.conf"

	install -D -m0755 kdump_collect.sh "$pkgdir/usr/lib/dracut/modules.d/55kdump/kdump_collect.sh"
	install -D -m0755 module-setup.sh "$pkgdir/usr/lib/dracut/modules.d/55kdump/module-setup.sh"
	install -D -m0644 README.md "$pkgdir/usr/lib/dracut/modules.d/55kdump/README"

	install -D -m0755 kdump_load.sh "$pkgdir/usr/lib/kdump/kdump_load.sh"
	install -D -m0755 submit_report.sh "$pkgdir/usr/lib/kdump/submit_report.sh"
	install -D -m0755 submitter_load.sh "$pkgdir/usr/lib/kdump/submitter_load.sh"
}
