SUBDIRS = wizbit
DIST_SUBDIRS = git

git/libgit.a:
	$(MAKE) -C $(top_srcdir)/git libgit.a

all-local: git/libgit.a
