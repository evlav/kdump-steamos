#  SPDX-License-Identifier: LGPL-2.1+
#
#  Copyright (c) 2021 Valve.
#  Maintainer: Guilherme G. Piccoli <gpiccoli@igalia.com>

pkgname=kdump-steamos
pkgver=0.2
pkgrel=1
pkgdesc="Kdump scripts to collect vmcore/dmesg in a small dracut-based initramfs"
depends=('dracut' 'kexec-tools' 'systemd' 'zstd')
arch=('x86_64')
license=('GPL2')
install=kdump-steamos.install

source=('kdump_collect.sh'
        'kdump.etc'
        'kdump_load.sh'
        'kdump-steamos.install'
        'kdump-steamos.service'
        'makedumpfile'
        'module-setup.sh'
        'README.md'
        'submit_report.sh')

sha256sums=('38a3636c95cb97b33a71cfb2b95ccbf7a9a565e86b2128299ea7844d1135fe07'
            '38751d1fa1607fc99607423a0051a2b3322db5579906401b40c11c10edd6bbc6'
            '888024a0b121102688d0384cf00dca06d55d3c2fc6b18a3de0da1fc8b5c10066'
            '06b38bd9f09da5fb22a765b6f1945fc349cc5f9d13cd32c9218b9b60b40a9010'
            '6063ed2283743d8d84a89d9f3c950e5f50adf99bba5ce865a25282081ebc04c2'
            '86ef2bd71551598f392fe278507449c1c872e0d42b27600cfeb5bcf9a75aa881'
            'c3ceaf77021e49c3ec884e3959f49b0cbf5e8e89ad3f17d485d895d9e91725f4'
            '01432491df80dfd37c6f261c17f55c574e8898003642334a4d61f8d93aef08c3'
            '956efe1589d8d6533a231d8bdec6ac5cd4c1d1494b1f44b8494fe1d75f6a1e4e')

package() {
	install -D -m0644 kdump.etc "$pkgdir/etc/default/kdump"

	install -D -m0644 kdump-steamos.service "$pkgdir/usr/lib/systemd/system/kdump-steamos.service"

	install -D -m0755 kdump_collect.sh "$pkgdir/usr/lib/dracut/modules.d/55kdump/kdump_collect.sh"
	install -D -m0755 module-setup.sh "$pkgdir/usr/lib/dracut/modules.d/55kdump/module-setup.sh"
	install -D -m0644 README.md "$pkgdir/usr/lib/dracut/modules.d/55kdump/README"

	install -D -m0755 kdump_load.sh "$pkgdir/usr/lib/kdump/kdump_load.sh"
	install -D -m0755 makedumpfile "$pkgdir/usr/lib/kdump/makedumpfile"
	install -D -m0755 submit_report.sh "$pkgdir/usr/lib/kdump/submit_report.sh"
}
