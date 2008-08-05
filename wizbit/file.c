#include <glib.h>
#include <glib/gstdio.h>

#include <libgitcore/sha1.h>
#include <libgitcore/object-loader.h>
#include <libgitcore/commit.h>
#include <libgitcore/tree.h>
#include <libgitcore/blob.h>
#include <libgitcore/tree-iterator.h>

#include <libgitcore/loose-object-writer.h>

#include "file.h"
#include "vref.h"

#define WIZ_BASE "/home/john/.wizbit/"
#define WIZ_OBJECTS WIZ_BASE"objects/"
#define WIZ_WORKING WIZ_BASE"wc/"

struct wiz_file {
	FILE *fp;
	struct git_commit_writer *commit_writer;
};

struct wiz_file *wiz_file_open(wiz_vref ref, int flags, enum wiz_file_mode mode)
{
	struct wiz_file *file;
	GError *gerror = NULL;

	file = (struct wiz_file *)g_new0(struct wiz_file, 1);

	if (wiz_vref_compare(ref, WIZ_FILE_NEW) == 0) {
		file->fp = g_fopen(WIZ_WORKING"foo", "w");
	} else {
		GMappedFile *tmpfile;
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

		loader = git_object_loader_new(WIZ_OBJECTS);
		store = git_object_cache_new(loader);

		commit = git_object_cache_lookup_commit(store, ref, &error);
		git_object_cache_parse_commit(store, commit, &error);

		tree = git_commit_get_tree(commit);
		git_object_cache_parse_tree(store, tree, &error);

		git_tree_get_iterator(tree, &iter, &error);

		memcpy((unsigned char *)blob, (const unsigned char *)*git_tree_iterator_sha1(&iter), 20);

		data = git_object_loader_load(loader, blob, &type, &size, &error);

		tmpfile = g_mapped_file_new(WIZ_WORKING"foo", TRUE, &gerror);
		memcpy(g_mapped_file_get_contents(tmpfile), data, size);
		g_mapped_file_free(tmpfile);

		file->fp = g_fopen(WIZ_WORKING"foo", "w");
	}

	file->commit_writer = git_commit_writer_new();

	return file;
}

void wiz_file_add_parent(struct wiz_file *file, wiz_vref ref)
{
	git_commit_writer_add_parent_sha1(file->commit_writer, ref);
}

void wiz_file_snapshot(struct wiz_file *file, wiz_vref ref)
{
        struct git_object_loader *loader;
        struct git_loose_object_writer *writer;
        struct git_blob_writer *blob_writer;
        git_sha1 blob;
        struct git_tree_writer *tree_writer;
        git_sha1 tree;
        git_sha1 commit;
        struct git_error *error;

        loader = git_object_loader_new(WIZ_OBJECTS);
        writer = git_loose_object_writer_new(loader, WIZ_OBJECTS);

        blob_writer = git_blob_writer_new();
	git_blob_writer_set_contents_from_file(blob_writer, "/tmp/foo");
	git_blob_writer_write(blob_writer, writer, blob, &error);

        tree_writer = git_tree_writer_new();
        git_tree_writer_add_sha1(tree_writer, 0, "path", blob);
        git_tree_writer_write(tree_writer, writer, tree, &error);

        git_commit_writer_set_tree_sha1(file->commit_writer, tree);
        git_commit_writer_set_author(file->commit_writer, "John Carr <john.carr@unrouted.co.uk>", 0);
        git_commit_writer_set_committer(file->commit_writer, "John Carr <john.carr@unrouted.co.uk>", 0);
        git_commit_writer_set_message(file->commit_writer, "Loreum Ipsum");
        git_commit_writer_write(file->commit_writer, writer, commit, &error);

	git_commit_writer_free(file->commit_writer);
	file->commit_writer = git_commit_writer_new();

	/* wiz_vref_copy(ref, commit); */
	memcpy(ref, commit, sizeof(wiz_vref));
}

void wiz_file_close(struct wiz_file *file)
{
}

FILE *wiz_file_get_handle(struct wiz_file *file)
{
	return file->fp;
}
