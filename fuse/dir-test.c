#include <stdio.h>
#include <uuid/uuid.h>
#include <sys/stat.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>

#include "wiz_fs.h"

int
main(int argc, char* argv[]) 
{
	uuid_t n, p;
	int fd;
	char fstore[FSTORE_NAME_SIZE];
	int res;

	if (wiz_fstore_mk(S_IFDIR | 0744, n) < 0) {
		printf("\nError: Could not create directory");
	}

	wiz_uuidtofs_file(fstore, n);
	uuid_generate(p);
	res = wiz_init_dir(fstore, n, p);
	if (res != 0)
		printf("ERROR: %s\n", strerror(-res));

	res = wiz_add_entry(fstore, p, WIZ_FT_REG_FILE, "ADir");
	if (res != 0)
		printf("ERROR: %s\n", strerror(-res));

	res = wiz_add_entry(fstore, p, WIZ_FT_REG_FILE, "AWhoopsieDir");
	if (res != 0)
		printf("ERROR: %s\n", strerror(-res));

	res = wiz_add_entry(fstore, p, WIZ_FT_REG_FILE, "AKillerDir");
	if (res != 0)
		printf("ERROR: %s\n", strerror(-res));

	close(fd);
}
