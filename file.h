#ifndef WIZBIT_FILE_H
#define WIZBIT_FILE_H

typedef wiz_vref char[20];

struct wiz_file;

struct wiz_file *wiz_file_new();

struct wiz_file *wiz_file_open(wiz_vref ref);

void wiz_file_add_parent(wiz_file *file, wiz_vref ref);

const wiz_vref *wiz_file_snapshot(wiz_file *file);

void wiz_file_close();

int wiz_file_get_fd(wiz_file *file);

#endif WIZBIT_FILE_H
