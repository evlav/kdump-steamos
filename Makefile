prefix     := /usr

libdir     := $(prefix)/lib
sharedir     := $(prefix)/share

systemdunitsdir := $(shell pkg-config --define-variable=prefix=$(prefix) --variable=systemdsystemunitdir systemd 2>/dev/null \
			  || echo $(libdir)/systemd/system/)
sysctldir := $(shell pkg-config --define-variable=prefix=$(prefix) --variable=sysctldir systemd 2>/dev/null \
			  || echo $(libdir)/sysctl.d/)
dracutmodulesdir := $(shell pkg-config --define-variable=prefix=$(prefix) --variable=dracutmodulesdir dracut 2>/dev/null \
			  || echo $(libdir)/dracut/modules.d/)

kdump-load.sh: kdump-load.header common.sh kdump-load.sh.in
	cat $^ > $@

module-setup.sh: module-setup.header common.sh module-setup.sh.in
	cat $^ > $@

save-dumps.sh: save-dumps.header common.sh save-dumps.sh.in
	cat $^ > $@

all: kdump-load.sh module-setup.sh save-dumps.sh

install: all
	install -D -m0644 kdump-init.service $(DESTDIR)$(systemdunitsdir)/kdump-init.service
	install -D -m0644 20-panic-sysctls.conf $(DESTDIR)$(sysctldir)/20-panic-sysctls.conf
	install -D -m0755 kdump-collect.sh $(DESTDIR)$(dracutmodulesdir)/55kdump/kdump-collect.sh
	install -D -m0755 module-setup.sh $(DESTDIR)$(dracutmodulesdir)/55kdump/module-setup.sh
	install -D -m0644 README.md $(DESTDIR)$(dracutmodulesdir)/55kdump/README
	install -D -m0755 kdump-load.sh $(DESTDIR)$(libdir)/kdump/kdump-load.sh
	install -D -m0755 save-dumps.sh $(DESTDIR)$(libdir)/kdump/save-dumps.sh
	install -D -m0644 00-default.conf $(DESTDIR)$(sharedir)/kdump.d/00-default
