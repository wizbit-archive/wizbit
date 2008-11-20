/**
 * $LGPL header$
 */

/**
 * TODO
 * 1. Create renderers for widget controls and the scale. Drawn needs to be 
 *    converted to cairo code
 * 2. Update signal handlers figure out the click zones, Control changes (zoom/scroll)
 * 3. Column calculations, this is pretty difficult, but just takes a little thinking about
 * 4. Signal emitted for selection changed
 * 5. Setting the selected node will scroll it to center
 * 6. Animations while timeline view changes, don't let zooming/panning
 *    be jumpy.
 * 7. Rename a bunch of things which are horribly named!
 * 8. Optimize the shizzle out of it! profile update_from_store especially
 * 9. use CIEXYZ colourspace for coloum colouring
 * For Future Release;
 * x. Kinetic scrolling - add timing/timer stuff into signal handlers
 * x. This TODO list is not upto date
 */

using GLib;
using Gtk;
using Cairo;

namespace Wiz {
  /* Each edge is a connetion in a certain direction, from the parent to the
   * child
   */
  public class TimelineEdge : Glib.Object {
    private TimelineNode parent { get; }
    private TimelineNode child { get; }
    private double r;
    private double g;
    private double b;

    public TimelineEdge(TimelineNode parent, TimelineNode child) {
      this.parent = parent;
      this.child = child;
    }
    public SetColor(double r, double g, double b) {
        this.r = r;
        this.g = g;
        this.b = b;
        // TODO Should also have a gradient fill, set up to blend the branching :/
        // shouldn't really have a function for set colour though as the colours
        // would be collected from the parent and child
    }
    public Render(CairoContext cr) {
        // Draw a line from each parent.x/y to child.x/y
        cr.move_to(parent.x, parent.y);
        cr.line_to(child.y, child.y);
        cr.set_source_rgb(this.r,this.g,this.b);
        cr.stroke();
    }
  }

  /* Each node has multiple edges, these edges connect the node to other nodes
   * the edges contain the direction of this connection. The node also stores
   * its position and size within the widget.
   */
  public class TimelineNode : CommitNode {
    public double size { get; set; }
    public bool visible { get; set }
    public bool root { get; set }
    public bool tip { get; set }
    public List<Edge> edges { get; construct; }
    public int x;
    public int y;
    // Colours! YAY
    private double lr;
    private double lg;
    private double lb;

    private double fr;
    private double fg;
    private double fb;

    public TimelineNode (string version_uuid, int timestamp) {
      this.version_uuid = version_uuid;
      this.timestamp = timestamp;
      this.edges = new List<TimelineEdge>();
    }

    public AddChild(TimelineNode child) {
      this.edges.append(new TimelineEdge(this, child));
    }

    public RenderNode(CairoContext cr) {
        if (!this.visible)
            return
        // Render a cirle to cr at x/y position of this.size
        cr.arc(this.x, this.y, this.size, 0, 2*M_PI);//?
        cr.set_source_rgb(this.fr,this.fg,this.fb);
        cr.fill_preserve()
        cr.set_source_rgb(this.lr,this.lg,this.lb);
        cr.stroke();
    }

    public SetPosition( Timeline timeline, double position, int column, int size ) {
        if (!this.visible)
            return;
        // Some of these will be private
        var dag_width = timeline.dag_width;
        var dag_height = timeline.dag_height;
        var offset = timeline.offset;
        var total_columns = timeline.total_columns;
        // this probably has a few off by one errors :/ 
        this.x = (graph_width / total_columns) * column;
        this.y = (dag_height * position) - offset;

        var hue = (column / total_columns);
        // Made up values ;/
        var sat = 0.5;
        var val = 0.3;
        // Convert to rgb for fill fr,fg,fb
        var val = 0.1;
        // Convert to rgb for line lr,lg,lb
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
    // Event handling, kinetic scrolling properties
    private bool mouse_down;
    private int button_press_timestamp;
    private int button_release_timestamp;
    private int mouse_press_x;
    private int mouse_press_y;
    private int mouse_release_x;
    private int mouse_release_y;
    private double velocity;
    // Dag height/visibility calculated from zoom level
    private int dag_height;
    private int dag_width;
    private int visible_columns;
    private int total_columns;
    private int oldest_timestamp;
    private int newest_timestamp;
    private int start_timestamp;
    private int end_timestamp;
    public int offset { get; set; }
    public string selected_version_uuid { get; set; }
    public double zoom { get; set; }

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
      this.mouse_down = false;
    }

    construct {
      this.tips = new List<TimelineNode>();
      this.update_from_store();
      this.default_width = 80;
      this.default_height = 160;
    }

    public void update_from_store () {
      this.nodes = this.commit_store.get_nodes();
      // Iterate the new nodes and add edges
      string root = this.commit_store.get_root();
      string primary_tip = this.commit_store.get_primary_tip();
      var tips = this.commit_store.get_tips();
      // Try and save a few iterations of the nodes by doing the edges during
      // the first tip cycle, its not pretty but it works
      bool edges_done = false;
      bool child_found;
      foreach (var tip in tips) {
        foreach (var node in this.nodes) {
          if (tip == node.version_uuid) {
            this.tips.append(node);
          }
          if (!edges_done) {
            var children = this.commit_store.get_forwards(node.version_uuid);
            if (node.version_uuid == root) {
              this.root = node;
            }
            if (node.version_uuid == primary_tip) {
              this.primary_tip = node;
            }
            // Unfortunately we've got to iterate this many times because
            // we need to tie up seen nodes by edges :/ At least we only have to
            // do it when the bit changes
            foreach (var child in children) {
              foreach (var child_node in this.nodes) {
                if (child_node.version_uuid == child) {
                  node.AddChild(child_node);
                  break;
                }
              }
            }
            if (node.timestamp > this.newest_timestamp) {
              this.newest_timestamp = commit_node.timestamp;
            }
            if (node.timestamp < this.oldest_timestamp) {
              this.oldest_timestamp = commit_node.timestamp;
            }
          }
        }
        edges_done = true;
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

    private void update_zoom() {
      var range = this.end_timestamp - this.start_timestamp;
      var total = this.newest_timestamp - this.oldest_timestamp;
      this.zoom = range/total;
      this.dag_height = this.allocation.height * (total/range)
      this.offset = this.dag_height * (self.start_timestamp/total);
      this.update_visibility();
      this.queue_draw();//?
    }

    // This has to be done on pan/zoom so that's a lot of events :/
    private void update_visibility() {
        size = 8;
        var parents = new List<string>();
        foreach (node in this.nodes) {
            if ((node.timestamp <= this.end_timestamp) && (node.timestamp >= this.start_timestamp) {
                node.visible = true;
                var parents = node.edges;
                foreach (var parent in parents) {
                    if (parent.child.version_uuid == node.version_uuid) {
                    // TODO if distance is less than the radius of the node,
                    // set visibility of parent to false and increase radius
                    // we know our timestamps in nodes are oldest first so we 
                    // won't overwrite it
                    }
                }
            } else {
                node.visible = false;
            }
            // TODO Calculate column, this is pretty anoying, we need to increment
            // every time we have a new branch :/ That means iterating forwards
            node.SetPosition(this, (node.timestamp - this.oldest_timestamp) / this.newest_timestamp, column, size)
        }
    }

    public override bool button_press_event (Gdk.EventButton event) {
        this.mouse_down = true;
        this.mouse_press_x = event.x;
        this.mouse_press_y = event.y;
    /*
        are we over the zoom widget
        // TODO FFR - This is for kinetic scrolling
        // create a press timestamp (milliseconds) argh, vala time!!!!!
        // this.button_press_timestamp = ?
    */
        return true;
    }

    public override bool button_release_event (Gdk.EventButton event) {
        this.mouse_down = false;
        this.mouse_release_x = event.x;
        this.mouse_release_y = event.y;
    /*  TODO
        are we over the controls?
            compute the change in the controls
        else
            // TODO FFR - This is for kinetic scrolling
            // create release timestamp (milliseconds)
            // this.button_release_timestamp = ?
            // calculate the distance travelled in that time and therefore the speed
            // start a timer which controls the speed/positioning (kinetic scroll)
            // horizontal scrolling will change the zoom level
     */
        return true;
    }

    public override bool button_click_event (Gdk.EventButton event) {
        this.mouse_down = false;
    /*  TODO - we have to iterate over the widgets and check the polar distance
        not hard, but yet another iteration, thankfully we only need to do it on
        click and not on motion :) We can speed this up by ignoring invisible 
        nodes.
        did we click on a version
            set selected - emit selection changed signal
            this.queue_draw(); 
     */
        return true;
    }

    public override bool motion_notify_event (Gdk.EventMotion event) {
    /*  TODO
        if the button is down over the zoom widget
            have the x/y co-ords changed since button press
                set handle positions
                update_zoom
        if the button is down elsewhere 
            pan widget to current co-ords
        else
            return false;
        this.queue_draw();
        return true;
    */
    }

    /* Converts a timestamp into a scale horizontal position. */
    private int TimestampToHScalePos(int timestamp) {

    }
    /* Get the integer of the month for a timestamp */
    private int TimestampToMonth(int timestamp) {

    }
    /* Get the timestamp of a specific d/m/y */
    private int DateToTimestamp(int d, int m, int y) {

    }

    // TODO
    public void RenderScale(CairoContext cr) {

    }

    public void RenderHandle(CairoContext cr, int timestamp) {
        // 4.5
    }
    // TODO
    // work out the colours
    public void RenderControls(CairoContext cr) {
        // Render background
        cr.rectangle(14.5, this.allocation.height - 37.5,
                           this.allocation.width - 14.5,
                           this.allocation.height - 31.5);
        pattern = Pattern.linear(0,0,0,6);
        pattern.add_stop_rgb(0, 0x88/255.0, 0x8a/255.0, 0x85/255.0);
        pattern.add_stop_rgb(1, 0xee/255.0, 0xee/255.0, 0xec/255.0);
        cr.set_source (pattern);
        cr.fill_preserve()
        cr.set_source_rgb(0x55/255.0, 0x57/255.0, 0x53/255.0);
        cr.stroke();

        // Render slider
        cr.rectangle (this.TimestampToHScalePos(this.start_timestamp) + 4.5,
                      this.allocation.height - 39.5,
                      this.TimestampToHScalePos(this.end_timestamo) + 4.5, 
                      this.allocation.height - 30.5);
        pattern = Pattern.linear(0,0,0,9);
        pattern.add_stop_rgb(0, 0x72/255.0,0x9f/255.0,0xcf/255.0);
        pattern.add_stop_rgb(1, 0x34/255.0,0x65/255.0,0xa4/255.0);
        cr.set_source (pattern);
        cr.fill_preserve();
        cr.set_source_rgb(0x20/255.0,0x4a/255.0,0x87/255.0);
        // Render some ticks in the middle of the slider
        var pos = this.TimestampToHScalePos(this.start_timestamp) + ((this.end_timestamp - this.start_timestamp)/2.0) - 9; 
        for (var i = ??; i < ??; i + 3) {
          cr.move_to(pos, this.allocation.height - 37.5);
          cr.line_to(pos, this.allocation.height - 32.5);
          pos = pos + 3;
        }
        cr.stroke();
        // Slider Highlight
        cr.set_source_rgba(0xff/255.0,0xff/255.0,0xff/255.0, 20/100.0);
        cr.rectangle (this.TimestampToHScalePos(this.start_timestamp) + 5.5, 
                      this.allocation.height - 38.5,
                      this.TimestampToHScalePos(this.end_timestamo) + 5.5, 
                      this.allocation.height - 31.5);
        cr.stroke();

        this.RenderHandle(cr, this.start_timestamp);
        this.RenderHandle(cr, this.end_timestamp);
    }

    public override bool expose_event (Gdk.EventExpose event) {
      var cr = Gdk.cairo_create (this.window);
      var surface = cr.get_group_target();
      var cr_background_layer = Cairo.create(surface.create_similar());
      var cr_foreground_layer = Cairo.create(surface.create_similar());
      this.set_double_buffered(true);

      this.RenderScale(cr);
      foreach (var node in this.nodes) {
        foreach (var edge in node.edges) {
          // Render the edges onto the underneath surface
          edge.Render(cr_background_layer);
        }
        // Render the node onto the ontop surface
        node.Render(cr_foreground_layer);
      }

      // composite surfaces together
      // Hopefully FILTER_NEAREST is being set internally by now, if not this
      // is likely to be slow. To work around that we'd have to rework the
      // rendering order to be able to render the edges under the nodes, that
      // would mean that we'd have to iterate the nodes again after the edges.
      cr.set_source_surface(cr_background_layer.get_group_target(), 0, 0);
      cr.paint();
      cr.set_source_surface(cr_foreground_layer.get_group_target(), 0, 0);
      cr.paint();
      this.RenderControls(cr);
      return true;
    }
  }
}
