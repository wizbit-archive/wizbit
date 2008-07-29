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

struct wiz_file {
	GMappedFile *gfile;
};

struct wiz_file *wiz_file_open(wiz_vref ref, int flags, enum wiz_file_mode mode)
{
	struct wiz_file *file;
	GError *gerror = NULL;

	file = (struct wiz_file *)g_new0(struct wiz_file, 1);

	if (wiz_vref_compare(ref, WIZ_FILE_NEW) == 0) {
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

		tree = git_commit_get_tree(commit);
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
        struct git_object_loader *loader;
        struct git_loose_object_writer *writer;
        struct git_blob_writer *blob_writer;
        git_sha1 blob;
        struct git_tree_writer *tree_writer;
        git_sha1 tree;
        struct git_commit_writer *commit_writer;
        git_sha1 commit;
        struct git_error *error;

        loader = git_object_loader_new("/tmp/wizbit");
        writer = git_loose_object_writer_new(loader,"/tmp/wizbit");

        blob_writer = git_blob_writer_new();
        git_blob_writer_set_contents(blob_writer, g_mapped_file_get_contents(file->gfile),
                                     g_mapped_file_get_length(file->gfile));
        git_blob_writer_write(blob_writer, writer, &error);

        tree_writer = git_tree_writer_new();
        git_tree_writer_add_sha1(tree_writer, 0, "path", blob);
        git_tree_writer_write(tree_writer, writer, &error);

        commit_writer = git_commit_writer_new();
        git_commit_writer_set_tree_sha1(commit_writer, tree);
        /* git_commit_writer_add_parent_sha1(commit_writer, parent); */
        git_commit_writer_set_author(commit_writer, "John Carr <john.carr@unrouted.co.uk>", 0);
        git_commit_writer_set_committer(commit_writer, "John Carr <john.carr@unrouted.co.uk>", 0);
        git_commit_writer_set_message(commit_writer, "Loreum Ipsum");
        git_commit_writer_write(commit_writer, writer, &error);
}

void wiz_file_close(struct wiz_file *file)
{
}

int wiz_file_get_fd(struct wiz_file *file)
{
}
