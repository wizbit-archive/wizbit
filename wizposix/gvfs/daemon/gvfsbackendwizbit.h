/*
  WizBit : Git based file system
  Copyright (C) 2008  Mark Doffman <mark.doffman@codethink.co.uk>

  This program can be distributed under the terms of the GNU GPL.
  See the file COPYING.
*/

#ifndef __G_VFS_BACKEND_WIZBIT_H__
#define __G_VFS_BACKEND_WIZBIT_H__

#include <gvfsbackend.h>

G_BEGIN_DECLS

#define G_VFS_TYPE_BACKEND_WIZBIT         (g_vfs_backend_wizbit_get_type ())
#define G_VFS_BACKEND_WIZBIT(o)           (G_TYPE_CHECK_INSTANCE_CAST ((o), G_VFS_TYPE_BACKEND_WIZBIT, GVfsBackendWizbit))
#define G_VFS_BACKEND_WIZBIT_CLASS(k)     (G_TYPE_CHECK_CLASS_CAST((k), G_VFS_TYPE_BACKEND_WIZBIT, GVfsBackendWizbitClass))
#define G_VFS_IS_BACKEND_WIZBIT(o)        (G_TYPE_CHECK_INSTANCE_TYPE ((o), G_VFS_TYPE_BACKEND_WIZBIT))
#define G_VFS_IS_BACKEND_WIZBIT_CLASS(k)  (G_TYPE_CHECK_CLASS_TYPE ((k), G_VFS_TYPE_BACKEND_WIZBIT))
#define G_VFS_BACKEND_WIZBIT_GET_CLASS(o) (G_TYPE_INSTANCE_GET_CLASS ((o), G_VFS_TYPE_BACKEND_WIZBIT, GVfsBackendWizbitClass))

typedef struct _GVfsBackendWizbit        GVfsBackendWizbit;
typedef struct _GVfsBackendWizbitClass   GVfsBackendWizbitClass;

struct _GVfsBackendWizbit
{
  GVfsBackend parent_instance;
};

struct _GVfsBackendWizbitClass
{
  GVfsBackendClass parent_class;
};

GType g_vfs_backend_wizbit_get_type (void) G_GNUC_CONST;
GVfsBackendWizbit *g_vfs_backend_wizbit_new (void);

G_END_DECLS

#endif /* __G_VFS_BACKEND_WIZBIT_H__ */
