#include <glib.h>
#include <glib/gstdio.h>

#include <libgitcore/sha1.h>
#include <libgitcore/object-loader.h>
#include <libgitcore/loose-object-loader.h>

#include "file.h"
#include "vref.h"

struct wiz_file {
	int fd;
};

struct wiz_file *wiz_file_open(wiz_vref ref, int flags, enum wiz_file_mode mode)
{
	struct wiz_file *file;

	file = (struct wiz_file *)g_new0(struct wiz_file, 1);

	if (wiz_vref_compare(ref, WIZ_FILE_NEW)) {
		file->fd = g_mkstemp("/tmp/WIZBIT_XXXXXX");
	} else {
		struct git_object_loader *loader;
		loader = git_object_loader_new("/tmp/wizbit");
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
	close(file->fd);
}

int wiz_file_get_fd(struct wiz_file *file)
{
	return file->fd; 
}
