#include <glib.h>
#include <glib/gstdio.h>

#include <uuid/uuid.h>

#include <wizbit/vref.h>
#include <wizbit/file.h>

int main()
{
	{
		wiz_vref_hexbuffer buffer;
		struct wiz_file *file;
		wiz_vref vref;
		FILE *fp;

		/*
		   Open up a new versioned file and create a couple
		   of revisions
		*/

		file = wiz_file_open(WIZ_FILE_NEW, 0, 0);
		fp = wiz_file_get_handle(file);

		fprintf(fp, "I BELIEVE");
		wiz_file_snapshot(file, vref);

		fprintf(fp, "\nNO RLY");
		wiz_file_add_parent(file, vref);
		wiz_file_snapshot(file, vref);

		fprintf(fp, "\nI CAN HAS BELIEVE!?");
		wiz_file_add_parent(file, vref);
		wiz_file_snapshot(file, vref);

		printf("%s\n", wiz_vref_to_hex(vref, buffer));

		wiz_file_close(file);
	}

	return 0;
}

