#ifndef WIZBIT_FILE_H
#define WIZBIT_FILE_H

#include "vref.h"

enum wiz_file_mode {
	WIZ_FILE_MODE_LAST
};

#define WIZ_FILE_NEW  (wiz_vref) { \
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, \
	0x00, 0x00, 0x00, 0x00 }

struct wiz_file;

struct wiz_file *wiz_file_open(wiz_vref ref, int flags, enum wiz_file_mode mode);

void wiz_file_add_parent(struct wiz_file *file, wiz_vref ref);

void wiz_file_snapshot(struct wiz_file *file, wiz_vref ref);

void wiz_file_close(struct wiz_file *file);

GMappedFile *wiz_file_get_g_mapped_file(struct wiz_file *file);

#endif /* WIZBIT_FILE_H */
