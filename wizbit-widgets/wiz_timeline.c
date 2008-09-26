/*
 * Wizbit Timeline Viewer
 * Copyright (C) 2008 Codethink LTD
 * Author: Karl Lattimer <karl@qdh.org.uk>
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

#include <glib/gi18n.h>
#include <gtk/gtk.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <signal.h>
#include <gdk/gdkkeysyms.h>
#include <math.h>
#include <cairo.h>
#include <wiz/store.h>
#include <wiz/bit.h>

#include "wiz_timeline.h"

#define WIZ_TIMELINE_GET_PRIVATE(obj) (G_TYPE_INSTANCE_GET_PRIVATE ((obj), WIZ_TYPE_TIMELINE, WizTimelinePrivate))

typedef struct _WizTimelineNode WizTimelineNode;
typedef struct _WizTimelineEdge WizTimelineEdge;

struct _WizTimelineEdge {
  Edge *next;
  Edge *prev;
  Node *nodes[2];
};

struct _WizTimelineNode
{
  gint tip_id;

  gdouble size;
  gchar *version_uuid;

  /* These x/y co-ordinates refer to positions relative to the size
   * of the whole rendered DAG, rather than the portion of the DAG
   * displayed on screen
   */
  guint x;
  guint y;
  guint timestamp;

  gint no_of_edges;
  WizTimelineEdge *edges;
};

struct _WizTimelinePrivate
{
  WizTimelineNode *primary_tip;
  WizTimelineNode *root;
  WizTimelineNode *last_node;
  WizTImelineNode *node;
  WizBit *bit;
  gint *seen;
  gint *edges;
  gint nodes;

  /* We can turn off editability of this widget, if we're working with 
   * bits (files etc...) which can't easily be merged.
   */
  gboolean mergable;

  gchar *bit_uuid;
  gchar *selected_version_uuid;

  gint width;
  gint height;
  gdouble zoom;

  /* The real position of the mouse relative to the full height of the DAG */
  gint real_mouse_x;
  gint real_mouse_y;

  gint x_offset;
  gint visible_height;

  gboolean mouse_down;
  gchar *drag_version_uuid;
  gchar *drop_version_uuid;
};

/* Properties */
enum
{
  PROP_0,
  PROP_STORE,
  PROP_BIT_UUID,
  PROP_BIT,
  PROP_MERGABLE,
  PROP_SELECTED_VERSION_UUID,
  PROP_DRAG_VERSION_UUID,
  PROP_DROP_VERSION_UUID,
  PROP_ZOOM
};

/* Signals */
enum
{
  SELECTION_CHANGED,
  MERGE_TIPS,
  LAST_SIGNAL
};

#define MIN_WIDTH 50
#define MIN_HEIGHT 100

static void wiz_timeline_class_intern_init (gpointer);
static void wiz_timeline_class_init (WizTimelineClass * klass);
static void wiz_timeline_init (WizTimeline * wiz_timeline);
static void wiz_timeline_finalize (GObject * object);
static void wiz_timeline_set_property (GObject * object, guint param_id,
                                       const GValue * value,
                                       GParamSpec * pspec);
static void wiz_timeline_get_property (GObject * object, guint param_id,
                                       GValue * value,
                                       GParamSpec * pspec);
static void wiz_timeline_realize (GtkWidget * widget);
static void wiz_timeline_size_request (GtkWidget * widget,
                                       GtkRequisition * requisition);
static void wiz_timeline_size_allocate (GtkWidget * widget,
                                        GtkAllocation * allocation);
static void wiz_timeline_unrealize (GtkWidget * widget);
static void wiz_timeline_state_changed (GtkWidget * widget,
                                        GtkStateType previous_state);
static void wiz_timeline_style_set (GtkWidget * widget,
                                    GtkStyle * previous_style);
static gint wiz_timeline_pressed (GtkWidget * widget,
                                  GdkEventButton * event);
static gint wiz_timeline_released (GtkWidget * widget,
                                   GdkEventButton * event);
static gboolean wiz_timeline_motion_notify (GtkWidget * widget,
                                            GdkEventMotion * event);
static gboolean wiz_timeline_enter_notify (GtkWidget * widget,
                                           GdkEventCrossing * event);
static gboolean wiz_timeline_leave_notify (GtkWidget * widget,
                                           GdkEventCrossing * event);

static guint timeline_signals[LAST_SIGNAL] = { 0 };

static gpointer wiz_timeline_parent_class = NULL;

// This little cluster fuck tells us if a node has been seen before and
// allocates it if it hasn't, then sets priv->node to that node
static int
get_node (WizTimeline *wiz_timeline, gchar *version_uuid) {
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE(wiz_timeline);
  WizTimelineNode *node;
  priv->node = NULL;
  gint *seen;

  if (priv->seen != NULL) {
    for (i = 0; i < priv->nodes; i++) {
      node = (WizTimelineNode *)priv->seen[k];
      // Compare version_uuid's in memory 
      if (!memcmp(node->version_uuid, version_uuid, 40)) {
        priv->node = tmp_node;
        return TRUE;
      }
    }
  }

  if (priv->node == NULL) {
    node = g_slice_new(WizTimelineNode);
    node->version_uuid = g_strdup (wiz_version_get_version_uuid(wiz_version));
    node->timestamp = wiz_version_get_timestamp(wiz_version);
    node->edges = NULL;

    if (priv->seen == NULL) {
      priv->seen = g_slice_new(WizTimelineNode);
      priv->primary_tip = node;
    } else {
      seen = priv->seen;
      priv->seen = g_slice_copy((priv->nodes + 1) * sizeof(int), seen);
      g_slice_free(seen);
    }
    priv->node = node;
    priv->seen[priv->nodes] = (int)node;
    priv->nodes++;
  }
  return FALSE;
}


/* Iterate over the nodes calling callback with timeline, node and data 
 * if once we've iterated children we still haven't been seen.
 */
static void
recurse_nodes (WizTimeline *wiz_timeline, WizTimelineNode *node, gointer callback, gointer data)
{
  gint i;
  for (i = 0; i < node->no_of_edges; i++) {
    recurse_nodes(wiz_timeline, node->edges->edges[1], callback);
    node->edge = node->edges->next;
  }
  if (!get_node(WizTimeline *wiz_timeline, node->version_uuid)) {
    callback(wiz_timeline, node, data);
  }
}

/* Start are recursion of the dag from the root, it really doesn't matter where
 * we start it should all eventually be touched
 */
static void
iterate_dag (WizTimeline *wiz_timeline, gpointer callback, gpointer data)
{
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE(wiz_timeline);
  WizTimelineNode *node = priv->root;
  recurse_nodes(wiz_timeline, node, callback, data);
}

static void
update_nodes(WizTimeline *wiz_timeline, WizTimelineNode *node, gpointer data)
{
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE(wiz_timeline);
  /* work out the x/y co-ordinates of the dag, to do this we compare the
   * timesdtamp of this node and the timestamp of the root version and 
   * the primary tip then perform a simple set of comparisons with them.
   */
  /* we also update the offset from the position of the sliders
   */
}

static void
render_node(WizTimeline *wiz_timeline, WizTimelineNode *node, cairo_t *cr)
{
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE(wiz_timeline);
  /* Draw the node where we told it to be drawn
   */
}

static void
render (GtkWidget * widget)
{
  WizTimeline *wiz_timeline = WIZ_TIMELINE (widget);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE(wiz_timeline);
  cairo_t *cr = gdk_cairo_create (widget->window);
  gint width, height;
  GError *error = NULL;
  gdk_drawable_get_size (widget->window, &width, &height);
  iterate_dag(wiz_timeline, update_coords, NULL);
  iterate_dag(wiz_timeline, render, cr);
  cairo_destroy (cr);
}

/* Adds an edge to the linked list for edges of src */
static void 
add_edge(WizTimelineNode *src, WizTimelineNode *dst) {
  gboolean new_edge = FALSE;
  WizTimelineEdge *edge = g_slice_new(WizTimelineEdge);
  WizTimelineEdge *tmp_edge;
  gint i;
  gboolean edge_exists;

  edge->nodes[0] = src;
  edge->nodes[1] = dst;
  if (src->edges == NULL) {
    edge->next = edge;
    edge->prev = edge;
    src->edges = edge;
  } else {
    edge_exists = FALSE;
    // Look for existing edge matching this edge
    for (k = 0; k < src->no_of_edges; k++) {
      if (src->edges->nodes[1] == dst) {
        g_slice_free(edge);
        edge_exists = TRUE;
        break;
      }
      src->edges = src->edges->next;
    }

    if (edge_exists == FALSE) {
      tmp_edge = src->edges;
      edge->prev = tmp_edge->prev;
      edge->prev->next = edge;
      tmp_edge->prev = edge;
      edge->next = tmp_edge;
    }
  }
  src->no_of_edges++;
}

void iterate_reflog(WizVersion *wiz_version, WizTimeline *wiz_timeline) 
{
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE(wiz_timeline);

  WizTimelineNode *node = NULL;
  WizTimelineNode *tmp_node;

  do {
    /* Find out whether or not this node has already been seen, otherwise
     * create a new node and add it to the seen list
     */
    get_node(wiz_timeline, wiz_version_get_version_uuid(wiz_version));
    node = priv->node;
    
    /* Hook up the edges, this include the new edge between this node and
     * the previous node, and the previous node and this one. Creating an
     * undirected graph from the directed graph, while we're at it, we avoid
     * existing edges between the two nodes in question
     */
    if (priv->last_node != NULL) {  
      add_edge(node, priv->last_node);  
      add_edge(priv->last_node, node);
    }
    priv->last_node = node;
    wiz_version = wiz_version_get_previous(wiz_version);
  } while (wiz_version != NULL);
}

/* Update the widget DAG from the WizStore, this requires retireving the bit
 * and iterating over the versions committed to the bit. :/ This will be slow
 * especially slow when we're updating from packed data. Missing out parts
 * which we know aren't effected might help. Performing UI changes internally
 * would also help, however we must be able to confirm that changes were under-
 * taken in the store.
 */
void 
wiz_timeline_update_from_store (WizTimeline *wiz_timeline) 
{
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE(wiz_timeline);
  // free??!?
  priv->seen = NULL;
  priv->last_node = NULL;
  g_list_foreach(wiz_bit_get_tips(priv->bit), iterate_reflog, wiz_timeline);
  priv->root = priv->last_node;
}

GType
wiz_timeline_get_type ()
{
  static GType wiz_timeline_type = 0;

  if (!wiz_timeline_type)
    {
      static const GTypeInfo wiz_timeline_info = {
        sizeof (WizTimelineClass),
        NULL,
        NULL,
        (GClassInitFunc) wiz_timeline_class_intern_init,
        NULL,
        NULL,
        sizeof (WizTimeline),
        0,
        (GInstanceInitFunc) wiz_timeline_init,
      };

      wiz_timeline_type =
        g_type_register_static (GTK_TYPE_DRAWING_AREA, "WizTimeline",
                                &wiz_timeline_info, 0);
    }

  return wiz_timeline_type;
}

static void
wiz_timeline_size_request (GtkWidget * widget,
                           GtkRequisition * requisition)
{
  g_return_if_fail (widget != NULL || requisition != NULL);
  g_return_if_fail (WIZ_IS_TIMELINE (widget));

  requisition->width = MIN_WIDTH;
  requisition->height = MIN_HEIGHT;
}

static void
wiz_timeline_size_allocate (GtkWidget * widget,
                            GtkAllocation * allocation)
{
  WizTimeline *wiz_timeline;

  g_return_if_fail (widget != NULL || allocation != NULL);
  g_return_if_fail (WIZ_IS_TIMELINE (widget));

  widget->allocation = *allocation;
  wiz_timeline = WIZ_TIMELINE (widget);

  if (GTK_WIDGET_REALIZED (widget))
    {
      gdk_window_move_resize (widget->window, allocation->x, allocation->y,
                              allocation->width, allocation->height);
    }
}

static void
wiz_timeline_style_set (GtkWidget * widget, GtkStyle * previous_style)
{
  GTK_WIDGET_CLASS (wiz_timeline_parent_class)->style_set (widget, previous_style);
}

GtkWidget *
wiz_timeline_new (WizStore *store, const gchar *bit_uuid)
{
  return g_object_new (WIZ_TYPE_TIMELINE, "store", store, "bit-uuid", bit_uuid,
                       NULL);
}

static void
wiz_timeline_class_intern_init (gpointer klass)
{
  wiz_timeline_parent_class = g_type_class_peek_parent (klass);
  wiz_timeline_class_init ((WizTimelineClass *) klass);
}

static void
wiz_timeline_init (WizTimeline * wiz_timeline)
{
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE (wiz_timeline);

  /* TODO Set some defaults */
  /*priv->********=*/

  g_signal_connect (wiz_timeline, "expose-event",
            G_CALLBACK (expose_event), wiz_timeline);
}

static void
wiz_timeline_realize (GtkWidget * widget)
{
  GTK_WIDGET_CLASS (wiz_timeline_parent_class)->realize (widget);
  render (widget);
}

static void
wiz_timeline_unrealize (GtkWidget * widget)
{
  GTK_WIDGET_CLASS (wiz_timeline_parent_class)->unrealize (widget);
}

static void
wiz_timeline_finalize (GObject * object)
{
  WizTimeline *wiz_timeline = WIZ_TIMELINE (object);
  /* TODO Cleanup and destroy anything left over */
  /* Iterate over and deallocate all of the dag, to do this, we iterate over
   * from the root to the tips deallocating edges first and appending nodes
   * to the seen list, then we iterate over the seen list and de-allocate it.
   * this should be made into a function so it's callable as a routing to roll
   * through to deallocate the dag. iterate_dag ^^
   */
  G_OBJECT_CLASS (wiz_timeline_parent_class)->finalize (object);
}

static void
wiz_timeline_class_init (WizTimelineClass * klass)
{
  GObjectClass *gobject_class;
  GtkWidgetClass *widget_class;

  gobject_class = G_OBJECT_CLASS (klass);
  widget_class = GTK_WIDGET_CLASS (klass);

  gobject_class->get_property = wiz_timeline_get_property;
  gobject_class->set_property = wiz_timeline_set_property;
  gobject_class->finalize = wiz_timeline_finalize;
  widget_class->size_request = wiz_timeline_size_request;
  widget_class->size_allocate = wiz_timeline_size_allocate;
  widget_class->realize = wiz_timeline_realize;
  widget_class->unrealize = wiz_timeline_unrealize;
  widget_class->style_set = wiz_timeline_style_set;
  widget_class->button_press_event = wiz_timeline_pressed;
  widget_class->button_release_event = wiz_timeline_released;
  widget_class->motion_notify_event = wiz_timeline_motion_notify;
  widget_class->enter_notify_event = wiz_timeline_enter_notify;
  widget_class->leave_notify_event = wiz_timeline_leave_notify;

  g_object_class_install_property (gobject_class,
                                   PROP_STORE,
                                   g_param_spec_pointer ("store",
                                     "Store",
                                     "A pointer to the wizbit store",
                                     G_PARAM_READWRITE)
                                  );

  g_object_class_install_property (gobject_class,
                                   PROP_BIT_UUID,
                                   g_param_spec_string ("bit-uuid",
                                     "Bit UUID",
                                     "A UUID of a bit",
                                     NULL,
                                     G_PARAM_READWRITE)
                                  );

  g_object_class_install_property (gobject_class,
                                   PROP_BIT,
                                   g_param_spec_pointer ("bit",
                                     "Bit",
                                     "A pointer to a bit",
                                     G_PARAM_READABLE)
                                  );

  g_object_class_install_property (gobject_class,
                                   PROP_MERGABLE,
                                   g_param_spec_boolean ("mergable",
                                     "Mergable",
                                     "Whether this bit allows merging",
                                     FALSE,
                                     G_PARAM_READWRITE)
                                  );  

  g_object_class_install_property (gobject_class,
                                   PROP_SELECTED_VERSION_UUID,
                                   g_param_spec_string ("selected-version-uuid",
                                     "Selected Version UUID",
                                     "A UUID of a version",
                                     NULL,
                                     G_PARAM_READWRITE)
                                  );

  g_object_class_install_property (gobject_class,
                                   PROP_DRAG_VERSION_UUID,
                                   g_param_spec_string ("drag-version-uuid",
                                     "Dragged Version UUID",
                                     "A UUID of a version",
                                     NULL,
                                     G_PARAM_READABLE)
                                  );

  g_object_class_install_property (gobject_class,
                                   PROP_DROP_VERSION_UUID,
                                   g_param_spec_string ("drop-version-uuid",
                                     "Dropped Version UUID",
                                     "A UUID of a version",
                                     NULL,
                                     G_PARAM_READABLE)
                                  );

  g_object_class_install_property (gobject_class,
                                   PROP_ZOOM,
                                   g_param_spec_double ("zoom", 
                                     "Zoom",
                                     "The zoom level of the DAG",
                                     0, 1, 0,
                                     G_PARAM_READWRITE)
                                  );

  klass->selection_changed = NULL;
  klass->merge_tips = NULL;

  wiz_timeline_signals[SELECTION_CHANGED] = g_signal_new ("selection_changed",
                                                          G_TYPE_FROM_CLASS
                                                          (gobject_class),
                                                          G_SIGNAL_RUN_FIRST,
                                                          G_STRUCT_OFFSET
                                                          (WizTimelineClass,
                                                          selection_changed), 
                                                          NULL, NULL,
                                                          gtk_marshal_VOID__VOID,
                                                          G_TYPE_NONE, 0);

  wiz_timeline_signals[SELECTION_CHANGED] = g_signal_new ("merge_tips",
                                                          G_TYPE_FROM_CLASS
                                                          (gobject_class),
                                                          G_SIGNAL_RUN_FIRST,
                                                          G_STRUCT_OFFSET
                                                          (WizTimelineClass,
                                                          merge_tips), 
                                                          NULL, NULL,
                                                          gtk_marshal_VOID__VOID,
                                                          G_TYPE_NONE, 0);

  g_type_class_add_private (gobject_class, sizeof (WizTimelinePrivate));
}

static void
wiz_timeline_set_property (GObject * object,
                           guint param_id,
                           const GValue * value, GParamSpec * pspec)
{
  WizTimeline *wiz_timeline = WIZ_TIMELINE (object);

  switch (param_id)
    {
    case PROP_STORE:
      wiz_timeline_set_store (wiz_timeline,
                     g_value_get_pointer (value));
      break;
    case PROP_BIT_UUID:
      wiz_timeline_set_bit_uuid (wiz_timeline, g_value_get_string (value));
      break;
    case PROP_MERGABLE:
      wiz_timeline_set_mergable (wiz_timeline, g_value_get_boolean (value));
      break;
    case PROP_SELECTED_VERSION_UUID:
      wiz_timeline_set_selected_version_uuid (wiz_timeline, g_value_get_string (value));
      break;
    case PROP_ZOOM:
      wiz_timeline_set_cbtype (wiz_timeline, g_value_get_double (value));
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, param_id, pspec);
      break;
    }
}

static void
wiz_timeline_get_property (GObject * object,
                           guint param_id,
                           GValue * value, GParamSpec * pspec)
{
  WizTimeline *wiz_timeline = WIZ_TIMELINE (object);

  switch (param_id)
    {
    case PROP_STORE:
      g_value_set_pointer (value, wiz_timeline_get_store (wiz_timeline));
      break;
    case PROP_BIT_UUID:
      g_value_set_string (value, wiz_timeline_get_bit_uuid (wiz_timeline));
      break;
    case PROP_BIT:
      g_value_set_pointer (value, wiz_timeline_get_bit (wiz_timeline));
      break;
    case PROP_MERGABLE 
      g_value_set_boolean (value, wiz_timeline_get_mergable (wiz_timeline));
      break;
    case PROP_SELECTED_VERSION_UUID:
      g_value_set_string (value, wiz_timeline_get_selected_version_uuid (wiz_timeline));
      break;
    case PROP_DRAG_VERSION_UUID:
      g_value_set_string (value, wiz_timeline_get_drag_version_uuid (wiz_timeline));
      break;
    case PROP_DROP_VERSION_UUID:
      g_value_set_string (value, wiz_timeline_get_drop_version_uuid (wiz_timeline));
      break;
    case PROP_ZOOM:
      g_value_set_double (value, wiz_timeline_get_zoom(wiz_timeline));
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, param_id, pspec);
      break;
    }
}

void 
wiz_timeline_set_selected_version (WizTimeline *wiz_timeline, 
                                   const gchar *version_uuid) 
{
  gchar *old_uuid;
  g_return_val_if_fail (WIZ_IS_TIMELINE (wiz_timeline), NULL);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE (wiz_timeline);

  old_uuid = priv->selected_version_uuid;
  priv->bit_uuid = g_strdup (version_uuid);
  g_free (old_uuid);

  wiz_timeline_update_from_store(wiz_timeline);
  g_object_notify (G_OBJECT (wiz_timeline), "selected-version-uuid");
}

G_CONST_RETURN gchar *
wiz_timeline_get_selected_version_uuid (WizTimeline *wiz_timeline) 
{
  g_return_val_if_fail (WIZ_IS_TIMELINE (wiz_timeline), NULL);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE (wiz_timeline);
  return priv->selected_version_uuid;
}

G_CONST_RETURN gchar *
wiz_timeline_get_drag_version_uuid (WizTimeline *wiz_timeline)
{
  g_return_val_if_fail (WIZ_IS_TIMELINE (wiz_timeline), NULL);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE (wiz_timeline);
  return priv->drag_version_uuid;
}

G_CONST_RETURN gchar *
wiz_timeline_get_drop_version_uuid (WizTimeline *wiz_timeline)
{
  g_return_val_if_fail (WIZ_IS_TIMELINE (wiz_timeline), NULL);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE (wiz_timeline);
  return priv->drop_version_uuid;
}

void 
wiz_timeline_set_store (WizTimeline *wiz_timeline, WizStore *store)
{
  g_return_val_if_fail (WIZ_IS_TIMELINE (wiz_timeline), NULL);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE (wiz_timeline);
  /* FIXME Should we free the old store? */
  priv->store = store;
  g_object_notify (G_OBJECT (wiz_timeline), "store");  
}

WizStore *
wiz_timeline_get_store (WizTimeline *wiz_timeline)
{
  g_return_val_if_fail (WIZ_IS_TIMELINE (wiz_timeline), NULL);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE (wiz_timeline);
  return priv->store;
}

void 
wiz_timeline_set_bit_uuid (WizTimeline *wiz_timeline, gchar *bit_uuid)
{
  gchar *old_uuid;
  g_return_val_if_fail (WIZ_IS_TIMELINE (wiz_timeline), NULL);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE (wiz_timeline);

  old_uuid = priv->bit_uuid;
  priv->bit_uuid = g_strdup (bit_uuid);
  g_free (old_uuid);

  wiz_timeline_update_from_store(wiz_timeline);
  g_object_notify (G_OBJECT (wiz_timeline), "bit-uuid");
}

G_CONST_RETURN gchar *
wiz_timeline_get_bit_uuid(WizTimeline *wiz_timeline)
{
  g_return_val_if_fail (WIZ_IS_TIMELINE (wiz_timeline), NULL);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE (wiz_timeline);
  return priv->bit_uuid;
}

WizBit *
wiz_timeline_get_bit(WizTimeline *wiz_timeline)
{
  g_return_val_if_fail (WIZ_IS_TIMELINE (wiz_timeline), NULL);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE (wiz_timeline);
  return priv->bit;
}

void 
wiz_timeline_set_zoom (WizTimline *wiz_timeline, gdouble zoom)
{
  g_return_val_if_fail (WIZ_IS_TIMELINE (wiz_timeline), NULL);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE (wiz_timeline);
  priv->zoom = zoom;
  g_object_notify (G_OBJECT (wiz_timeline), "zoom");
}

gdouble 
wiz_timeline_get_zoom (WizTimeline *wiz_timeline)
{
  g_return_val_if_fail (WIZ_IS_TIMELINE (wiz_timeline), NULL);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE (wiz_timeline);
  return priv->zoom;
}

/* This computes the zoom factor based on version->commit timestamps 
 * we need to iterate over the DAG to determine the limits :/
 */
void 
wiz_timeline_set_view_range (WizTimeline *wiz_timeline, 
                             gint start_timestamp, 
                             gint end_timestamp)
{
  g_return_val_if_fail (WIZ_IS_TIMELINE (wiz_timeline), NULL);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE (wiz_timeline);
  // TODO
  g_object_notify (G_OBJECT (wiz_timeline), "zoom");  
}


void 
wiz_timeline_set_mergable (WizTimeline *wiz_timeline, gboolean mergable)
{
  g_return_val_if_fail (WIZ_IS_TIMELINE (wiz_timeline), NULL);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE (wiz_timeline);
  priv->mergable = mergable;
  g_object_notify (G_OBJECT (wiz_timeline), "mergable");
}

gboolean 
wiz_timeline_get_mergable (WizTimeline *wiz_timeline)
{
  g_return_val_if_fail (WIZ_IS_TIMELINE (wiz_timeline), NULL);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE (wiz_timeline);
  return priv->mergable;
}

/* EVENTS */

/* Handle exposure events for the timeline's drawing area */
static gint
expose_event (GtkWidget * widget, GdkEventExpose * event, gpointer data)
{
  render (GTK_WIDGET (data));

  return FALSE;
}

static gint
wiz_timeline_pressed (GtkWidget * widget, GdkEventButton * event)
{
  WizTimeline *wiz_timeline = WIZ_TIMELINE (widget);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE(wiz_timeline);
  priv->mouse_down = TRUE;
  /* TODO Iterate over the DAG and set the drag version if any */

  return 0;
}

static gint
wiz_timeline_released (GtkWidget * widget, GdkEventButton * event)
{
  WizTimeline *wiz_timeline = WIZ_TIMELINE (widget);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE(wiz_timeline);
  priv->mouse_down = FALSE;
  /* Figure out if the version has been dropped on another element, and fire
   * the MERGE_TIP event, receivers of this event should then call WizBit to
   * merge the versions, and call WizTimeline to update the onscreen DAG
   * immediately afterwards.
   */

  // TODO
  return 0;
}

static gboolean
wiz_timeline_motion_notify (GtkWidget * widget, GdkEventMotion * event)
{
  WizTimeline *wiz_timeline = WIZ_TIMELINE (widget);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE(wiz_timeline);

  if ((priv->mouse_down) && (priv->drag_version_uuid != NULL))
    render(widget);

  return FALSE;
}

static gboolean
wiz_timeline_enter_notify (GtkWidget * widget, GdkEventCrossing * event)
{
  WizTimeline *wiz_timeline = WIZ_TIMELINE (widget);

  return FALSE;
}

static gboolean
wiz_timeline_leave_notify (GtkWidget * widget, GdkEventCrossing * event)
{
  WizTimeline *wiz_timeline = WIZ_TIMELINE (widget);
  WizTimelinePrivate *priv = WIZ_TIMELINE_GET_PRIVATE(wiz_timeline);
  priv->mouse_down = FALSE;

  return FALSE;
}

#define __WIZ_TIMELINE_C__
