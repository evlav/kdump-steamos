#  SPDX-License-Identifier: LGPL-2.1+
#
#  Copyright (c) 2021 Valve.
#  Maintainer: Guilherme G. Piccoli <gpiccoli@igalia.com>

pkgname=kdump-steamos
pkgver=0.1
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

sha256sums=('b008f0afa1ca0eccbb27d5293fc624c6845eb89d1b6a92141b096d9746afb672'
            'c18621fb705decfff724b7498d418002cdf9c30c2c1a00d5379a51fdb4c21a26'
            'feef3082832df97e5a21ee90a94874b7776fceaa4bb9847ae57344db8aab73ef'
            '8f2fb837c980975dfd3bb2c7c2dd66b20975f97fdecd2646e06543a869be6136'
            '6063ed2283743d8d84a89d9f3c950e5f50adf99bba5ce865a25282081ebc04c2'
            '86ef2bd71551598f392fe278507449c1c872e0d42b27600cfeb5bcf9a75aa881'
            'eaff70fd08c2378894bc0c7c340fb41cef6bc488a839d81ea7d0f06f4998e14e'
            'e4da9aa28643aee08f126f0fd62e273924e511daefbc8c2957ba34715b718b95'
            '98fd860864cfb59043532dd6b4dfea0e6cf2abbd77da5d9b3200da718126a480')

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
