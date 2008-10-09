include $(top_srcdir)/Makefile.decl

NULL = 

AUTOMAKE_OPTIONS = subdir-objects

SUBDIRS = \
	libwizbit \
	tests \
	po \
	$(NULL)

AM_CPPFLAGS = \
	$(WIZBIT_CFLAGS) \
	-include $(CONFIG_HEADER) \
	$(NULL)

BUILT_SOURCES = src/wizbit.vala.stamp

bin_PROGRAMS = wizbit

wizbit_VALASOURCES = \
	src/main.vala \
	$(NULL)

wizbit_SOURCES = \
	$(wizbit_VALASOURCES:.vala=.c) \
	$(wizbit_VALASOURCES:.vala=.h) \
	$(NULL)

src/wizbit.vala.stamp: $(wizbit_VALASOURCES)
	$(VALAC) -C --vapidir=$(top_srcdir)/vapi --basedir $(top_srcdir) $^
	touch $@

wizbit_LDADD = \
	$(WIZBIT_LIBS) \
	$(NULL)

EXTRA_DIST = \
	intltool-extract.in \
	intltool-update.in \
	intltool-merge.in \
	$(wizbit_VALASOURCES) \
	src/wizbit.vala.stamp \
	$(NULL)

DISTCLEANFILES = \
	intltool-extract \
	intltool-update \
	intltool-merge \
	po/.intltool-merge-cache \
	$(NULL)

