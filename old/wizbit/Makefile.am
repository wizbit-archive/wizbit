lib_LTLIBRARIES=libwizbit.la

INCLUDES= \
	$(GLIB_CFLAGS) \
	$(LIBGITCORE_CFLAGS)

libwizbit_la_SOURCES = \
	file.c \
	file.h \
	vref.c \
	vref.h

libwizbit_la_LIBADD = @UUID_LIBS@ @LIBGITCORE_LIBS@
libwizbit_la_CFLAGS = @UUID_CFLAGS@ @LIBGITCORE_CFLAGS@
