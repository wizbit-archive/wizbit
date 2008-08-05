#include <glib.h>
#include <glib/gstdio.h>

#include <uuid/uuid.h>

#include <wizbit/file.h>

int main()
{
	{
		struct wiz_file *file;
		wiz_vref vref;
		FILE *fp;

		file = wiz_file_open(WIZ_FILE_NEW, 0, 0);
		fp = wiz_file_get_handle(file);
		fprintf(fp, "I BELIEVE");
		wiz_file_snapshot(file, vref);
		wiz_file_close(file);
	}

	return 0;
}

