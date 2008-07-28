#include <glib.h>

#include "file.h"
#include "vref.h"

struct wiz_file {
	int int_of_fail;
};

struct wiz_file *wiz_file_open(wiz_vref ref, int flags, enum wiz_file_mode mode)
{
	struct wiz_file *file;

	file = (struct wiz_file *)g_new0(struct wiz_file, 1);

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
	return 0;
}
