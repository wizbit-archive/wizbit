include $(top_srcdir)/Makefile.decl

INCLUDES = \
	-I$(top_srcdir) \
	-DTESTDATADIR=\"$(top_srcdir)/tests/data/\"

TEST_PROGS += test-everything test-sync test-commit-store test-blob-store test-widget

COMMON_VALASOURCES = \
	$(top_builddir)/wizbit/wizbit.vapi		\
	config.vapi					\
	tests.vala					\
	tests.vapi					\
	$(NULL)

noinst_PROGRAMS = $(TEST_PROGS)

BUILT_SOURCES = \
	test_everything.vala.stamp			\
	test-sync.vala.stamp				\
	test-commit-store.vala.stamp			\
	test-blob-store.vala.stamp			\
	test-widget.vala.stamp				\
	$(NULL)

test_everything_VALASOURCES = \
	$(COMMON_VALASOURCES)				\
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
test_everything_LDADD=../wizbit/libwizbit.la

test_sync_VALASOURCES = \
	$(COMMON_VALASOURCES)				\
	test-sync.vala					\
	$(NULL)

test_sync_SOURCES = \
	$(test_sync_VALASOURCES:.vala=.c)		\
	$(test_sync_VALASOURCES:.vala=.h)		\
	$(NULL)

test-sync.vala.stamp: $(test_sync_VALASOURCES)
	$(VALAC) -C --basedir $(top_srcdir) --pkg gio-2.0  $^
	touch $@

test_sync_CFLAGS=@WIZBIT_CFLAGS@
test_sync_LDADD=../wizbit/libwizbit.la

test_commit_store_VALASOURCES = \
	$(COMMON_VALASOURCES)				\
	test-commit-store.vala				\
	$(NULL)

test_commit_store_SOURCES = \
	$(test_commit_store_VALASOURCES:.vala=.c)	\
	$(test_commit_store_VALASOURCES:.vala=.h)	\
	$(NULL)

test-commit-store.vala.stamp:	$(test_commit_store_VALASOURCES)
	$(VALAC) -C --basedir $(top_srcdir) --pkg gio-2.0  $^
	touch $@

test_commit_store_CFLAGS=@WIZBIT_CFLAGS@
test_commit_store_LDADD=../wizbit/libwizbit.la

test_blob_store_VALASOURCES = \
	$(top_srcdir)/wizbit/blob_store.vala		\
	tests.vapi					\
	config.vapi					\
	tests.vala					\
	test-blob-store.vala				\
	$(NULL)

test_blob_store_SOURCES = \
	$(test_blob_store_VALASOURCES:.vala=.c)	\
	$(test_blob_store_VALASOURCES:.vala=.h)	\
	$(NULL)

test-blob-store.vala.stamp:	$(test_blob_store_VALASOURCES)
	$(VALAC) -C --basedir $(top_srcdir) --pkg gio-2.0  $^
	touch $@

test_blob_store_CFLAGS=@WIZBIT_CFLAGS@
test_blob_store_LDADD=../wizbit/libwizbit.la

test_widget_VALASOURCES = \
	$(top_builddir)/wizbit/wizbit.vapi		\
	$(top_builddir)/wizbit-widgets/wizbit-widgets.vapi \
	test-widget.vala				\
	$(NULL)

test_widget_SOURCES = \
	$(test_widget_VALASOURCES:.vala=.c)	\
	$(test_widget_VALASOURCES:.vala=.h)	\
	$(NULL)

test-widget.vala.stamp:	$(test_widget_VALASOURCES)
	$(VALAC) -C --basedir $(top_srcdir) --pkg gio-2.0 --pkg gtk+-2.0  $^
	touch $@

test_widget_CFLAGS=@WIZBIT_CFLAGS@
test_widget_LDADD=../wizbit-widgets/libwizbit-widgets.la ../wizbit/libwizbit.la

EXTRA_DIST += \
	$(BUILT_SOURCES)				\
	$(test_everything_VALASOURCES)			\
	$(test_sync_VALASOURCES)			\
	$(test_commit_store_VALASOURCES)		\
	$(test_blob_store_VALASOURCES)			\
	$(test_widget_VALASOURCES)			\
	$(NULL)
