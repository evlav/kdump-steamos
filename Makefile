SHELL := /bin/bash
prefix     := /usr

libdir     := $(prefix)/lib
sharedir     := $(prefix)/share

systemdunitsdir := $(shell pkg-config --define-variable=prefix=$(prefix) --variable=systemdsystemunitdir systemd 2>/dev/null \
			  || echo $(libdir)/systemd/system/)
sysctldir := $(shell pkg-config --define-variable=prefix=$(prefix) --variable=sysctldir systemd 2>/dev/null \
			  || echo $(libdir)/sysctl.d/)
alpmhooksdir := $(shell echo $(sharedir)/libalpm/hooks/)

kdump-load.sh: kdump-load.header common.sh kdump-load.sh.in
	cat $^ > $@

save-dumps.sh: save-dumps.header common.sh save-dumps.sh.in
	cat $^ > $@

99-kdump-dracut.hook: initramfs/alpm-hook.generic
	sed 's/INITRD/dracut/g' $^ > initramfs/$@

kdump-dracut-hook.sh: common.sh initramfs/dracut/dracut-common.sh
	sed 's/INITRD/dracut/g' initramfs/alpm-script.header > initramfs/alpm-header-dracut
	sed 's/INITRD/dracut/g' initramfs/alpm-script.sh.in > initramfs/alpm-script.sh.in-dracut
	cat initramfs/alpm-header-dracut $^ initramfs/alpm-script.sh.in-dracut > initramfs/dracut/$@
	rm -f initramfs/alpm-header-dracut initramfs/alpm-script.sh.in-dracut

module-setup.sh: initramfs/dracut/module-setup.header common.sh initramfs/dracut/module-setup.sh.in
	cat $^ > initramfs/dracut/$@

.PHONY: dracut
dracut: 99-kdump-dracut.hook kdump-dracut-hook.sh module-setup.sh

99-kdump-mkinitcpio.hook: initramfs/alpm-hook.generic
	sed 's/INITRD/mkinitcpio/g' $^ > initramfs/$@

99-kdump-mkinitcpio-git.hook: initramfs/alpm-hook.generic
	sed 's/INITRD/mkinitcpio-git/g' $^ > initramfs/$@

kdump-mkinitcpio-hook.sh: common.sh initramfs/initcpio/initcpio-common.sh
	sed 's/INITRD/mkinitcpio/g' initramfs/alpm-script.header > initramfs/alpm-header-initcpio
	sed 's/INITRD/mkinitcpio/g' initramfs/alpm-script.sh.in > initramfs/alpm-script.sh.in-initcpio
	cat initramfs/alpm-header-initcpio $^ initramfs/alpm-script.sh.in-initcpio > initramfs/initcpio/$@
	rm -f initramfs/alpm-header-initcpio initramfs/alpm-script.sh.in-initcpio

kdump.hook: initramfs/kdump-collect.sh
	sed 's/\#ENTRY POINT/run_hook() \{/g' $^ > initramfs/initcpio/$@
	sed -i 's/\#END/\}/g' initramfs/initcpio/$@

kdump.install: initramfs/initcpio/kdump.install.header common.sh initramfs/initcpio/kdump.install.in
	cat $^ > initramfs/initcpio/$@

.PHONY: mkinitcpio
mkinitcpio: 99-kdump-mkinitcpio.hook 99-kdump-mkinitcpio-git.hook kdump-mkinitcpio-hook.sh kdump.hook kdump.install

all: kdump-load.sh save-dumps.sh dracut mkinitcpio

install: all
	install -D -m0644 kdump-init.service $(DESTDIR)$(systemdunitsdir)/kdump-init.service
	install -D -m0644 20-panic-sysctls.conf $(DESTDIR)$(sysctldir)/20-panic-sysctls.conf
	install -D -m0644 README.md $(DESTDIR)$(libdir)/kdump/README.md
	install -D -m0755 kdump-load.sh $(DESTDIR)$(libdir)/kdump/kdump-load.sh
	install -D -m0755 save-dumps.sh $(DESTDIR)$(libdir)/kdump/save-dumps.sh
	install -D -m0644 00-default.conf $(DESTDIR)$(sharedir)/kdump.d/00-default
	install -D -m0644 initramfs/99-kdump-dracut.hook $(DESTDIR)$(alpmhooksdir)/99-kdump-dracut.hook
	install -D -m0644 initramfs/99-kdump-mkinitcpio.hook $(DESTDIR)$(alpmhooksdir)/99-kdump-mkinitcpio.hook
	install -D -m0644 initramfs/99-kdump-mkinitcpio-git.hook $(DESTDIR)$(alpmhooksdir)/99-kdump-mkinitcpio-git.hook
	install -D -m0755 initramfs/dracut/kdump-dracut-hook.sh $(DESTDIR)$(libdir)/kdump/kdump-dracut-hook.sh
	install -D -m0755 initramfs/kdump-collect.sh $(DESTDIR)$(libdir)/kdump/dracut/kdump-collect.sh
	install -D -m0755 initramfs/dracut/module-setup.sh $(DESTDIR)$(libdir)/kdump/dracut/module-setup.sh
	install -D -m0755 initramfs/initcpio/kdump-mkinitcpio-hook.sh $(DESTDIR)$(libdir)/kdump/kdump-mkinitcpio-hook.sh
	install -D -m0755 initramfs/initcpio/kdump-mkinitcpio-hook.sh $(DESTDIR)$(libdir)/kdump/kdump-mkinitcpio-git-hook.sh
	install -D -m0644 initramfs/initcpio/kdump.hook $(DESTDIR)$(libdir)/kdump/initcpio/kdump.hook
	install -D -m0644 initramfs/initcpio/kdump.install $(DESTDIR)$(libdir)/kdump/initcpio/kdump.install

clean:
	rm -f kdump-load.sh save-dumps.sh
	rm -f initramfs/99-kdump-*
	rm -f initramfs/dracut/{kdump-dracut-hook.sh,module-setup.sh}
	rm -f initramfs/initcpio/kdump{-mkinitcpio-hook.sh,.hook,.install}
