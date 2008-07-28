#include <glib.h>
#include <glib/gstdio.h>

#include <libgitcore/sha1.h>
#include <libgitcore/object-loader.h>
#include <libgitcore/loose-object-loader.h>
#include <libgitcore/commit.h>
#include <libgitcore/tree.h>
#include <libgitcore/tree-iterator.h>

#include "file.h"
#include "vref.h"

struct wiz_file {
	GMappedFile *gfile;
};

struct wiz_file *wiz_file_open(wiz_vref ref, int flags, enum wiz_file_mode mode)
{
	struct wiz_file *file;
	GError *gerror;

	file = (struct wiz_file *)g_new0(struct wiz_file, 1);

	if (wiz_vref_compare(ref, WIZ_FILE_NEW)) {
		file->gfile = g_mapped_file_new("/tmp/foo", TRUE, &gerror);
	} else {
		struct git_object_loader *loader;
		struct git_object_cache *store;
		struct git_commit *commit;
		struct git_tree *tree;
		struct git_tree_iterator iter;
		git_sha1 blob;
		void *data;
		enum git_object_type type;
		unsigned long size;
		struct git_error *error;

		loader = git_object_loader_new("/tmp/wizbit");
		store = git_object_cache_new(loader);

		commit = git_object_cache_lookup_commit(store, ref, &error);
		git_object_cache_parse_commit(store, commit, &error);

		tree = git_object_cache_lookup_tree(store, git_commit_get_tree(commit), &error);
		git_object_cache_parse_tree(store, tree, &error);

		git_tree_get_iterator(tree, &iter, &error);

		memcpy((unsigned char *)blob, (const unsigned char *)*git_tree_iterator_sha1(&iter), 20);

		data = git_object_loader_load(loader, blob, &type, &size, &error);

		file->gfile = g_mapped_file_new("/tmp/foo", TRUE, &gerror);
		memcpy(g_mapped_file_get_contents(file->gfile), data, size);
	}

	return file;
}

void wiz_file_add_parent(struct wiz_file *file, wiz_vref ref)
{
}

void wiz_file_snapshot(struct wiz_file *file, wiz_vref ref)
{
}

void wiz_file_close(struct wiz_file *file)
{
}

int wiz_file_get_fd(struct wiz_file *file)
{
}
