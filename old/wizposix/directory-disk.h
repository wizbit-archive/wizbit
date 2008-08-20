/*
  WizBit : Git based file system
  Copyright (C) 2008  Mark Doffman <mark.doffman@codethink.co.uk>

  This program can be distributed under the terms of the GNU GPL.
  See the file COPYING.
*/

#ifndef __DIRECTORY_DISK_H__
#define __DIRECTORY_DISK_H__

#include <uuid/uuid.h>

int
wiz_dir_make_empty (char *base, uuid_t dir, uuid_t parent, mode_t mode);

int
wiz_dir_add_link (char *base, uuid_t dir, DEntry* de);

int
wiz_dir_remove_link (char *base, uuid_t dir, DEntry *de);

int
wiz_dir_set_link (char *base, uuid_t dir, DEntry *de, uuid_t file);

int
wiz_dir_find_entry (char *base, uuid_t dir, DEntry *de, DEntry **res);

int
wiz_dir_list_entries (char *base, uuid_t dir, DEntry ***list);

#endif  /* __DIRECTORY_DISK_H__ */
