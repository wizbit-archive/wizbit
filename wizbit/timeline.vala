/**
 * $LGPL header$
 */

/**
 * TODO
 * 1. Create renderers for ~widget controls~ and the scale. Drawn needs to be 
 *    converted to cairo code
 * 2. ~Get it building~ and fix any rounding/off by one errors in the maths
 * 3. Column calculations, this is pretty difficult, but just takes a little thinking about
 * ~4. Signal emitted for selection changed~
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
  public class TimelineEdge : GLib.Object {
    public TimelineNode parent;
    public TimelineNode child;
    private double r;
    private double g;
    private double b;

    public TimelineEdge(TimelineNode parent, TimelineNode child) {
      this.parent = parent;
      this.child = child;
    }

    public void SetColor(double r, double g, double b) {
      this.r = r;
      this.g = g;
      this.b = b;
      // TODO Should also have a gradient fill, set up to blend the branching :/
      // shouldn't really have a function for set colour though as the colours
      // would be collected from the parent and child
    }
    public void Render(Cairo.Context cr) {
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
  public class TimelineNode : GLib.Object {
    public double size { get; set; }
    public bool visible { get; set; }
    public bool root { get; set; }
    public bool tip { get; set; }
    public weak List<TimelineEdge> edges { get; construct; }
    public int x;
    public int y;
    public string version_uuid;
    public int timestamp;
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

    construct {
      this.edges = new List<TimelineEdge>();
    }

    public void AddChild(TimelineNode child) {
      this.edges.append(new TimelineEdge(this, child));
    }

    public void Render(Cairo.Context cr) {
      if (!this.visible)
        return;
      // Render a cirle to cr at x/y position of this.size
      cr.arc(this.x, this.y, this.size, 0, 2.0 * Math.PI);
      cr.set_source_rgb(this.fr,this.fg,this.fb);
      cr.fill_preserve();
      cr.set_source_rgb(this.lr,this.lg,this.lb);
      cr.stroke();
    }

    public void SetPosition( Timeline timeline, double position, int column, int size ) {
      if (!this.visible)
        return;
        // Some of these will be private
      var dag_width = timeline.dag_width;
      var dag_height = timeline.dag_height;
      var offset = timeline.offset;
      var total_columns = timeline.total_columns;
      var graph_width = timeline.get_allocation_width();
      // this probably has a few off by one errors :/ 
      this.x = (graph_width / total_columns) * column;
      this.y = (int)((double)dag_height * position) - offset;

      var hue = (column / total_columns);
      // Made up values ;/
      var sat = 0.5;
      var val = 0.3;
      // Convert to rgb for fill fr,fg,fb
      val = 0.1;
      // Convert to rgb for line lr,lg,lb
    }
  }

  public class Timeline : Gtk.Widget {
    private List<TimelineNode> nodes;
    private List<TimelineNode> tips;
    private TimelineNode primary_tip;
    private TimelineNode root;
    private Bit bit = null;
    private Store store = null;
    private CommitStore commit_store = null;
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
    public int dag_height;
    public int dag_width;
    private int visible_columns;
    public int total_columns;
    private int oldest_timestamp;
    private int newest_timestamp;
    private int start_timestamp;
    private int end_timestamp;
    public int offset { get; set; }
    public string selected_version_uuid { get; set; }
    public double zoom { get; set; }
    private int handle_grabbed;
    private int grab_offset;

    public string bit_uuid {
      get {
        return this.bit.uuid;
      }
      set {
        if (value != null) {
            this.bit = this.store.open_bit(value);
            assert(this.bit.commits != null);
            this.commit_store = this.bit.commits;
            assert(this.commit_store != null);
        }
      }
    }

    public signal void selection_changed ();

    // We can construct with no bit specified, and use bit_uuid to open the bit
    public Timeline(Store store, string? bit_uuid) {
      this.store = store;
      stdout.printf("Bit UUID: %s\n", bit_uuid);
      this.bit_uuid = bit_uuid;
      this.tips = new List<TimelineNode>();
      this.mouse_down = false;
      this.default_width = 250;
      this.default_height = 400;
      this.update_from_store();
    }

    // FIXME this is dumb, maybe I should just move setposition/render into Timeline from TimelineNode
    public int get_allocation_width() {
        return this.allocation.width;
    }

    public void update_from_store () {
      stdout.printf("Updating the timeline from the bit store\n");
      assert(this.commit_store != null);
      this.nodes = this.commit_store.get_nodes();
      // Iterate the new nodes and add edges
      string root = this.commit_store.get_root();
      string primary_tip = this.commit_store.get_primary_tip();
      var tips = this.commit_store.get_tips();
      // Try and save a few iterations of the nodes by doing the edges during
      // the first tip cycle, its not pretty but it works
      bool edges_done = false;
      foreach (var tip in tips) {
        stdout.printf("Iterating tip %s\n", tip);
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
          }
        }
        edges_done = true;
      }
      this.newest_timestamp = this.primary_tip.timestamp;
      this.oldest_timestamp = this.root.timestamp;
      stdout.printf("Oldest: %d\n", this.oldest_timestamp);
      stdout.printf("Newest: %d\n", this.newest_timestamp);
      this.start_timestamp = this.oldest_timestamp;
      this.end_timestamp = this.newest_timestamp;
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

    public override void size_request (out Gtk.Requisition requisition) {
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
      this.dag_height = this.allocation.height * (total/range);
      this.offset = this.dag_height * (this.start_timestamp/total);
    }

    // This has to be done on pan/zoom so that's a lot of events :/
    private void update_visibility() {
      var size = 8;
      var parents = new List<string>();
      var column = 0;
      foreach (var node in this.nodes) {
        if ((node.timestamp <= this.end_timestamp) && (node.timestamp >= this.start_timestamp)) {
          node.visible = true;
          foreach (var parent in node.edges) {
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
        //node.SetPosition(this, (node.timestamp - this.oldest_timestamp) / this.newest_timestamp, column, size);
      }
    }
    /*
     * Update the timestamp's from where the position controls are.
     *
     */
    public void update_controls(int x) {
      if (this.handle_grabbed < 1) {
        return; // You don't have to go home but you can't stay here
      } else {
        var xpos = x - this.grab_offset;

        if (this.handle_grabbed == 1) {
          this.start_timestamp = this.HScalePosToTimestamp(xpos);
        } else if (this.handle_grabbed == 2) {
          this.end_timestamp = this.HScalePosToTimestamp(xpos);
        } else if (this.handle_grabbed == 3) {
          var click_timestamp = this.HScalePosToTimestamp(xpos);
          var half_time = (this.end_timestamp - this.start_timestamp)/2; 
          this.start_timestamp = click_timestamp - half_time;
          this.end_timestamp = click_timestamp + half_time;
        }
      }
    }

    public override bool button_press_event (Gdk.EventButton event) {
      this.mouse_down = true;
      this.mouse_press_x = (int)event.x;
      this.mouse_press_y = (int)event.y;
      var st = this.TimestampToHScalePos(this.start_timestamp);
      var et = this.TimestampToHScalePos(this.end_timestamp);
      var sv = this.allocation.height - 40;
      var ev = this.allocation.height - 26;
      stdout.printf("%d, %d : %d, %d : %d, %d\n", this.mouse_press_x, this.mouse_press_y, st, et, sv, ev);

      if (this.mouse_press_y > sv &&
          this.mouse_press_y < ev &&
          this.mouse_press_x >= st &&
          this.mouse_press_x <= et ) {
        // figure out which part of the control we're over
        if (this.mouse_press_x > st - 4.5 &&
            this.mouse_press_x < st + 4.5) {
          // Over left handle
          this.handle_grabbed = 1;
          this.grab_offset = (int)event.x - st;
          stdout.printf("left handle grabbed\n");
        } else if (this.mouse_press_x > et - 4.5 &&
                   this.mouse_press_x < et + 4.5) {
          // Over right handle    
          this.handle_grabbed = 2;            
          this.grab_offset = (int)event.x - et;
          stdout.printf("right handle grabbed\n");
        } else {
          // Over the slider bar
          this.handle_grabbed = 3;
          this.grab_offset = (int)event.x - ((et - st)/2) + st;
          stdout.printf("center handle grabbed\n");
        }
      } else {
        this.handle_grabbed = 0;
      }

      // TODO FFR - This is for kinetic scrolling
      // create a press timestamp (milliseconds) argh, vala time!!!!!
      // this.button_press_timestamp = ?
      return true;
    }

    public override bool button_release_event (Gdk.EventButton event) {
      this.mouse_down = false;
      this.mouse_release_x = (int)event.x;
      this.mouse_release_y = (int)event.y;
      if (this.handle_grabbed > 0) {
        this.update_controls(this.mouse_release_x);
        this.update_zoom();
        this.update_visibility();
        this.queue_draw();
      } // else if Gtk.drag_check_threshold.... {
        // TODO - we have to iterate over the nodes and check the polar distance
        // not hard, but yet another iteration, thankfully we only need to do it on
        // click and not on motion :) We can speed this up by ignoring invisible 
        // nodes.
        // did we click on a version
        //   set selected - emit selection changed signal
        //   this.selection_changed();
        //   this.queue_draw(); 
        // } else {
        // TODO FFR - This is for kinetic scrolling
        // create release timestamp (milliseconds)
        // this.button_release_timestamp = ?
        // calculate the distance travelled in that time and therefore the speed
        // start a timer which controls the speed/positioning (kinetic scroll)
        // horizontal scrolling will change the zoom level
      this.handle_grabbed = 0;
      return true;
    }

    public override bool motion_notify_event (Gdk.EventMotion event) {
      if (this.mouse_down && this.handle_grabbed > 0) {
        if (event.x != this.mouse_press_x) {
          this.update_controls((int)event.x);
          this.update_zoom();
          this.queue_draw();
        }
        return true;
      }

      // TODO This is really FFR part of kinetic scrolling
      // if the button is down elsewhere 
      //    pan widget to current co-ords
      return false;
    }

    /* Converts a timestamp into a scale horizontal position. */
    private int TimestampToHScalePos(int timestamp) {
      var range = this.newest_timestamp - this.oldest_timestamp;
      double pos = ((double)timestamp - (double)this.oldest_timestamp) / (double)range; // unsure of vala casting?
      return (int)Math.ceil((pos * ((double)this.allocation.width - 29.0)) + 14.5); 
    }
    private int HScalePosToTimestamp(int xpos) {
      double ratio = (xpos - 14.5) / (this.allocation.width - 29.0);
      return (int)Math.ceil(((this.newest_timestamp - this.oldest_timestamp) * ratio) + this.oldest_timestamp);
    }
    /* Get the integer of the month for a timestamp */
    private int TimestampToMonth(int timestamp) {
      // Vala time... PLEASE GIMME DOCS!!!!!!!!
      return 0;
    }
    /* Get the timestamp of a specific d/m/y */
    private int DateToTimestamp(int d, int m, int y) {
      return 0;
    }

    // TODO
    public void RenderScale(Cairo.Context cr) {
    }

    public void RenderHandle(Cairo.Context cr, int timestamp) {
      var hpos = this.TimestampToHScalePos(timestamp);
      cr.move_to(hpos - 3.5, this.allocation.height - 39.5);
      cr.line_to(hpos - 3.5, this.allocation.height - 30.5);
      cr.line_to(hpos, this.allocation.height - 26.5);
      cr.line_to(hpos + 3.5, this.allocation.height - 30.5);
      cr.line_to(hpos + 3.5, this.allocation.height - 39.5);
      cr.line_to(hpos - 3.5, this.allocation.height - 39.5);
      var pattern = new Cairo.Pattern.linear(hpos - 3.5, 0, hpos + 3.5,0);
      pattern.add_color_stop_rgb(0, 0xee/255.0, 0xee/255.0, 0xec/255.0); 
      pattern.add_color_stop_rgb(1, 0x88/255.0, 0x8a/255.0, 0x85/255.0);
      cr.set_source (pattern);
      cr.fill_preserve();
      cr.set_source_rgb(0x55/255.0, 0x57/255.0, 0x53/255.0);
      cr.stroke();

      cr.set_source_rgba(0xff/255.0,0xff/255.0,0xff/255.0, 20/100.0);
      cr.move_to(hpos - 2.5, this.allocation.height - 38.5);
      cr.line_to(hpos - 2.5, this.allocation.height - 30.85);
      cr.line_to(hpos, this.allocation.height - 28.0);
      cr.line_to(hpos + 2.5, this.allocation.height - 30.85);
      cr.line_to(hpos + 2.5, this.allocation.height - 38.5);
      cr.line_to(hpos - 2.5, this.allocation.height - 38.5);
      cr.stroke();
    }

    public void RenderControls(Cairo.Context cr) {
      int start_pos = this.TimestampToHScalePos(this.start_timestamp);
      int end_pos = this.TimestampToHScalePos(this.end_timestamp);
      // Render background
      cr.rectangle(14.5, this.allocation.height - 37.5,
                   this.allocation.width - 29.0, 6.0);
      var pattern = new Cairo.Pattern.linear(0, this.allocation.height - 37.5, 0, this.allocation.height - 31.5);
      pattern.add_color_stop_rgb(0, 0x88/255.0, 0x8a/255.0, 0x85/255.0);
      pattern.add_color_stop_rgb(1, 0xee/255.0, 0xee/255.0, 0xec/255.0);
      cr.set_line_width(1);
      cr.set_source (pattern);
      cr.fill_preserve();
      cr.set_source_rgb(0x55/255.0, 0x57/255.0, 0x53/255.0);
      cr.stroke();

      stdout.printf("s %d\n", start_pos);
      stdout.printf("e %d\n", end_pos);
      // Render slider
      cr.rectangle (start_pos + 3.5, this.allocation.height - 39.5,
                    end_pos - start_pos - 7, 9);
      pattern = new Cairo.Pattern.linear(0, this.allocation.height - 39.5, 
                                         0,this.allocation.height - 30.5);
      pattern.add_color_stop_rgb(0, 0x72/255.0,0x9f/255.0,0xcf/255.0);
      pattern.add_color_stop_rgb(1, 0x34/255.0,0x65/255.0,0xa4/255.0);
      cr.set_source (pattern);
      cr.fill_preserve();
      cr.set_source_rgb(0x20/255.0,0x4a/255.0,0x87/255.0);
      // Render some ticks in the middle of the slider
      var pos = this.TimestampToHScalePos(this.start_timestamp + ((this.end_timestamp - this.start_timestamp)/2)) - 3.5; 
      for (var i = 0; i < 3; i++) {
        cr.move_to(pos + (i * 3), this.allocation.height - 37.5);
        cr.line_to(pos + (i * 3), this.allocation.height - 32.5);
      }
      cr.stroke();
      // Slider Highlight
      cr.set_source_rgba(0xff/255.0,0xff/255.0,0xff/255.0, 20/100.0);
      cr.rectangle (start_pos + 4.5, this.allocation.height - 38.5,
                    end_pos - start_pos - 9, 7);
      cr.stroke();

      this.RenderHandle(cr, this.start_timestamp);
      this.RenderHandle(cr, this.end_timestamp);
    }

    public override bool expose_event (Gdk.EventExpose event) {
      var cr = Gdk.cairo_create (this.window);
      //var surface = cr.get_group_target();
      //var cr_background_layer = new Cairo.Context(new Cairo.Surface.similar(surface, Cairo.Content.COLOR_ALPHA, this.allocation.width, this.allocation.height));
      //var cr_foreground_layer = new Cairo.Context(new Cairo.Surface.similar(surface, Cairo.Content.COLOR_ALPHA, this.allocation.width, this.allocation.height));
      this.set_double_buffered(true);

      //this.RenderScale(cr);
      foreach (var node in this.nodes) {
        foreach (var edge in node.edges) {
          // Render the edges onto the underneath surface
          //edge.Render(cr_background_layer);
          stdout.printf("Rendering edge between %s and %s\n", edge.parent.version_uuid, edge.child.version_uuid);
        }
        // Render the node onto the ontop surface
        //node.Render(cr);
        stdout.printf("Rendering node %s\n", node.version_uuid);
      }

      // composite surfaces together
      // Hopefully FILTER_NEAREST is being set internally by now, if not this
      // is likely to be slow. To work around that we'd have to rework the
      // rendering order to be able to render the edges under the nodes, that
      // would mean that we'd have to iterate the nodes again after the edges.
      //cr.set_source_surface(cr_background_layer.get_group_target(), 0, 0);
      //cr.paint();
      //cr.set_source_surface(cr_foreground_layer.get_group_target(), 0, 0);
      //cr.paint();
      this.RenderControls(cr);
      return true;
    }
  }
}
