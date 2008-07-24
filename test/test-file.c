#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>

#include <string.h>
#include <errno.h>

#include <uuid/uuid.h>

#include "wizbit/file.h"

char *work_dir = "/tmp/wizbittest";

int main()
{
	system ("rm -rf /tmp/wizbittest");
	mkdir (work_dir,0700);
	chdir (work_dir);

	{
		struct wiz_file *file;
		wiz_vref vref;
		int fd;

		file = wiz_file_open(WIZ_FILE_NEW, 0, 0);
		fd = wiz_file_get_fd(file);
		wiz_file_snapshot(file, vref);
		wiz_file_close(file);
	}

	return 0;
}

