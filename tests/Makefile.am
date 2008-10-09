include $(top_srcdir)/Makefile.decl

INCLUDES = \
	-I$(top_srcdir) \
	-DTESTDATADIR=\"$(srcdir)/data/\"

TEST_PROGS = test-everything test-sync

noinst_PROGRAMS = $(TEST_PROGS)

BUILT_SOURCES = \
	test_everything.vala.stamp			\
	test-sync.vala.stamp				\
	$(NULL)

test_everything_VALASOURCES = \
	$(top_builddir)/wizbit/wizbit.vapi		\
	test-everything.vala				\
	$(NULL)

test_everything_SOURCES = \
	$(test_everything_VALASOURCES:.vala=.c)		\
	$(test_everything_VALASOURCES:.vala=.h)		\
	$(NULL)

test_everything.vala.stamp: $(test_everything_VALASOURCES)
	$(VALAC) -C --basedir $(top_srcdir) --pkg gio-2.0 $^
	touch $@

test_everything_CFLAGS=@WIZBIT_CFLAGS@
test_everything_LDADD=../wizbit/libwizbit.la @WIZBIT_LIBS@

test_sync_VALASOURCES = \
	$(top_builddir)/wizbit/wizbit.vapi		\
	test-sync.vala					\
	$(NULL)

test_sync_SOURCES = \
	$(test_sync_VALASOURCES:.vala=.c)		\
	$(test_sync_VALASOURCES:.vala=.h)		\
	$(NULL)

test-sync.vala.stamp: $(test_sync_VALASOURCES)
	$(VALAC) -C --vapidir=$(top_srcdir)/vapi --basedir $(top_srcdir) --pkg gio-2.0 --pkg gnio $^
	touch $@

test_sync_CFLAGS=@WIZBIT_CFLAGS@
test_sync_LDADD=../wizbit/libwizbit.la @WIZBIT_LIBS@

EXTRA_DIST += \
	$(BUILT_SOURCES)				\
	$(test_everything_VALASOURCES)			\
	$(test_sync_VALASOURCES)			\
	$(NULL)
