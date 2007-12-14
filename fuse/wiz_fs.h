#include <inttypes.h>

#define WIZ_NAME_LEN 255

/* Meta data, Inode equivalent? What should go in here? */
struct wiz_mdata {
	uint16_t file_type;
};

#define WIZ_DIRENT_FIXED 22

/* Structure of directory entry on disk */
struct wiz_dir_entry {
	char     uuid[16]; /* inode eqv...lookup file */
	uint16_t rec_len;
	uint16_t name_len;
	uint16_t file_type;
	char     name[WIZ_NAME_LEN];
};

enum {
        WIZ_FT_UNKNOWN = 0,
        WIZ_FT_REG_FILE,
        WIZ_FT_DIR,
        WIZ_FT_CHRDEV,
        WIZ_FT_BLKDEV,
        WIZ_FT_FIFO,
        WIZ_FT_SOCK,
        WIZ_FT_SYMLINK,
        WIZ_FT_MAX
};

#define EXTENSION_SIZE 6
#define UUID_SIZE 35

#define FSTORE_NAME_SIZE UUID_SIZE + EXTENSION_SIZE

int wiz_add_entry(char* fstore, uuid_t uuide, int ftype, char* name);
int wiz_init_dir(char *fstore, uuid_t fsuid, uuid_t parent);

inline int wiz_fstouuid(char* fstore, uuid_t uuid);
inline int wiz_uuidtofs_data(uuid_t uuid, char *fstore);
inline int wiz_uuidtofs_file(uuid_t uuid, char *fstore);
int wiz_fstore_mk(mode_t mode, uuid_t made);
