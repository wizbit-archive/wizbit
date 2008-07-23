#include "file.h"

struct wiz_file *wiz_file_new()
{
	return NULL;
}

struct wiz_file *wiz_file_open(wiz_vref ref, int flags, mode_t mode)
{
	return NULL;
}

void wiz_file_add_parent(struct wiz_file *file, wiz_vref ref)
{
}

const wiz_vref *wiz_file_snapshot(struct wiz_file *file, refs)
{
	wiz_vref vref;
	return vref;
}

void wiz_file_close(struct wiz_file *file)
{
}

int wiz_file_get_fd(struct wiz_file *file)
{
	return 0;
}
