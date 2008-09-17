/*
 * Gnome system monitor colour pickers
 * Copyright (C) 2007 Karl Lattimer <karl@qdh.org.uk>
 * All rights reserved.
 *
 * This Library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with the software; see the file COPYING. If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifndef __WIZ_TIMELINE_H__
#define __WIZ_TIMELINE_H__

#include <glib.h>
#include <gdk/gdk.h>
#include <gtk/gtkdrawingarea.h>

G_BEGIN_DECLS
#define WIZ_TYPE_TIMELINE             (wiz_timeline_get_type ())
#define WIZ_TIMELINE(obj)             (G_TYPE_CHECK_INSTANCE_CAST ((obj), WIZ_TYPE_TIMELINE, WizTimeline))
#define WIZ_TIMELINE_CLASS(klass)     (G_TYPE_CHECK_CLASS_CAST ((klass),  WIZ_TYPE_TIMELINE, WizTimelineClass))
#define WIZ_IS_TIMELINE(obj)          (G_TYPE_CHECK_INSTANCE_TYPE ((obj), WIZ_TYPE_TIMELINE))
#define WIZ_IS_TIMELINE_CLASS(klass)  (G_TYPE_CHECK_CLASS_TYPE ((klass),  WIZ_TYPE_TIMELINE))
#define WIZ_TIMELINE_GET_CLASS(obj)   (G_TYPE_INSTANCE_GET_CLASS ((obj),  WIZ_TYPE_TIMELINE, WizTimelineClass))
typedef struct _WizTimeline           WizTimeline;
typedef struct _WizTimelineClass      WizTimelineClass;
typedef struct _WizTimelinePrivate    WizTimelinePrivate;
typedef struct _WizTimelineDag        WizTimelineDag;

struct _WizTimeline
{
  GtkDrawingArea widget;

  /*< private > */

  WizTimelinePrivate *priv;
};

struct _WizTimelineClass
{
  void (*selection_changed) (WizTimeline *wiz_timeline);
  void (*merge_tips) (WizTimeline *wiz_timeline);

  GtkWidgetClass parent_class;
};

GType wiz_timeline_get_type (void) G_GNUC_CONST;
GtkWidget *wiz_timeline_new (WizStore *store, const gchar *bit_uuid);

void wiz_timeline_update_from_store (WizTimeline *wiz_timeline);

/* Getters/Setters */
void wiz_timeline_set_selected_version (WizTimeline *wiz_timeline, const gchar *version_uuid);
G_CONST_RETURN gchar *wiz_timeline_get_selected_version_uuid (WizTimeline *wiz_timeline);
G_CONST_RETURN gchar *wiz_timeline_get_drag_version_uuid (WizTimeline *wiz_timeline);
G_CONST_RETURN gchar *wiz_timeline_get_drop_version_uuid (WizTimeline *wiz_timeline);
void wiz_timeline_set_store (WizTimeline *wiz_timeline, WizStore *store);
WizStore *wiz_timeline_get_store (WizTimeline *wiz_timeline);
void wiz_timeline_set_bit_uuid (WizTimeline *wiz_timeline, gchar *bit_uuid);
G_CONST_RETURN gchar *wiz_timeline_get_bit_uuid(WizTimeline *wiz_timeline);
WizBit *wiz_timeline_get_bit(WizTimeline *wiz_timeline);
void wiz_timeline_set_zoom (WizTimline *wiz_timeline, gdouble zoom);
gdouble wiz_timeline_get_zoom (WizTimeline *wiz_timeline);
void wiz_timeline_set_view_range (WizTimeline *wiz_timeline, gint start_timestamp, gint end_timestamp);
void wiz_timeline_set_mergable (WizTimeline *wiz_timeline, gboolean mergable);
gboolean wiz_timeline_get_mergable (WizTimeline *wiz_timeline);

G_END_DECLS
#endif /* __WIZ_TIMELINE_H__ */
