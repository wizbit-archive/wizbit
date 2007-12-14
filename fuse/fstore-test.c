#include <stdio.h>
#include <uuid/uuid.h>
#include <sys/stat.h>

#include "wiz_fs.h"

int
main(int argc, char* argv[]) {
	uuid_t uuid;
	if (wiz_fstore_mk(S_IFREG | 0744, uuid) < 0) {
		printf("\nError: Could not create reg file");
	}
	if (wiz_fstore_mk(S_IFDIR | 0744, uuid) < 0) {
		printf("\nError: Could not create directory");
	}
}
