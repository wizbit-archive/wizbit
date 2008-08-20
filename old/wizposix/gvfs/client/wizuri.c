/*
  WizBit : Git based file system
  Copyright (C) 2008  Mark Doffman <mark.doffman@codethink.co.uk>

  This program can be distributed under the terms of the GNU GPL.
  See the file COPYING.
*/

#include <config.h>
#include <string.h>

#include <stdlib.h>

#include <gio/gio.h>
#include <gvfsurimapper.h>
#include <gvfsuriutils.h>

static const char *uri_schemes[] = {
  "wizbit",
  NULL
};

static const char *mount_types[] = {
  "wizbit",
  NULL
};

typedef struct _WizUriMapper WizUriMapper;
typedef struct _WizUriMapperClass WizUriMapperClass;

struct _WizUriMapper
{
  GVfsUriMapper parent;
};

struct _WizUriMapperClass
{
  GVfsUriMapperClass parent;
};

GType wiz_uri_mapper_get_type (void);
void  wiz_uri_mapper_register (GIOModule *module);

G_DEFINE_DYNAMIC_TYPE (WizUriMapper, wiz_uri_mapper, G_VFS_TYPE_URI_MAPPER)

/*
  find_base_path - Gets the root wizbit path from the given path.
                   Currently done the stupid way by moving from parent to 
                   parent looking for a directory that exists and contains the
                   entry ".wiz".
 */
static char *
find_base_path(const char *path)
{
  /*
    Get file for path,
    Check if ".wiz" child exists,
    Move to parent,
    Repeat until found or no parent.
   */
  GFile *cur, *tmp;
  char *base_path = NULL;

  cur = g_file_new_for_path (path);
  while (cur && !base_path)
    {
      GFile *child;

      child = g_file_get_child(cur, ".wiz");
      if(g_file_query_exists(child, NULL))
        {
          base_path = g_file_get_path(cur);
        }
      g_object_unref(G_OBJECT(child));

      tmp = g_file_get_parent(cur);
      g_object_unref(G_OBJECT(cur));
      cur = tmp;
    }

  return base_path;
}

static void
wiz_uri_mapper_init (WizUriMapper *vfs)
{
}

static const char * const *
wiz_get_handled_schemes (GVfsUriMapper *mapper)
{
  return uri_schemes;
}

/*
  wiz_from_uri - Gets a mount info for a given URI. A mount info is a MountSpec
                 with an associated path. A MountSpec uniquely identifies a mount.

  The unique identifier for a wizbit mount is simply its base directory.
  So a uuid of wizbit:///a/base/path/with/a/file becomes:

  type : wizbit
  base : /a/base/path
  path : /with/a/file

  With type and base making up the MountSpec and unique identifier.
 */
static GVfsUriMountInfo *
wiz_from_uri (GVfsUriMapper *mapper,
              const char     *uri_str)
{
  GVfsUriMountInfo *info = NULL;
  char *path = NULL;
  char *base_path = NULL;
  GDecodedUri *uri;

  uri = g_vfs_decode_uri (uri_str);

  if (uri && uri->path)
    {
      base_path = find_base_path(uri->path);
      path = uri->path;
      uri->path = NULL;
      g_vfs_decoded_uri_free (uri);
    }

  if (base_path)
    {
      char *relative_path;

      info = g_vfs_uri_mount_info_new ("wizbit");
      g_vfs_uri_mount_info_set (info, "base", base_path);

      relative_path = path;
      while (*relative_path == *base_path)
        {
          relative_path++;
          base_path++;
        }
      info->path = g_strdup(relative_path);
      g_free(path);
    }

  return info;
}

/*
  wiz_get_mount_info_for_path - Makes a MountInfo from an old MountInfo and a new path.

  Replaces new path with old one. Assumes new path is contined within base.
  TODO - Find out what the purpose of this function is.
 */
static GVfsUriMountInfo *
wiz_get_mount_info_for_path (GVfsUriMapper *mapper,
                             GVfsUriMountInfo *info,
                             const char *new_path)
{
  GVfsUriMountInfo *new_info = NULL;
  const char *type;

  type = g_vfs_uri_mount_info_get (info, "type");

  if (strcmp (type, "wizbit") == 0)
    {
      const char *base;

      new_info = g_vfs_uri_mount_info_new ("wizbit");
      base = g_vfs_uri_mount_info_get (info, "base");
      g_vfs_uri_mount_info_set (new_info, "base", g_strdup(base));
      new_info->path = g_strdup(new_path);
    }
  return new_info;
}

static const char * const *
wiz_get_handled_mount_types (GVfsUriMapper *mapper)
{
  return mount_types;
}

static char *
wiz_to_uri (GVfsUriMapper    *mapper,
            GVfsUriMountInfo *info,
            gboolean          allow_utf8)
{
  char       *res = NULL;
  const char *uri = "wizbit://";
  const char *type;

  type = g_vfs_uri_mount_info_get (info, "type");

  if (strcmp (type, "wizbit") == 0)
    {
      res = g_strconcat(uri, g_vfs_uri_mount_info_get(info, "base"), info->path, NULL);
    }
  return res;
}

static const char *
wiz_to_uri_scheme (GVfsUriMapper    *mapper,
                   GVfsUriMountInfo *info)
{
  const gchar *type;

  type = g_vfs_uri_mount_info_get (info, "type");

  if (strcmp (type, "wizbit") == 0)
     return "wizbit";
  else
     return NULL; 
}

static void
wiz_uri_mapper_class_finalize (WizUriMapperClass *klass)
{
}

static void
wiz_uri_mapper_class_init (WizUriMapperClass *klass)
{
  GVfsUriMapperClass *mapper = G_VFS_URI_MAPPER_CLASS(klass);

  mapper->get_handled_schemes     = wiz_get_handled_schemes;
  mapper->from_uri                = wiz_from_uri;
  mapper->get_mount_info_for_path = wiz_get_mount_info_for_path;
  mapper->get_handled_mount_types = wiz_get_handled_mount_types;
  mapper->to_uri                  = wiz_to_uri;
  mapper->to_uri_scheme           = wiz_to_uri_scheme;
}

void
g_vfs_uri_mapper_wizbit_register (GIOModule *module)
{
  wiz_uri_mapper_register_type (G_TYPE_MODULE (module));
}
