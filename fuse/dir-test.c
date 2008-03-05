#include <stdio.h>
#include <uuid/uuid.h>
#include <sys/stat.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>

#include "wiz-fs.h"

int
make_empty (uuid_t dir, uuid_t parent);

int
add_link (uuid_t dir, DEntry* de);

int
remove_link (uuid_t dir, DEntry *de);

int
print_entries (uuid_t dir);

int
main(int argc, char* argv[]) 
{
  uuid_t n, p;
  uuid_t f1, f2, f3, f4, f5, f6;
  int res;
  DEntry entry1, entry2, entry3;
  DEntry entry4, entry5, entry6;
  DEntry *found1, *found2, *found3;
  char *fn;

  uuid_generate(p);
  uuid_generate(n);

  res = make_empty(n, p);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));
  res = print_entries(n);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));

  printf("Add Link -------- \n\n");
  uuid_generate(f1);
  entry1.name = "HoundoftheBaskervilles";
  entry1.name_len = strlen(entry1.name);
  entry1.file_type = WIZ_FT_REG_FILE;
  memcpy(entry1.f_uuid, f1, sizeof(uuid_t));
  res = add_link(n, &entry1);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));
  res = print_entries(n);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));

  uuid_generate(f2);
  entry2.name = "WutheringHeights";
  entry2.name_len = strlen(entry2.name);
  entry2.file_type = WIZ_FT_REG_FILE;
  memcpy(entry2.f_uuid, f2, sizeof(uuid_t));
  res = add_link(n, &entry2);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));
  res = print_entries(n);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));

  uuid_generate(f3);
  entry3.name = "WomanInWhite";
  entry3.name_len = strlen(entry3.name);
  entry3.file_type = WIZ_FT_DIR;
  memcpy(entry3.f_uuid, f3, sizeof(uuid_t));
  res = add_link(n, &entry3);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));
  res = print_entries(n);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));

  printf("Find Entry -------- \n\n");
  entry4.name = "WomanInWhite";
  entry4.name_len = strlen(entry4.name);
  res = find_entry(n, &entry4, &found1);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));
  if (found1)
      printf("Found %s\n", found1->name);
  else
      printf("%s Not found\n", entry4.name);

  entry5.name = "WutheringHeights";
  entry5.name_len = strlen(entry5.name);
  res = find_entry(n, &entry5, &found2);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));
  if (found2)
      printf("Found %s\n", found2->name);
  else
      printf("%s Not found\n", entry5.name);

  entry6.name = "Gobblegibblegook";
  entry6.name_len = strlen(entry6.name);
  res = find_entry(n, &entry6, &found3);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));
  if (found3)
      printf("Found %s\n", found3->name);
  else
      printf("%s Not found\n", entry6.name);

  printf("Set Link -------- \n\n");
  uuid_generate(f4);
  res = set_link(n, &entry1, f4);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));
  res = print_entries(n);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));

  uuid_generate(f5);
  res = set_link(n, &entry2, f5);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));
  res = print_entries(n);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));

  uuid_generate(f6);
  res = set_link(n, &entry3, f6);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));
  res = print_entries(n);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));

  printf("Remove Link -------- \n\n");
  res = remove_link(n, &entry1);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));
  res = print_entries(n);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));

  res = remove_link(n, &entry2);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));
  res = print_entries(n);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));

  res = remove_link(n, &entry3);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));
  res = print_entries(n);
  if (res != 0)
    printf("ERROR: %s\n", strerror(-res));

  res = uuidtofn(n, &fn);
  if (res)
    printf("ERROR: %s\n", strerror(-res));
  unlink(fn);

  free(fn);
  return 0;
}
