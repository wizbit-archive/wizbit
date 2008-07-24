SUBDIRS = wizbit test
DIST_SUBDIRS = git

git/libgitcore/.libs/libgitcore.a:
	$(MAKE) -C $(top_srcdir)/git

all-local: git/libgitcore/.libs/libgitcore.a
