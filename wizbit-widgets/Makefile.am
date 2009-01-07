include $(top_srcdir)/Makefile.decl

lib_LTLIBRARIES=libwizbit-widgets.la

INCLUDES= \
	$(GLIB_CFLAGS) \
	-I$(top_srcdir) \
	$(NULL)

BUILT_SOURCES = libwizbit-widgets.vala.stamp

libwizbit_widgets_la_VALASOURCES = \
	$(top_builddir)/wizbit/wizbit.vapi
	timeline.vala
	$(NULL)

libwizbit_widgets_la_SOURCES = \
	$(libwizbit_widgets_la_VALASOURCES:.vala=.c) \
	$(libwizbit_widgets_la_VALASOURCES:.vala=.h) \
	$(NULL)

libwizbit-widgets.vala.stamp: $(libwizbit_widgets_la_VALASOURCES)
	$(VALAC) -C --vapidir=$(top_srcdir)/vapi --basedir $(top_srcdir) --pkg gtk+-2.0 --pkg cairo --pkg glib-2.0 --pkg gio-2.0 --pkg gio-unix-2.0 --pkg sqlite3 --library wizbit-widgets $^
	touch $@

libwizbit_widgets_la_CFLAGS=@WIZBIT_CFLAGS@
libwizbit_widgets_la_LIBADD=@WIZBIT_LIBS@

wizbitwidgetsincludedir = $(includedir)/wizbit-1.0/wizbit-widgets
wizbitwidgetsinclude_HEADERS = \
	$(libwizbit_widgets_la_VALASOURCES:.vala=.h) \
	$(NULL)

EXTRA_DIST += \
	$(libwizbit_widgets_la_VALASOURCES) \
	libwizbit-widgets.vala.stamp \
	$(NULL)
