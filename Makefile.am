include $(top_srcdir)/Makefile.decl

NULL = 

AUTOMAKE_OPTIONS = subdir-objects
ACLOCAL_AMFLAGS = -I m4

SUBDIRS = \
	wizbit \
	tests \
	docs \
	$(NULL)

#	wizbit-widgets

AM_CPPFLAGS = \
	$(WIZBIT_CFLAGS) \
	-include $(CONFIG_HEADER) \
	$(NULL)

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = wizbit.pc wizbit-widgets.pc
