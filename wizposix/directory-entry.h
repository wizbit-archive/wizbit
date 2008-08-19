/*
  WizBit : Git based file system
  Copyright (C) 2008  Mark Doffman <mark.doffman@codethink.co.uk>

  This program can be distributed under the terms of the GNU GPL.
  See the file COPYING.
*/

#ifndef WIZ_DIRECTORY_ENTRY_H
#define WIZ_DIRECTORY_ENTRY_H

#include <uuid/uuid.h>

enum wiz_file_type
{
  WIZ_FT_UNKNOWN = 0,
  WIZ_FT_REG_FILE,
  WIZ_FT_DIR,
  WIZ_FT_SYMLINK,
  WIZ_FT_MAX
};

/* dentry - The in memory representation of a directory entry*/
typedef struct
{
  uuid_t f_uuid;
  enum wiz_file_type file_type;
  char name_len;
  char *name;
} DEntry;

/*
  wiz_directory_entry_new - Creates a new directory entry with blank uuid.

  Ownership of the file_name parameter transfers to the directory entry.
 */
DEntry *wiz_directory_entry_new(char *file_name, int name_len, enum wiz_file_type file_type);

/*
  wiz_directory_entry_new_uuid - Creates a new directory entry with filled uuid.

  Same a wiz_directory_entry new, but the file id parameter is filled in.
 */
DEntry *wiz_directory_entry_new_id(char *file_name, int name_len, enum wiz_file_type file_type, uuid_t id);

/*
  wiz_directory_entry_free - Deletes a dentry, if entry->name exists,
                             that is freed also.
 */
void wiz_directory_entry_free(DEntry *entry);

/*
  wiz_directory_entry_freev - Deletes a null terminated array of DEntry*.
 */
void wiz_directory_entry_freev(DEntry **list);

#endif  /* WIZ_DIRECTORY_ENTRY_H */
