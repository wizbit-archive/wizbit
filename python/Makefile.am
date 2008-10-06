include $(top_srcdir)/Makefile.decl

WIZZERS =					\
	$(top_builddir)/libwizbit/bit.h		\
	$(top_builddir)/libwizbit/store.h	\
	$(top_builddir)/libwizbit/version.h	\
	$(NULL)

wizbit.defs: $(WIZZERS)
	python /usr/share/pygtk/2.0/codegen/h2def.py $(WIZZERS) > wizbit.defs

wizbit.c: wizbit.defs wizbit.override
	pygtk-codegen-2.0 -o wizbit.override -p wizbit wizbit.defs > $@

wizbitdir = $(pyexecdir)/wizbit
wizbit_PYTHON = __init__.py
wizbit_LTLIBRARIES = _wizbit.la

_wizbit_la_CFLAGS = $(PYTHON_CFLAGS) $(PYGOBJECT_CFLAGS) -I$(top_builddir)/libwizbit/
_wizbit_la_LDFLAGS = -module -avoid-version -export-symbols-regex init_wizbit
_wizbit_la_LIBADD = $(WIZBIT_LIBS) $(top_builddir)/libwizbit/libwizbit.la
_wizbit_la_SOURCES =		\
	wizbitmodule.c		\
	wizbit.c		\
	$(NULL)
