#ifndef WIZBIT_FILE_H
#define WIZBIT_FILE_H

typedef unsigned char wiz_vref[20];

enum wiz_file_mode {
	WIZ_FILE_MODE_LAST
};

struct wiz_file;

struct wiz_file *wiz_file_new();

struct wiz_file *wiz_file_open(wiz_vref ref, int flags, enum wiz_file_mode mode);

void wiz_file_add_parent(struct wiz_file *file, wiz_vref ref);

const wiz_vref *wiz_file_snapshot(struct wiz_file *file);

void wiz_file_close(struct wiz_file *file);

int wiz_file_get_fd(struct wiz_file *file);

#endif /* WIZBIT_FILE_H */
