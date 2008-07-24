noinst_PROGRAMS = test-file

test_file_SOURCE = \
	test-file.c
test_file_LDADD = $(top_builddir)/wizbit/libwizbit.la @GIT_LIBS@ @UUID_LIBS@ -lpthread
test_file_CFLAGS = @UUID_CFLAGS@ @GIT_CFLAGS@

#test_storage_SOURCES = \
#	test-storage.c

#test_storage_LDADD = $(top_builddir)/wizbit/libwizbit.la @GIT_LIBS@ @UUID_LIBS@ -lpthread
#test_storage_CFLAGS = @UUID_CFLAGS@ @GIT_CFLAGS@
