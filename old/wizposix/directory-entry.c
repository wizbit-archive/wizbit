/*
  WizBit : Git based file system
  Copyright (C) 2008  Mark Doffman <mark.doffman@codethink.co.uk>

  This program can be distributed under the terms of the GNU GPL.
  See the file COPYING.
*/

#include <string.h>
#include <uuid/uuid.h>

#include <wizbit/xmalloc.h>
#include "directory-entry.h"

/*----------------------------------------------------------------------------*/

static DEntry *_wiz_directory_entry_new(char *file_name, enum wiz_file_type file_type)
{
  DEntry *entry = NULL;

  entry = xmalloc(sizeof(DEntry));
  entry->name_len = strlen(file_name);
  entry->file_type = file_type;
  entry->name = file_name;
  return 0;
}

/*----------------------------------------------------------------------------*/

DEntry *wiz_directory_entry_new(char *file_name, int name_len, enum wiz_file_type file_type)
{
  char *name;
  DEntry *entry;

  name = xmalloc(name_len + 1);
  memcpy(name, file_name, entry->name_len);
  name[name_len] = '\0';

  return _wiz_directory_entry_new(name, file_type);
}

/*----------------------------------------------------------------------------*/

DEntry *wiz_directory_entry_new_id(char *file_name, int name_len, enum wiz_file_type file_type, uuid_t id)
{
  DEntry *entry;

  entry = wiz_directory_entry_new(file_name, name_len, file_type);
  memcpy(entry->f_uuid, id, sizeof(uuid_t));
  return entry;
}

/*----------------------------------------------------------------------------*/

void wiz_directory_entry_free(DEntry *entry)
{
  if (entry->name)
    {
      free(entry->name);
    }
  free(entry);
}

/*----------------------------------------------------------------------------*/

void wiz_directory_entry_freev(DEntry **list)
{
  DEntry* cur = *list;
  while (cur)
    {
      wiz_directory_entry_free(cur);
      cur++;
    }
  free(list);
}
