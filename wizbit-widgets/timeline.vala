/**
 * $LGPL header$
 */

/**
 * TODO
 *  1. Signal emitted for selection changed
 *  2. Work out the size allocation stuff
 *  3. Work out the realization stuff, ensure we're grabbing the correct
 *     events, we need button press, and motion notify, possibly configure.
 *  4. Dag loading in update from store
 */

using GLib;
using Gtk;
using Cairo;

namespace Wiz {
  /* Each edge is a connetion in a certain direction, from the parent to the
   * child
   */
  public class Edge : Glib.Object {
    private Node parent { get; }
    private Node child { get; }

    public Edge(Node parent, Node child) {
      this.parent = parent;
      this.child = child;
    }
  }

  /* Each node has multiple edges, these edges connect the node to other nodes
   * the edges contain the direction of this connection. The node also stores
   * its position and size within the widget.
   */
  public class Node : Glib.Object { // Probably should specialise from CommitNode in commit_store.vala
    public double size { get; set; }
    public string version_uuid { get; construct; }
    public int timestamp { get; construct; }
    public int column { get; set; }
    public double position { get; set; }
    public List<Edge> edges { get; construct; }

    public Node (string version_uuid, int timestamp) {
      this.version_uuid = version_uuid;
      this.timestamp = timestamp;
      this.edges = new List<Edge>();
      // Add edges, only one direction is required, we should probably go for children
    }
  }

  public class Timeline : Gtk.Widget {
    private List<Node> nodes;
    private List<Node> tips;
    private Node primary_tip;
    private Node root;
    private Bit bit;
    private Store store;
    private int default_width;
    private int default_height;
    public string selected_version_uuid { get; set; }
    public double zoom { get; set; }
    public int offset { get; set; }

    public string bit_uuid {
      get {
        return this.bit.uuid;
      }
      set {
        this.bit = this.store.open_bit(value);
      }
    }

    // We can construct with no bit specified, and use bit_uuid to open the bit
    public Timeline(Store store, string? bit_uuid) {
      this.store = store;

      if (bit_uuid != null) {
        this.bit_uuid = bit_uuid;
      }
    }

    construct {
      this.nodes = new List<Node>();
      this.update_from_store();
      this.default_width = 80;
      this.default_height = 160;
    }

    public void update_from_store () {
      // Use commit_store get_nodes to retrieve all nodes, each node will then
      // on construct tie up the edges itself (that's the theory at least)
    }

    public void set_view_range(int start_timestamp, int end_timestamp) {
    }

    public override void realize () {
      // First set an internal flag telling that we're realized
      this.set_flags (Gtk.WidgetFlags.REALIZED);
 
      // Create a new gdk.Window which we can draw on.
      // Also say that we want to receive exposure events by setting
      // the event_mask
      var attrs = Gdk.WindowAttr ();
      attrs.window_type = Gdk.WindowType.CHILD;
      attrs.width = this.allocation.width;
      attrs.wclass = Gdk.WindowClass.INPUT_OUTPUT;
      attrs.event_mask = this.get_events() | Gdk.EventMask.EXPOSURE_MASK | 
                                             Gdk.EventMask.POINTER_MOTION_MASK |
                                             Gdk.EventMask.BUTTON_PRESS_MASK |
                                             Gdk.EventMask.BUTTON_RELEASE_MASK;
      this.window = new Gdk.Window (this.get_parent_window (), attrs, 0);
 
      // Associate the gdk.Window with ourselves, Gtk+ needs a reference
      // between the widget and the gdk window
      this.window.set_user_data (this);
 
      // Attach the style to the gdk.Window, a style contains colors and
      // GC contextes used for drawing
      this.style = this.style.attach (this.window);
 
      // The default color of the background should be what
      // the style (theme engine) tells us.
      this.style.set_background (this.window, Gtk.StateType.NORMAL);
      this.window.move_resize (this.allocation.x, this.allocation.y,
                               this.allocation.width, this.allocation.height);
    }


    public override void unrealize () {
      this.window.set_user_data (null);
    }

    public override void size_request (Gtk.Requisition requisition) {
      requisition.width = this.default_width;
      requisition.height = this.default_height; 
    }

    public override void size_allocate (Gdk.Rectangle allocation) {
      // Save the allocated space
      this.allocation = (Gtk.Allocation)allocation;
 
      // If we're realized, move and resize the window to the
      // requested coordinates/positions
      if ((this.get_flags () & Gtk.WidgetFlags.REALIZED) == 0)
        return;
      this.window.move_resize (this.allocation.x, this.allocation.y,
                               this.allocation.width, this.allocation.height);
    }

    public override bool expose_event (Gdk.EventExpose event) {
      var cr = Gdk.cairo_create (this.window);
      /*Gdk.cairo_set_source_color (cr, this.style.fg[this.state]);
      cr.rectangle (this._BORDER_WIDTH,
                    this._BORDER_WIDTH,
                    this.allocation.width - 2*this._BORDER_WIDTH,
                    this.allocation.height - 2*this._BORDER_WIDTH);
      cr.set_line_width (5.0);
      cr.set_line_join (Cairo.LineJoin.ROUND);
      cr.stroke ();*/
      return true;
    }
  }
}
