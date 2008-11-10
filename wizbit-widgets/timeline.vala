/**
 * $LGPL header$
 */

/**
 * TODO
 *  1. Signal emitted for selection changed
 *  2. Add signal handlers for motion, button press/release
 *  3. Add zoom calculations
 *  4. Figure out whether or not the node needs to be visible
 *  5. Setting the selected node will scroll it to center
 *  6. Animations while timeline view changes, don't let zooming/panning
 *     be jumpy.
 *  7. Prevent duplicate nodes being loaded when appending offscreen
       adjacent nodes, or simply remove duplicates every time we update
       nodes.
 *  8. Rename a bunch of things which are horribly named!
 *  9. Optimize the shizzle out of it! profile update_from_store especially
 *  x. This TODO list is not upto date
 */

using GLib;
using Gtk;
using Cairo;

namespace Wiz {
  /* Each edge is a connetion in a certain direction, from the parent to the
   * child
   */
  public class TimelineEdge : Glib.Object {
    private Node parent { get; }
    private Node child { get; }

    public TimelineEdge(TimelineNode parent, TimelineNode child) {
      this.parent = parent;
      this.child = child;
    }
  }

  /* Each node has multiple edges, these edges connect the node to other nodes
   * the edges contain the direction of this connection. The node also stores
   * its position and size within the widget.
   */
  public class TimelineNode : CommitNode {
    public double size { get; set; }
    public int column { get; set; }
    public double position { get; set; }
    public List<Edge> edges { get; construct; }

    public TimelineNode (string version_uuid, int timestamp) {
      this.version_uuid = version_uuid;
      this.timestamp = timestamp;
      this.edges = new List<Edge>();
    }

    public AddChild(TimelineNode child) {
      // Should see if it already exists first
      this.edges.append(new TimelineEdge(this, child));
    }
    public AddParent(TimelineNode parent) {
      // Should see if it already exists first
      this.edges.append(new TimelineEdge(parent, this));
    }
  }

  public class Timeline : Gtk.Widget {
    private List<TimelineNode> nodes;
    private List<TimelineNode> tips;
    private TimelineNode primary_tip;
    private TimelineNode root;
    private Bit bit;
    private Store store;
    private CommitStore commit_store;
    private int default_width;
    private int default_height;
    public string selected_version_uuid { get; set; }
    public double zoom { get; set; }
    // Dag height/visibility calculated from zoom level
    public int offset { get; set; }
    private int dag_height;
    private int dag_width;
    private int visible_columns;
    private int total_columns;
    private int visible_height; // Should use allocation.height for this
                                // and recalculate when we get a configure event
    private int oldest_timestamp;
    private int youngest_timestamp;
    private int start_timestamp;
    private int end_timestamp;

    public string bit_uuid {
      get {
        return this.bit.uuid;
      }
      set {
        this.bit = this.store.open_bit(value);
        this.commit_store = this.bit.commits;
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

    public void update_from_store (start, end) {
      // Limit the load start/end to new ones and update the viewable start/end
      if (end > this.end_timestamp) {
        start = this.end_timestamp
        this.end_timestamp = end;
      }
      if (start < this.start_timestamp) {
        end = this.start_timestamp
        this.start_timestamp = start;
      }

      var commit_nodes = List<CommitNode>;
      var new_nodes = List<TimelineNode>;
      commit_nodes = this.commit_store.get_nodes(start, end);

      // We're always appending to the seen nodes but never taking away, this is 
      // because we don't want to continue reloading and unloading the nodes for
      // the life of the widget, and as we want to be a little nippy about it
      // we should keep things around ffr.

      // Loading the nodes from the commit store
      foreach (var commit_node in commit_nodes) {
        new_node = TimelineNode(commit_node.version_uuid, 
                                commit_node.timestamp)
        new_nodes.append(new_node);
        this.nodes.append(new_node);

        if (commit_node.timestamp > this.youngest_timestamp) {
          this.youngest_timestamp = commit_node.timestamp;
        }
        if (commit_node.timestamp < this.oldest_timestamp) {
          this.oldest_timestamp = commit_node.timestamp;
        }
        // Get the offscreen parents/children so we know which direction the
        // far edges land in, this is probably going to cause some duplicate
        // parents where branches occur, TODO prevent duplicates :/
        parents = this.commit_store.get_backwards(commit_node.version_uuid);
        foreach (parent in parents) {
          parent_node = this.commit_store.get_node(parent);
          if (parent_node.timestamp < this.start_timestamp) {
            new_node = TimelineNode(parent_node.version_uuid, 
                                    parent_node.timestamp)
            new_nodes.append(new_node);
            this.nodes.append(new_node);
            if (parent_node.timestamp > this.youngest_timestamp) {
              this.youngest_timestamp = parent_node.timestamp;
            }
          }
        }
        children = this.commit_store.get_forwards(commit_node.version_uuid);
        foreach (child in children) {
          child_node = this.commit_store.get_node(child);
          if (child_node.timestamp > this.end_timestamp) {
            new_node = TimelineNode(child_node.version_uuid, 
                                    child_node.timestamp)
            new_nodes.append(new_node);
            this.nodes.append(noew_node);
            if (child_node.timestamp < this.oldest_timestamp) {
              this.oldest_timestamp = child_node.timestamp;
            }
          }
        }
      }
      // Iterate the new nodes and add edges
      foreach (var node in new_nodes) {
        children = new List<string>;
        children = this.commit_store.get_forwards(node.version_uuid);
        // Unfortunately we've got to iterate this many times because
        // we need to tie up seen nodes by edges :/ At least we only have to
        // do it when the bit changes
        foreach (var child in children) {
          foreach (var child_node in this.nodes) {
            if (child_node.version_uuid == child) {
              node.AddChild(child_node);
            }
          }
        }
      }
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
                                             Gdk.EventMask.BUTTON_RELEASE_MASK |
                                             Gdk.EventMask.BUTTON_CLICK;
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

    // update_zoom
    /*
        has the start timestamp gotten earlier
            load all nodes from the old start timestamp to the new start
        has the end timestamp gotten later
            load all nodes from the old end timestamp to the new end and

        the zoom level is calculate from the newest commit timestamp to the root
        timestamp vs. what is currently on screen, the offset position is
        also calculated here, then the visibility of all nodes is updated and
        and queue draw is called for the whole widget :/
        it's not pretty...
    */

    //public override bool button_press_event?
    /*
        set mouse down
        this.press_co-ords = event.x event.y
        are we over the zoom widget
        create a press timestamp (milliseconds)
    */
    //public override bool button_release_event?
    /* 
        unset mouse down
        set click co-ords
        compare press/release co-ords
        create release timestamp (milliseconds)
        calculate the distance travelled in that time and therefore the speed
        start a timer which controls the speed/positioning (kinetic scroll)
     */ 
    //public override bool button_release_event?
    /* 
        unset mouse down
        set click co-ords
        did we click on a version
            highlight version and set selected 
     */
    //public override bool motion_notify_event?
    /* 
        if the button is down over the zoom widget
            have the x/y co-ords changed since button press
                update_zoom
        if the button is down elsewhere 
            pan widget to current co-ords
    */

    public override bool expose_event (Gdk.EventExpose event) {
      var cr = Gdk.cairo_create (this.window);
      var surface = cr.get_group_target();
      var cr_background_layer = Cairo.create(surface.create_similar());
      var cr_node_layer = Cairo.create(surface.create_similar());
      var cr_controls_layer = Cairo.create(surface.create_similar();
      // Set up some vars so we don't overload the cpu
      // Set double buffered
      foreach (var node in this.nodes) {
        foreach (var edge in node.edges) {
          // Render the edges onto the underneath surface
        }
        // Render the node onto the ontop surface
      }
      // composite surfaces together
      // Render the zoom/scroll widget
      return true;
    }
  }
}