include $(top_srcdir)/Makefile.decl

INCLUDES = \
	-I$(top_srcdir) \
	$(LIBGITCORE_CFLAGS) \
	-DTESTDATADIR=\"$(srcdir)/data/\"

TEST_PROGS = test-everything

noinst_PROGRAMS = $(TEST_PROGS)

BUILT_SOURCES = test_everything.vala.stamp

test_everything_VALASOURCES = \
	$(top_srcdir)/libwizbit/libwizbit.vapi \
	test-everything.vala \
	$(NULL)

test_everything_SOURCES = \
	$(test_everything_VALASOURCES:.vala=.c) \
	$(test_everything_VALASOURCES:.vala=.h) \
	$(NULL)

test_everything.vala.stamp: $(test_everything_VALASOURCES)
	$(VALAC) -C --basedir $(top_srcdir) --pkg gio-2.0 $^
	touch $@

test_everything_CFLAGS=@WIZBIT_CFLAGS@
test_everything_LDADD=../libwizbit/libwizbit.la @WIZBIT_LIBS@
