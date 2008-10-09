include $(top_srcdir)/Makefile.decl

lib_LTLIBRARIES=libwizbit.la

INCLUDES= \
	$(GLIB_CFLAGS) \
	-I$(top_srcdir) \
	$(NULL)

BUILT_SOURCES = libwizbit.vala.stamp

libwizbit_la_VALASOURCES = \
	graph.vala \
	store.vala \
	bit.vala \
	version.vala \
	reader.vala \
	writer.vala \
	uuid.vapi \
	utils.vala \
	breadthfirst.vala \
	$(NULL)

libwizbit_la_SOURCES = \
	$(libwizbit_la_VALASOURCES:.vala=.c) \
	$(libwizbit_la_VALASOURCES:.vala=.h) \
	$(NULL)

libwizbit.vala.stamp: $(libwizbit_la_VALASOURCES)
	$(VALAC) -C --vapidir=$(top_srcdir)/vapi --basedir $(top_srcdir) --pkg glib-2.0 --pkg gio-2.0 --pkg gio-unix-2.0 --library wizbit $^
	touch $@

libwizbit_la_CFLAGS=@WIZBIT_CFLAGS@
libwizbit_la_LIBS=@WIZBIT_LIBS@

wizbitincludedir = $(includedir)/wizbit-1.0/wizbit
wizbitinclude_HEADERS = \
	$(libwizbit_la_VALASOURCES:.vala=.h) \
	$(NULL)

EXTRA_DIST = \
	$(libwizbit_la_VALASOURCES) \
	libwizbit.vala.stamp \
	$(NULL)
