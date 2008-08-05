#include <glib.h>
#include <glib/gstdio.h>

#include <uuid/uuid.h>

#include <wizbit/file.h>

char *work_dir = "/tmp/wizbittest";

int main()
{
	system ("rm -rf /tmp/wizbittest");
	mkdir (work_dir,0700);
	chdir (work_dir);

	{
		struct wiz_file *file;
		wiz_vref vref;
		FILE *fp;

		file = wiz_file_open(WIZ_FILE_NEW, 0, 0);
		fp = wiz_file_get_handle(file);
		wiz_file_snapshot(file, vref);
		wiz_file_close(file);
	}

	return 0;
}

