noinst_LTLIBRARIES=libwizbit.la

INCLUDES= \
	$(GLIB_CFLAGS) \
	$(LIBGITCORE_CFLAGS)

libwizbit_la_SOURCES = \
	file.c \
	file.h \
	vref.c \
	vref.h

#evil hack to get around git's internal headers being pants

SHA1_HEADER = $(shell sh -c 'cd $(top_builddir)/git && make -q -p | grep "SHA1_HEADER =" | cut -d " " -f 3')
libwizbit_la_LIBADD = @UUID_LIBS@ @LIBGITCORE_LIBS@
libwizbit_la_CFLAGS = @UUID_CFLAGS@ @LIBGITCORE_CFLAGS@ -DSHA1_HEADER="$(SHA1_HEADER)"
