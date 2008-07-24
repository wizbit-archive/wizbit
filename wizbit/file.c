#include "file.h"

struct wiz_file *wiz_file_new()
{
	return 0;
}

struct wiz_file *wiz_file_open(wiz_vref ref, int flags, enum wiz_file_mode mode)
{
	return 0;
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
