/*
  WizBit : Git based file system
  Copyright (C) 2008  Mark Doffman <mark.doffman@codethink.co.uk>

  This program can be distributed under the terms of the GNU GPL.
  See the file COPYING.
*/

#include <config.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>

#include <glib/gstdio.h>
#include <glib/gi18n.h>
#include <gio/gio.h>

#include "gvfsbackendwizbit.h"
#include "gvfsjobopenforread.h"
#include "gvfsjobread.h"
#include "gvfsjobseekread.h"
#include "gvfsjobqueryinfo.h"
#include "gvfsjobenumerate.h"
#include "gvfsjobsetdisplayname.h"
#include "gvfsjobwrite.h"
#include "gvfsjobseekwrite.h"
#include "gvfsjobopenforwrite.h"
#include "gvfsjobqueryattributes.h"

G_DEFINE_TYPE (GVfsBackendWizbit, g_vfs_backend_wizbit, G_VFS_TYPE_BACKEND)

static void
g_vfs_backend_wizbit_finalize (GObject *object)
{
  if (G_OBJECT_CLASS (g_vfs_backend_wizbit_parent_class)->finalize)
    (*G_OBJECT_CLASS (g_vfs_backend_wizbit_parent_class)->finalize) (object);
}

static void
g_vfs_backend_wizbit_init (GVfsBackendWizbit *test_backend)
{
  GVfsBackend *backend = G_VFS_BACKEND (test_backend);
}

/*---------------------------------------------------------------------------*/

/*
  get_local_file - Gets the local file system file for the base path and filename.

  TODO - Is the filename given to us always absolute?
 */
static GFile*
get_local_file (GVfsBackend *backend, const char *filename, GVfsJob *job)
{
  GVfs *local_vfs;
  GFile *file = NULL;
  GMountSpec *mount_spec;
  char *base;
  char *full_path;

  mount_spec = g_vfs_backend_get_mount_spec (backend);
  base = (char*) g_mount_spec_get (mount_spec, "base");
  full_path = g_strconcat(base, filename, NULL);

  local_vfs = g_vfs_get_local ();

  if (! local_vfs) 
    {
      g_vfs_job_failed (job, G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get local vfs");
      return NULL;
    }

  file = g_vfs_get_file_for_path (local_vfs, full_path);
  if (!file) 
    {
      g_vfs_job_failed (job, G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get file from local vfs"); 
      return NULL;
    }

  return file;
}

static GFileInfo*
get_file_info (GFile *file,
               const char *attributes, 
               GFileQueryInfoFlags flags,
               GVfsJob *job)
{
  GError *err = NULL;
  GFileInfo *info = NULL;

  g_return_val_if_fail (file != NULL, NULL);

  info = g_file_query_info (file, attributes, flags, G_VFS_JOB (job)->cancellable, &err);
  if (err || !info)
    {
      g_vfs_job_failed_from_error (G_VFS_JOB (job), err);
      return NULL;
    }
  return info;
}

/*---------------------------------------------------------------------------*/

/*
  do_mount - Mounts the given base path.

  A wizbit mount is just defined by
  a path to the repository
 */
static void
do_mount (GVfsBackend *backend,
          GVfsJobMount *job,
          GMountSpec *mount_spec,
          GMountSource *mount_source,
          gboolean is_automount)
{
  GMountSpec *real_mount_spec;
  char *base = NULL;

  real_mount_spec = g_mount_spec_new ("wizbit");
  base = (char*) g_mount_spec_get (mount_spec, "base");
  /*
    TODO - This should also check that the given
    base path is a valid wizbit directory.
   */
  if (base)
    {
      char *display_name;

      g_mount_spec_set(real_mount_spec, "base", base);
      g_vfs_backend_set_mount_spec (backend, real_mount_spec);
      g_mount_spec_unref (real_mount_spec);

      display_name = g_strdup_printf (_("Wizbit at %s"), base);
      g_vfs_backend_set_display_name (backend, display_name);
      g_free (display_name);
      g_vfs_backend_set_icon_name (backend, "folder-remote");

      g_vfs_job_succeeded (G_VFS_JOB (job));
    }
  else
    {
      g_vfs_job_failed (G_VFS_JOB (job),
                        G_IO_ERROR, G_IO_ERROR_INVALID_ARGUMENT,
                        _("Invalid mount spec"));
    }
}

/*
  do_unmount - Nothing right now, returns success.

  TODO - Might in future want to commit all open files??
 */
static void
do_unmount (GVfsBackend *backend,
            GVfsJobUnmount *job)
{
  g_vfs_job_succeeded (G_VFS_JOB (job));
}

/*---------------------------------------------------------------------------*/

/*
  do_enumerate - Gets all the children of a path.
 */
static void
do_enumerate (GVfsBackend *backend,
              GVfsJobEnumerate *job,
              const char *filename,
              GFileAttributeMatcher *attribute_matcher,
              GFileQueryInfoFlags flags)
{
  GFile *file;
  GFileEnumerator *enumerator;
  GFileInfo *info;
  GError *err = NULL;
  gboolean success = TRUE;

  file = get_local_file(backend, filename, G_VFS_JOB(job));

  if (file)
    {
      enumerator = g_file_enumerate_children (file, job->attributes, flags, G_VFS_JOB (job)->cancellable, &err);
      if (enumerator)
        {
          info = g_file_enumerator_next_file(enumerator, G_VFS_JOB(job)->cancellable, &err);
          while ((info != NULL) && (success == TRUE))
            {
              if (!err)
                {
                  g_vfs_job_enumerate_add_info (job, info);
                }
              else
                {
                  g_vfs_job_failed_from_error (G_VFS_JOB (job), err);
                  g_error_free (err);
                  success = FALSE;
                }
              g_object_unref(info);
              info = g_file_enumerator_next_file(enumerator, G_VFS_JOB(job)->cancellable, &err);
            }
          g_object_unref(enumerator);
        }
      else
        {
          success = FALSE;
        }
      g_object_unref(file);
    }
  else
    {
      success = FALSE;
    }

  if (success)
    {
      g_vfs_job_enumerate_done (job);
      g_vfs_job_succeeded (G_VFS_JOB(job));
    }
}

/*
  do_query_info - Gets file information for a path.
 */
static void
do_query_info (GVfsBackend *backend,
               GVfsJobQueryInfo *job,
               const char *filename,
               GFileQueryInfoFlags flags,
               GFileInfo *info,
               GFileAttributeMatcher *matcher)
{
  GFile *file;
  GFileInfo *result;

  file = get_local_file(backend, filename, G_VFS_JOB(job));

  if (file)
    {
      result = get_file_info(file, job->attributes, flags, G_VFS_JOB (job));
      if (result)
        {
          g_file_info_copy_into(result, info);
          g_object_unref (result);
          g_vfs_job_succeeded (G_VFS_JOB(job));
        }
      g_object_unref(file);
    }
  else
    {
      g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get file from local vfs"); 
    }
}

/*
  do_query_fs_info - Gets file system information for a path.

  File system information is mostly taken from the underlying
  file system. The only thing modified is the file system ID.
 */
static void
do_query_fs_info (GVfsBackend *backend,
                  GVfsJobQueryFsInfo *job,
                  const char *filename,
                  GFileInfo *info,
                  GFileAttributeMatcher *attribute_matcher)
{
  GFile *file;
  GFileInfo *result;
  GError *err = NULL;

  file = get_local_file(backend, filename, G_VFS_JOB(job));

  if (file) {
      result = g_file_query_filesystem_info (file, "fs:*", G_VFS_JOB (job)->cancellable, &err);
      if (result && !err)
        {
          GMountSpec *spec;
          char *id;

          g_file_info_copy_into(result, info);
          g_object_unref (result);
          /*
            In the query info & enumerate case the filesystem ID is filled in
            automatically. In the query fs info case it is not.
            The filesystem type is left as is (The underlying file system).
           */
          spec = g_vfs_backend_get_mount_spec (backend);
          if (spec)
            {
              id = g_mount_spec_to_string (spec);
              g_file_info_set_attribute_string (info, G_FILE_ATTRIBUTE_ID_FILESYSTEM, id);
              g_free (id);
            }
          g_vfs_job_succeeded (G_VFS_JOB(job));
        }
      else
        {
          if (err)
            {
              g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
              g_error_free (err);
            }
          else
            {
              g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                                "Could not obtain file system info"); 

            }
        }
      g_object_unref(file);
    }
  else
    {
      g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get file from local vfs"); 
    }
}

/*---------------------------------------------------------------------------*/

static void
do_query_settable_attributes (GVfsBackend *backend,
                              GVfsJobQueryAttributes *job,
                              const char *filename)
{
  GFileAttributeInfoList *attr_list;
  GError *err;
  GFile *file = NULL;

  file = get_local_file(backend, filename, G_VFS_JOB(job));

  if (file)
    {
      attr_list = g_file_query_settable_attributes (file, G_VFS_JOB (job)->cancellable, &err);
      if ((attr_list) && (!err))
        {
          g_vfs_job_query_attributes_set_list (job, attr_list);
          g_vfs_job_succeeded (G_VFS_JOB(job));
        }
      else
        {
          g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
          g_error_free (err);
        }
      g_object_unref (file);
    }
  else
    {
      g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get file from local vfs"); 
    }
}

static void
do_set_attribute (GVfsBackend *backend,
                  GVfsJobSetAttribute *job,
                  const char *filename,
                  const char *attribute,
                  GFileAttributeType type,
                  gpointer value_p,
                  GFileQueryInfoFlags flags)
{
  GError *err;
  GFile *file = NULL;

  file = get_local_file(backend, filename, G_VFS_JOB(job));

  if (file)
    {
      if (g_file_set_attribute (file,
                                attribute, 
                                type,
                                value_p,
                                flags,
                                G_VFS_JOB (job)->cancellable,
                                &err))
        {
          g_vfs_job_succeeded (G_VFS_JOB(job));
        }
      else
        {
          g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
          g_error_free (err);
        }
      g_object_unref (file);
    }
  else
    {
      g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get file from local vfs"); 
    }
}

/*---------------------------------------------------------------------------*/

static void
do_open_for_read (GVfsBackend *backend,
                  GVfsJobOpenForRead *job,
                  const char *filename)
{
  GFileInputStream *stream;
  GError *err = NULL;
  GFile *file;

  file = get_local_file(backend, filename, G_VFS_JOB(job));

  if (file)
    {
      stream = g_file_read (file, G_VFS_JOB (job)->cancellable, &err);
      if (stream && !err)
        {
          g_vfs_job_open_for_read_set_can_seek (job, g_seekable_can_seek (G_SEEKABLE (stream)));
          g_vfs_job_open_for_read_set_handle (job, stream);
          g_vfs_job_succeeded (G_VFS_JOB(job));
        }
      else
        {
          if (err)
            {
              g_vfs_job_failed_from_error (G_VFS_JOB (job), err);
              g_error_free (err);
            }
          else
            {
              g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                                "Could not open file for reading");
            }
        }
      g_object_unref(file);
    }
  else
    {
      g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get file from local vfs"); 
    }
}

static void
do_read (GVfsBackend *backend,
         GVfsJobRead *job,
         GVfsBackendHandle _handle,
         char *buffer,
         gsize bytes_requested)
{
  GError *err = NULL;
  GFileInputStream *stream = _handle;
  gssize s;

  g_assert (stream != NULL);

  s = g_input_stream_read (G_INPUT_STREAM (stream), buffer, bytes_requested,
                           G_VFS_JOB (job)->cancellable, &err);
  if (s >= 0)
    {
      g_vfs_job_read_set_size (job, s);
      g_vfs_job_succeeded (G_VFS_JOB(job));
    }
  else
    {
      g_vfs_job_failed_from_error (G_VFS_JOB (job), err);
      g_error_free (err);
    }
}


static void
do_seek_on_read (GVfsBackend *backend,
                 GVfsJobSeekRead *job,
                 GVfsBackendHandle _handle,
                 goffset    offset,
                 GSeekType  type)
{
  GError *err = NULL;
  GFileInputStream *stream = _handle;

  g_assert (stream != NULL);

  if (g_seekable_seek (G_SEEKABLE (stream), offset, type, G_VFS_JOB (job)->cancellable, &err)) 
    {
      g_vfs_job_seek_read_set_offset (job, g_seekable_tell (G_SEEKABLE (stream)));
      g_vfs_job_succeeded (G_VFS_JOB(job));
    }
  else
    {
      g_vfs_job_failed_from_error (G_VFS_JOB (job), err);
      g_error_free (err);
    }
}


static void
do_close_read (GVfsBackend *backend,
               GVfsJobCloseRead *job,
               GVfsBackendHandle _handle)
{
  GError *err;
  GFileInputStream *stream = _handle;

  g_assert (stream != NULL);

  if (g_input_stream_close (G_INPUT_STREAM (stream), G_VFS_JOB (job)->cancellable, &err))
    {
      g_object_unref (stream);
      g_vfs_job_succeeded (G_VFS_JOB(job));
    }
  else
    {
      g_vfs_job_failed_from_error (G_VFS_JOB (job), err);
      g_error_free (err);
    }
}

/*---------------------------------------------------------------------------*/

/*
  do_make_directory - Creates a directory file at given path.
 */
static void
do_make_directory (GVfsBackend *backend,
                    GVfsJobMakeDirectory *job,
                    const char *filename)
{
  GError *err = NULL;
  GFile *file;

  file = get_local_file(backend, filename, G_VFS_JOB(job));

  if (file)
    {
      if (g_file_make_directory (file, G_VFS_JOB (job)->cancellable, &err))
        {
          g_vfs_job_succeeded (G_VFS_JOB(job));
        }
      else
        {
          g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
          g_error_free (err);
        }
      g_object_unref (file);
    }
  else
    {
      g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get file from local vfs"); 
    }
}

/*
  do_delete - Deletes a given path.

  FIXME - Does this delete directories also?
 */
static void
do_delete (GVfsBackend *backend,
           GVfsJobDelete *job,
           const char *filename)
{
  GError *err = NULL;
  GFile *file;

  file = get_local_file(backend, filename, G_VFS_JOB(job));

  if (file)
    {
      if (g_file_delete (file, G_VFS_JOB (job)->cancellable, &err))
        {
          g_vfs_job_succeeded (G_VFS_JOB(job));
        }
      else
        {
          g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
          g_error_free (err);
        }
      g_object_unref (file);
    }
  else
    {
      g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get file from local vfs"); 
    }
}

/*
  do_trash - ??

  FIXME - What does it mean to move to trash? 
          Do I move to the trash dir on the drive where wizbit
          dir is located?
          How would this be restored?
 */
static void
do_trash (GVfsBackend *backend,
          GVfsJobTrash *job,
          const char *filename)
{
  GError *err = NULL;
  GFile *file;

  file = get_local_file(backend, filename, G_VFS_JOB(job));

  if (file)
    {
      if (g_file_trash (file, G_VFS_JOB (job)->cancellable, &err))
        {
          g_vfs_job_succeeded (G_VFS_JOB(job));
        }
      else
        {
          g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
          g_error_free (err);
        }
      g_object_unref (file);
    }
  else
    {
      g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get file from local vfs"); 
    }
}

/*
  do_copy - Coipes from one path to another.

  FIXME - Is this supposed to copy recursively?
 */
static void
do_copy (GVfsBackend *backend,
         GVfsJobCopy *job,
         const char *source,
         const char *destination,
         GFileCopyFlags flags,
         GFileProgressCallback progress_callback,
         gpointer progress_callback_data)
{
  GFile *src_file, *dst_file;
  GError *err = NULL;

  src_file = get_local_file(backend, source, G_VFS_JOB(job));
  dst_file = get_local_file(backend, destination, G_VFS_JOB(job));

  if (src_file)
    {
      if (g_file_copy (src_file, dst_file, flags, G_VFS_JOB (job)->cancellable,
                       progress_callback, progress_callback_data, &err))
        {
          g_vfs_job_succeeded (G_VFS_JOB(job));
        }
      else
        {
          g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
        }
      g_object_unref (src_file);
      g_object_unref (dst_file);
    }
  else
    {
      g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get file from local vfs"); 
    }
}

/*
  do_move - Moves one path to another.
 */
static void
do_move (GVfsBackend *backend,
         GVfsJobMove *job,
         const char *source,
         const char *destination,
         GFileCopyFlags flags,
         GFileProgressCallback progress_callback,
         gpointer progress_callback_data)
{
  GFile *src_file, *dst_file;
  GError *err = NULL;

  src_file = get_local_file(backend, source, G_VFS_JOB(job));
  dst_file = get_local_file(backend, destination, G_VFS_JOB(job));

  if (src_file)
    {
      if (g_file_move (src_file, dst_file, flags, G_VFS_JOB (job)->cancellable,
                       progress_callback, progress_callback_data, &err))
        {
          g_vfs_job_succeeded (G_VFS_JOB(job));
        }
      else
        {
          g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
        }
      g_object_unref (src_file);
      g_object_unref (dst_file);
    }
  else
    {
      g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get file from local vfs"); 
    }
}

/*
  do_set_display_name - ??

  FIXME - Isn't this just a rename? Can't we do a rename with a move?
 */
static void
do_set_display_name (GVfsBackend *backend,
                     GVfsJobSetDisplayName *job,
                     const char *filename,
                     const char *display_name)
{
  GError *err = NULL;
  GFile *file;


  file = get_local_file(backend, filename, G_VFS_JOB(job));

  if (file)
    {
      if (g_file_set_display_name (file, display_name, G_VFS_JOB (job)->cancellable, &err))
        {
          char *dirname, *new_path;

          dirname = g_path_get_dirname (filename);
          new_path = g_build_filename (dirname, display_name, NULL);
          g_vfs_job_set_display_name_set_new_path (job, new_path);
          g_free (dirname);
          g_free (new_path);
          g_vfs_job_succeeded (G_VFS_JOB(job));
        }
      else
        {
          g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
          g_error_free (err);
        }
      g_object_unref (file);
    }
  else
    {
      g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get file from local vfs"); 
    }
}

/*---------------------------------------------------------------------------*/

static void
do_create (GVfsBackend *backend,
           GVfsJobOpenForWrite *job,
           const char *filename,
           GFileCreateFlags flags)
{
  GFileOutputStream *stream;
  GError *err = NULL;
  GFile *file;

  file = get_local_file(backend, filename, G_VFS_JOB(job));

  if (file)
    {
      stream = g_file_create (file, flags, G_VFS_JOB (job)->cancellable, &err);
      if (stream) {
          g_vfs_job_open_for_write_set_can_seek (job, g_seekable_can_seek (G_SEEKABLE (stream)));
          g_vfs_job_open_for_write_set_handle (job, stream);
          g_vfs_job_succeeded (G_VFS_JOB(job));
        }
      else
        {
          g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
          g_error_free (err);
        }
      g_object_unref (file);
    }
  else
    {
      g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get file from local vfs"); 
    }
}

static void
do_append_to (GVfsBackend *backend,
              GVfsJobOpenForWrite *job,
              const char *filename,
              GFileCreateFlags flags)
{
  GFileOutputStream *stream;
  GError *err = NULL;
  GFile *file;

  file = get_local_file(backend, filename, G_VFS_JOB(job));

  if (file)
    {
      stream = g_file_append_to (file, flags, G_VFS_JOB (job)->cancellable, &err);
      if (stream)
        {
          if ((g_seekable_seek (G_SEEKABLE (stream), 0,
               G_SEEK_END, G_VFS_JOB (job)->cancellable, &err)) && (!err))
            {
              g_vfs_job_open_for_write_set_initial_offset (job,
                                                           g_seekable_tell (G_SEEKABLE (stream)));
              g_vfs_job_open_for_write_set_can_seek (job, g_seekable_can_seek (G_SEEKABLE (stream)));
              g_vfs_job_open_for_write_set_handle (job, stream);
              g_vfs_job_succeeded (G_VFS_JOB(job));
            }
          else
            {
              g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
              g_error_free (err);
            }
        }
      else
        {
          g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
          g_error_free (err);
        }
      g_object_unref (file);
    }
  else
    {
      g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get file from local vfs"); 
    }
}

static void
do_replace (GVfsBackend *backend,
            GVfsJobOpenForWrite *job,
            const char *filename,
            const char *etag,
            gboolean make_backup,
            GFileCreateFlags flags)
{
  GFileOutputStream *stream;
  GError *err = NULL;
  GFile *file;

  file = get_local_file(backend, filename, G_VFS_JOB(job));

  if (file)
    {
      stream = g_file_replace (file, etag, make_backup, flags, G_VFS_JOB (job)->cancellable, &err);
      if (stream) {
          g_vfs_job_open_for_write_set_can_seek (job, g_seekable_can_seek (G_SEEKABLE (stream)));
          g_vfs_job_open_for_write_set_handle (job, stream);
          g_vfs_job_succeeded (G_VFS_JOB(job));
        }
      else
        {
          g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
          g_error_free (err);
        }
      g_object_unref (file);
    }
  else
    {
      g_vfs_job_failed (G_VFS_JOB(job), G_IO_ERROR, G_IO_ERROR_FAILED,
                        "Cannot get file from local vfs"); 
    }
}


static void
do_write (GVfsBackend *backend,
          GVfsJobWrite *job,
          GVfsBackendHandle _handle,
          char *buffer,
          gsize buffer_size)
{
  GError *err = NULL;
  GFileOutputStream *stream = _handle;
  gssize s;

  s = g_output_stream_write (G_OUTPUT_STREAM (stream), buffer, buffer_size, G_VFS_JOB (job)->cancellable, &err); 
  if (s >= 0) 
    {
      g_vfs_job_write_set_written_size (job, s);
      g_vfs_job_succeeded (G_VFS_JOB(job));
    }
  else
    {
      g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
      g_error_free (err);
    }
}


static void
do_seek_on_write (GVfsBackend *backend,
                  GVfsJobSeekWrite *job,
                  GVfsBackendHandle _handle,
                  goffset    offset,
                  GSeekType  type)
{
  GError *err = NULL;
  GFileOutputStream *stream = _handle;

  if (g_seekable_seek (G_SEEKABLE (stream), offset, type, G_VFS_JOB (job)->cancellable, &err))
    {
      g_vfs_job_seek_write_set_offset (job, g_seekable_tell (G_SEEKABLE (stream)));
      g_vfs_job_succeeded (G_VFS_JOB(job));
    }
  else
    {
      g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
      g_error_free (err);
    }
}


static void
do_close_write (GVfsBackend *backend,
                GVfsJobCloseWrite *job,
                GVfsBackendHandle _handle)
{
  GError *err = NULL;
  GFileOutputStream *stream = _handle;

  if (g_output_stream_close (G_OUTPUT_STREAM(stream), G_VFS_JOB (job)->cancellable, &err))
    {
      g_object_unref (stream);
      g_vfs_job_succeeded (G_VFS_JOB(job));
    }
  else
    {
      g_vfs_job_failed_from_error (G_VFS_JOB (job), err); 
      g_error_free (err);
    }
}

/*---------------------------------------------------------------------------*/

static void
g_vfs_backend_wizbit_class_init (GVfsBackendWizbitClass *klass)
{
  GObjectClass *gobject_class = G_OBJECT_CLASS (klass);
  GVfsBackendClass *backend_class = G_VFS_BACKEND_CLASS (klass);

  gobject_class->finalize = g_vfs_backend_wizbit_finalize;

  backend_class->mount = do_mount;
  backend_class->unmount = do_unmount;

  backend_class->enumerate = do_enumerate;
  backend_class->query_info = do_query_info;
  backend_class->query_fs_info = do_query_fs_info;

  backend_class->set_attribute = do_set_attribute;
  backend_class->query_settable_attributes = do_query_settable_attributes;

  backend_class->open_for_read = do_open_for_read;
  backend_class->read = do_read;
  backend_class->seek_on_read = do_seek_on_read;
  backend_class->close_read = do_close_read;

  backend_class->make_directory = do_make_directory;
  backend_class->delete = do_delete;
  backend_class->trash = do_trash;
  backend_class->copy = do_copy;
  backend_class->move = do_move;
  backend_class->set_display_name = do_set_display_name;

  backend_class->create = do_create;
  backend_class->replace = do_replace;
  backend_class->append_to = do_append_to;
  backend_class->write = do_write;
  backend_class->seek_on_write = do_seek_on_write;
  backend_class->close_write = do_close_write;
#if 0
  backend_class->mount_mountable = do_mount_mountable;
  backend_class->unmount_mountable = do_unmount_mountable;
  backend_class->eject_mountable = do_eject_mountable;

  backend_class->make_symlink = do_make_symlink;

  backend_class->upload = do_upload;
  backend_class->query_writeable_namespaces = do_query_writeable_namespaces;
#endif
}
