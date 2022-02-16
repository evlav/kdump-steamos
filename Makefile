prefix     := /usr
sysconfdir := /etc

libdir     := $(prefix)/lib

systemdunitsdir := $(shell pkg-config --define-variable=prefix=$(prefix) --variable=systemdsystemunitdir systemd 2>/dev/null \
			  || echo $(libdir)/systemd/system/)
sysctldir := $(shell pkg-config --define-variable=prefix=$(prefix) --variable=sysctldir systemd 2>/dev/null \
			  || echo $(libdir)/sysctl.d/)
dracutmodulesdir := $(shell pkg-config --define-variable=prefix=$(prefix) --variable=dracutmodulesdir dracut 2>/dev/null \
			  || echo $(libdir)/dracut/modules.d/)

all:

install: all
	install -D -m0644 kdump.etc $(DESTDIR)$(sysconfdir)/default/kdump
	install -D -m0644 kdump-steamos.service $(DESTDIR)$(systemdunitsdir)/kdump-steamos.service
	install -D -m0644 20-kdump-steamos.conf $(DESTDIR)$(sysctldir)/20-kdump-steamos.conf
	install -D -m0755 kdump_collect.sh $(DESTDIR)$(dracutmodulesdir)/55kdump/kdump_collect.sh
	install -D -m0755 module-setup.sh $(DESTDIR)$(dracutmodulesdir)/55kdump/module-setup.sh
	install -D -m0644 README.md $(DESTDIR)$(dracutmodulesdir)/55kdump/README
	install -D -m0755 kdump_load.sh $(DESTDIR)$(libdir)/kdump/kdump_load.sh
	install -D -m0755 submit_report.sh $(DESTDIR)$(libdir)/kdump/submit_report.sh
	install -D -m0755 submitter_load.sh $(DESTDIR)$(libdir)/kdump/submitter_load.sh
