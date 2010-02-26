include $(top_srcdir)/Makefile.decl

lib_LTLIBRARIES=libwizbit.la

INCLUDES= \
	$(GLIB_CFLAGS) \
	-I$(top_srcdir) \
	$(NULL)

BUILT_SOURCES = libwizbit.vala.stamp

libwizbit_la_VALASOURCES = \
	config.vapi \
	blob_store.vala \
	commit.vala \
	commit_builder.vala \
	commit_store.vala \
	store.vala \
	bit.vala \
	file.vala \
	uuid.vapi \
	utils.vala \
	breadthfirst.vala \
	iterator.vala \
	sync.vala
	$(NULL)

libwizbit_la_SOURCES = \
	$(libwizbit_la_VALASOURCES:.vala=.c) \
	$(NULL)

libwizbit.vala.stamp: $(libwizbit_la_VALASOURCES)
	$(VALAC) -C --basedir $(top_srcdir) --pkg posix --pkg glib-2.0 --pkg gio-2.0 --pkg gio-unix-2.0 --pkg sqlite3 --pkg gee-1.0 -H wizbit.h --library wizbit $^
	touch $@

libwizbit_la_CFLAGS=@WIZBIT_CFLAGS@
libwizbit_la_LIBADD=@WIZBIT_LIBS@

wizbitincludedir = $(includedir)/wizbit-1.0/wizbit
wizbitinclude_HEADERS = \
	wizbit.h \
	$(NULL)

wizbitvapidir = $(datadir)/vala/vapi
wizbitvapi_DATA = \
	wizbit.vapi \
	$(NULL)

EXTRA_DIST += \
	$(libwizbit_la_VALASOURCES) \
	libwizbit.vala.stamp \
	$(NULL)

MAINTAINERCLEANFILES = \
        wizbit.vapi \
        wizbit.h \
        $(libwizbit_la_VALASOURCES:.vala=.c) \
        $(NULL)

