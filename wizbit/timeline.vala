/**
 * $LGPL header$
 */

/**
 * TODO
 * 1.  Create renderer for the scale.
 * 2.  Setting the selected node will scroll it to center
 * 3.  Animations while timeline view changes, don't let zooming/panning
 *     be jumpy. Branches can slide and fade...
 * 4.  Rename a bunch of things which are horribly named!
 *     node_type -> ?
 * 5.  Fix column positioning it's not centered properly...
 * 6.  work out the horizontal/vertical positioning stuff
 * 7.  Clean up some of the calculations
 * 8.  Make sure the primary tip and root aren't hanging around at the edge
 * 9.  Work out the node globbing (nodes close to each other combind and size increases)
 * 10. Fix hugging bug for negative columns
 * 11. Node click zones calculations
 * 12. Maximum angle acuteness for branch angles. 
 * 13. Separate from the database properly
 * 14. Merge update_from_store and update_branches simplifies graph loading
 * 15. Separate from the database fudgeness, create a cleaner separation
 * 16. Optimize the shizzle out of it! profile update_from_store especially
 *     update_from_store and update_columns could conceivably be integratied into
 *     a single routine. 
 * 17. use CIEXYZ colourspace for branch colouring
 * 18. Create the gradient blend for the column edges.
 * For Future Release;
 * x. Kinetic scrolling - add timing/timer stuff into signal handlers
 * x. This TODO list is not upto date
 */

using GLib;
using Gtk;
using Cairo;

namespace Wiz {
  public enum TimelineProperties {
    HORIZONTAL = 0,
    VERTICAL = 1,
    PADDING = 14,
    SCALE_INDENT = 60
  }
  public enum TimelineHandle {
    NONE = 0,
    LIMIT_OLD = 1,
    SLIDER = 2,
    LIMIT_NEW = 3,
    WIDTH = 9,
    HEIGHT = 13,
    INDENT = 14
  }

  public enum TimelineNodeType {
    NORMAL,
    ROOT,
    PRIMARY_TIP,
    TIP
  }

  // A class for animated branchess
  public class TimelineBranch : GLib.Object {
    public int position;             // The position of this branch
    public double opacity;           // The current opacity
    public int offset;               // The current offset position
    public bool visible;             // Visibility of this branch
    public List<TimelineNode> nodes; // All the nodes that belong to this branch
    public int oldest = 0;
    public int newest = 0;
    public TimelineBranch parent = null;
    public int px_position = 0;      // This branches pixel position: x or y

    public double stroke_r;
    public double stroke_g = 0.0;
    public double stroke_b = 0.0;

    public double fill_r;
    public double fill_g = 0.0;
    public double fill_b = 0.0;

    public TimelineBranch(TimelineBranch? parent) {
      this.stroke_r = 0xa4/255.0;
      this.fill_r = 0xcc/255.0;
      this.parent = parent;
      this.nodes = new List<TimelineNode>();
      this.position = 0;
    }

    public void SlideOut() {
    }
    public void SlideIn() {
    }
    public void FadeOut() {
    }
    public void FadeIn() {
    }

    public void Hide() {
    }
    public void Show() {
    }

    /* Figure out if we're hiding or showing dependent on the state of the nodes
     * This is called on all branchs on a button release event, causing the 
     * branchs to re-organise on screen.
     > FIXME This function must work in time with the overall zooming in/out
     > which occurs after a button release event.
     */
    public void Animate() {
      foreach (var node in this.nodes) {
        if ((node.visible == true) && (this.visible == false)) {
          this.Show();
          return;
        }
      }
      if (this.visible == true) {
          this.Hide();
      }
    }
  }

  /* Each edge is a connetion in a certain direction, from the parent to the
   * child
   */
  public class TimelineEdge : GLib.Object {
    public TimelineNode parent;
    public TimelineNode child;

    public TimelineEdge(TimelineNode parent, TimelineNode child) {
      this.parent = parent;
      this.child = child;
    }

    public void Render(Cairo.Context cr) {
      // Draw a line from each parent.x/y to child.x/y
      int x = parent.branch.px_position;
      int y = parent.px_position;
      cr.move_to(x, y);

      x = child.branch.px_position;
      y = child.px_position;      
      cr.line_to(x, y);      
      cr.set_source_rgb(child.branch.stroke_r, 
                        child.branch.stroke_g,
                        child.branch.stroke_b);
      cr.stroke();
    }
  }

  /* Each node has multiple edges, these edges connect the node to other nodes
   * the edges contain the direction of this connection. The node also stores
   * its position and size within the widget.
   */
  public class TimelineNode : GLib.Object {
    private TimelineBranch t_branch = null;
    public bool visible { get; set; }
    public int node_type { get; set; }
    public int px_position;
    public int size;
    public string uuid;
    public int timestamp;

    // Might not be best to make this weak
    public weak List<TimelineEdge> edges { get; construct; }

    public TimelineBranch branch {
      get {
        return this.t_branch;
      }
      set {
        if (this.t_branch != null) {
          this.t_branch.nodes.remove(this);
        }
        this.t_branch = value;
        if (this.t_branch != null) {
          this.t_branch.nodes.append(this);
          if ((this.timestamp < this.t_branch.oldest) || 
              (this.t_branch.oldest == 0)) {
            this.t_branch.oldest = this.timestamp;
          }
          if ((this.timestamp > this.t_branch.newest) || 
              (this.t_branch.newest == 0)) {
            this.t_branch.newest = this.timestamp;
          }
        }
      }
    }

    public TimelineNode (string uuid, int timestamp) {
      this.uuid = uuid;
      this.timestamp = timestamp;
      this.edges = new List<TimelineEdge>();
      this.size = 15;
    }

    public void AddEdge(TimelineNode node) {
      this.AddChild(node);
      node.AddParent(this);
    }

    public void AddChild(TimelineNode node) {
      this.edges.append(new TimelineEdge(this, node));
    }

    public void AddParent(TimelineNode node) {
      this.edges.append(new TimelineEdge(node, this));
    }
    public void Render(Cairo.Context cr) {
      int x = this.branch.px_position;
      int y = this.px_position;
      cr.arc(x, y, this.size, 0, 2.0 * Math.PI);
      cr.set_source_rgb(this.branch.fill_r, 
                        this.branch.fill_g,
                        this.branch.fill_b);
      cr.fill_preserve();
      cr.set_source_rgb(this.branch.stroke_r, 
                        this.branch.stroke_g,
                        this.branch.stroke_b);
      cr.stroke();
    }
  }

  public class Timeline : Gtk.Widget {
    private Bit bit = null;
    private Store store = null;
    private CommitStore commit_store = null;

    // The dag itself
    private TimelineNode primary_tip = null;
    private TimelineNode root = null;
    private TimelineNode selected = null;
    private List<TimelineNode> nodes;
    private List<TimelineNode> tips;
    private List<TimelineBranch> branches;
    private int lowest_branch_position;
    private int highest_branch_position;

    // Scale ranges 
    private int oldest_timestamp;
    private int newest_timestamp;
    private int start_timestamp;
    private int end_timestamp;

    // Mouse handling
    private bool mouse_down;
    private int button_press_timestamp;
    private int button_release_timestamp;
    private int mouse_press_x;
    private int mouse_press_y;
    private int mouse_release_x;
    private int mouse_release_y;
    // FFR kinetic scrolling
    private double velocity;

    // Grabbed information for the controls
    private int grab_handle;
    private int grab_offset;

    // Drawing information, what's our currentt zoom level and offset from
    // the start of the timeline
    public int offset { get; set; }
    public double zoom { get; set; }

    // Orientation of the timeline and controls
    // FIXME each should be independent
    public bool orientation_timeline = TimelineProperties.VERTICAL;
    public bool orientation_controls = TimelineProperties.HORIZONTAL;

    // The size of the graph, we exclude the padding and position occupied by  
    // the controls.
    // FIXME this.orientation_*    
    public int graph_height {
      get {
        return this.widget_height - (int)TimelineProperties.SCALE_INDENT;
      }
    }
    public int graph_width {
      get {
        return this.widget_width;
      }
    }

    // Pixel width of an individual branch
    // FIXME this.orientation_* 
    public int branch_width {
      get {
        int rows = this.highest_branch_position - this.lowest_branch_position + 1;
        return this.graph_width / rows; 
      }
    }

    // Size of the allocation 
    public int widget_width {
      get {
        return this.allocation.width - ((2 * (int)TimelineProperties.PADDING) + 1);
      }
    }
    public int widget_height {
      get {
        return this.allocation.height - ((2 * (int)TimelineProperties.PADDING) + 1);
      }
    }

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
      stdout.printf("Bit UUID: %s\n", bit_uuid);
      this.store = store;
      this.bit_uuid = bit_uuid;
      this.tips = new List<TimelineNode>();
      this.branches = new List<TimelineBranch>();
      this.mouse_down = false;
      this.lowest_branch_position = 0;
      this.update_from_store();
    }

    public override void size_request (out Gtk.Requisition requisition) {
      requisition.width = 250;
      requisition.height = 400;
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

    // GRAPH HANDLING :S
    public void update_from_store () {
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
        foreach (var node in this.nodes) {
          if ((node.uuid == primary_tip) && (this.primary_tip == null)) {
            this.primary_tip = node;
            node.node_type = TimelineNodeType.PRIMARY_TIP;  
          } else if (node.uuid == tip) {
            this.tips.append(node);
            node.node_type = TimelineNodeType.TIP;
          } else if (!edges_done) {
            if (node.uuid == root) {
              this.root = node;
              node.node_type = TimelineNodeType.ROOT;
            } else {
              node.node_type = TimelineNodeType.NORMAL;
            }
            // Unfortunately we've got to iterate this many times because
            // we need to tie up seen nodes by edges :/ At least we only have to
            // do it when the bit changes
            var children = this.commit_store.get_forwards(node.uuid);
            foreach (var child in children) {
              foreach (var child_node in this.nodes) {
                if (child_node.uuid == child) {
                  node.AddEdge(child_node);
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
      this.start_timestamp = this.oldest_timestamp;
      this.end_timestamp = this.newest_timestamp;

      this.update_branches();
    }

    private void update_branches () {
      string child_uuid = "";
      int i, j, d;
      TimelineNode node = this.primary_tip;
      TimelineEdge edge;
      TimelineBranch branch = new TimelineBranch(null);
      TimelineBranch branch_match;
      this.branches.append(branch);
      branch.position = 0;
 
      // Step backward over parents until we hit the root
      while (true) {
        if (node.edges.length() > 2) {
          for (i = 0; i < node.edges.length(); i++ ) {
            edge = node.edges.nth_data(i);
            if ((edge.child.uuid != child_uuid) &&
                (edge.parent == node)) { // Branch for every child too much
              this.recurse_children(edge.child, new TimelineBranch(branch));
            }
          }
        }
        child_uuid = node.uuid;
        node.branch = branch;
        if (node == this.root) {
          break;
        }
        for (i = 0; i < node.edges.length(); i++ ) {
          edge = node.edges.nth_data(i);
          if (edge.child == node) {
            node = edge.parent;
            break;
          }
        }
      }
      // Now that all the branches exist, and the reflogs of each tip assigned
      // to a branch. We can arrange the branches into the densest space.
      for (i = 1; i < this.branches.length(); i++ ) {
        d = 1;
        branch = this.branches.nth_data(i);
        for (j = 1; j < i; j++ ) {
          branch_match = this.branches.nth_data(j);
          /* HUGGING */ 
          if ((branch.oldest > branch_match.newest) ||
              (branch.newest < branch_match.oldest)) {
            branch.position = branch_match.position;
          } else if (branch.oldest < branch_match.oldest) {
            branch.position = branch_match.position + 1;
          } else if (branch.oldest > branch_match.oldest) {
            // FIXME There'll be a bug in negatives here easy to fix though
            if ((branch_match.position + branch.position) > branch_match.position) {
              branch.position = branch.position * -1; 
            }
          } else {
            // This should never happen
            branch.position = branch_match.position * -1;
          }
        }
        if (branch.position == 0) {
          branch.position = d;
        } else if (branch.position < this.lowest_branch_position) {
          this.lowest_branch_position = branch.position;
        } else if (branch.position > this.highest_branch_position) {
          this.highest_branch_position = branch.position;
        }

      }
    }

    private void recurse_children (TimelineNode node, TimelineBranch branch) {
      TimelineEdge edge;
      int i, j;
      node.branch = branch;
      if (this.branches.index(branch) < 0) {
        this.branches.append(branch);
      }

      for (i = 0; i < node.edges.length(); i++ ) {
        // First child is on the same branch
        edge = node.edges.nth_data(i);
        if (edge.parent == node) {
          this.recurse_children(edge.child, branch);
          break;
        }
      }

      // All other children are on new branches
      for (j = (i+1); j < node.edges.length(); j++ ) {
        edge = node.edges.nth_data(j);
        if (edge.parent == node) {
          this.recurse_children(edge.child, new TimelineBranch(branch));
          break;
        }
      }
    }

    private void update_visibility() {/*
        if ((node.timestamp <= this.end_timestamp) && (node.timestamp >= this.start_timestamp)) {
          node.visible = true;
        } else {
          node.visible = false;
        }*/
    }

    /*
     * Update the timestamp's from where the position controls are.
     *
     */
    public void update_controls(int x) {
      if (this.grab_handle > (int)TimelineHandle.NONE) {
        var xpos = x - this.grab_offset;
        if (this.grab_handle == TimelineHandle.LIMIT_OLD) {
          this.start_timestamp = this.HScalePosToTimestamp(xpos);
        } else if (this.grab_handle == TimelineHandle.LIMIT_NEW) {
          this.end_timestamp = this.HScalePosToTimestamp(xpos);
        } else if (this.grab_handle == TimelineHandle.SLIDER) {
          var click_timestamp = this.HScalePosToTimestamp(xpos);
          var half_time = (this.end_timestamp - this.start_timestamp)/2;
          var tmp_s = click_timestamp - half_time;
          var tmp_e = click_timestamp + half_time;
          if ((tmp_s >= this.oldest_timestamp) && (tmp_e <= this.newest_timestamp)) {
            this.start_timestamp = tmp_s;
            this.end_timestamp = tmp_e;
          }
        }
        if (this.start_timestamp >= this.end_timestamp) {
          this.start_timestamp = this.end_timestamp - 1;
        }
        if (this.start_timestamp < this.oldest_timestamp) {
          this.start_timestamp = this.oldest_timestamp;
        }
        if (this.end_timestamp <= this.start_timestamp) {
          this.end_timestamp = this.start_timestamp + 1;
        }
        if (this.end_timestamp > this.newest_timestamp) {
          this.end_timestamp = this.newest_timestamp;
        }
      }
    }

    private int calculate_offset(int height) {
      return (int) ((double) height * ((double) this.start_timestamp /
                    (double) (this.newest_timestamp - this.oldest_timestamp))
                   );
    }

    private int calculate_height(double zoom) {
      return (int)((double)this.widget_height / zoom);
    }

    private double calculate_zoom() {
      var range = this.end_timestamp - this.start_timestamp;
      var total = this.newest_timestamp - this.oldest_timestamp;
      return (double)range/(double)total;
    }

    /* Converts a timestamp into a scale horizontal position. */
    private int TimestampToHScalePos(int timestamp) {
      var range = this.newest_timestamp - this.oldest_timestamp;
      double pos = (double)(timestamp - this.oldest_timestamp) / (double)range;
      return (int)Math.ceil((pos * (double)this.widget_width) + (double)TimelineProperties.PADDING + 0.5); 
    }

    private int HScalePosToTimestamp(int xpos) {
      double ratio = (xpos - (double)TimelineProperties.PADDING + 0.5) / (this.widget_width);
      return (int) Math.ceil(((this.newest_timestamp - this.oldest_timestamp) * 
                               ratio
                             ) + this.oldest_timestamp
                            );
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

    private void update_node_position( TimelineNode node ) {

    }

    public override bool button_press_event (Gdk.EventButton event) {
      this.mouse_down = true;
      this.mouse_press_x = (int)event.x;
      this.mouse_press_y = (int)event.y;
      var st = this.TimestampToHScalePos(this.start_timestamp) - 5;
      var et = this.TimestampToHScalePos(this.end_timestamp) + 5;
      var sv = this.widget_height - 25;
      var ev = this.widget_height - 11;

      if (this.mouse_press_y > sv &&
          this.mouse_press_y < ev &&
          this.mouse_press_x >= st &&
          this.mouse_press_x <= et ) {
        // figure out which part of the control we're over
        if (this.mouse_press_x <= st + 10) {
          // Over left handle
          this.grab_handle = TimelineHandle.LIMIT_OLD;
          this.grab_offset = this.mouse_press_x - st;
        } else if (this.mouse_press_x >= et - 10) {
          // Over right handle    
          this.grab_handle = TimelineHandle.LIMIT_NEW;
          this.grab_offset = this.mouse_press_x - et;
        } else {
          // Over the slider bar
          this.grab_handle = TimelineHandle.SLIDER;
          this.grab_offset = this.mouse_press_x - (st + ((et - st)/2));
        }

      } else {
        this.grab_handle = TimelineHandle.NONE;
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
      if (this.grab_handle > (int)TimelineHandle.NONE) {
        this.update_controls(this.mouse_release_x);
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
      this.grab_handle = TimelineHandle.NONE;
      return true;
    }

    public override bool motion_notify_event (Gdk.EventMotion event) {
      if (this.mouse_down && this.grab_handle > (int)TimelineHandle.NONE) {
        if (event.x != this.mouse_press_x) {
          this.update_controls((int)event.x);
          this.queue_draw();
        }
        return true;
      }

      // TODO This is really FFR part of kinetic scrolling
      // if the button is down elsewhere 
      //    pan widget to current co-ords
      return false;
    }

    // TODO
    public void RenderScale(Cairo.Context cr) {
    }

    public void RenderHandle(Cairo.Context cr, int timestamp) {
      var hpos = this.TimestampToHScalePos(timestamp);
      // Handle outline
      cr.move_to(hpos - 4.5, this.widget_height - 24.5);
      cr.line_to(hpos - 4.5, this.widget_height - 15.5);
      cr.line_to(hpos, this.widget_height - 11.5);
      cr.line_to(hpos + 4.5, this.widget_height - 15.5);
      cr.line_to(hpos + 4.5, this.widget_height - 24.5);
      cr.line_to(hpos - 4.5, this.widget_height - 24.5);
      // Handle fill
      var pattern = new Cairo.Pattern.linear(hpos - 4.5, 0, hpos + 4.5, 0);
      pattern.add_color_stop_rgb(0, 0xee/255.0, 0xee/255.0, 0xec/255.0); 
      pattern.add_color_stop_rgb(1, 0x88/255.0, 0x8a/255.0, 0x85/255.0);
      
      cr.set_source (pattern);
      cr.fill_preserve();
      cr.set_source_rgb(0x55/255.0, 0x57/255.0, 0x53/255.0);
      cr.stroke();

      // Handle inner highlight
      cr.move_to(hpos - 3.5, this.widget_height - 23.5);
      cr.line_to(hpos - 3.5, this.widget_height - 15.85);
      cr.line_to(hpos, this.widget_height - 13.0);
      cr.line_to(hpos + 3.5, this.widget_height - 15.85);
      cr.line_to(hpos + 3.5, this.widget_height - 23.5);
      cr.line_to(hpos - 3.5, this.widget_height - 23.5);

      cr.set_source_rgba(0xff/255.0,0xff/255.0,0xff/255.0, 20/100.0);      
      cr.stroke();
    }

    public void RenderControls(Cairo.Context cr) {
      int start_pos = this.TimestampToHScalePos(this.start_timestamp);
      int end_pos = this.TimestampToHScalePos(this.end_timestamp);
      // Render background
      cr.rectangle((double)TimelineProperties.PADDING + 0.5, this.widget_height - 22.5,
                   this.widget_width, 6.0);
      var pattern = new Cairo.Pattern.linear(0, this.widget_height - 22.5, 0, this.widget_height - 16.5);
      pattern.add_color_stop_rgb(0, 0x88/255.0, 0x8a/255.0, 0x85/255.0);
      pattern.add_color_stop_rgb(1, 0xee/255.0, 0xee/255.0, 0xec/255.0);
      cr.set_line_width(1);
      cr.set_source (pattern);
      cr.fill_preserve();
      cr.set_source_rgb(0x55/255.0, 0x57/255.0, 0x53/255.0);
      cr.stroke();

      // Render slider
      cr.rectangle (start_pos + 4.5, this.widget_height - 24.5,
                    end_pos - start_pos - 9, 9);
      pattern = new Cairo.Pattern.linear(0, this.widget_height - 24.5, 
                                         0,this.widget_height - 15.5);
      pattern.add_color_stop_rgb(0, 0x72/255.0,0x9f/255.0,0xcf/255.0);
      pattern.add_color_stop_rgb(1, 0x34/255.0,0x65/255.0,0xa4/255.0);
      cr.set_source (pattern);
      cr.fill_preserve();
      cr.set_source_rgb(0x20/255.0,0x4a/255.0,0x87/255.0);
      // Render some ticks in the middle of the slider
      var pos = this.TimestampToHScalePos(this.start_timestamp + ((this.end_timestamp - this.start_timestamp)/2)) - 3.5; 
      for (var i = 0; i < 3; i++) {
        cr.move_to(pos + (i * 3), this.widget_height - 22.5);
        cr.line_to(pos + (i * 3), this.widget_height - 17.5);
      }
      cr.stroke();
      // Slider Highlight
      cr.set_source_rgba(0xff/255.0,0xff/255.0,0xff/255.0, 20/100.0);
      cr.rectangle (start_pos + 5.5, this.widget_height - 23.5,
                    end_pos - start_pos - 11, 7);
      cr.stroke();

      this.RenderHandle(cr, this.start_timestamp);
      this.RenderHandle(cr, this.end_timestamp);
    }

    public override bool expose_event (Gdk.EventExpose event) {
      for (var i = 0; i < this.branches.length(); i++ ) {
        var branch = this.branches.nth_data(i);
        var real_pos = ((double)branch.position - (double)this.lowest_branch_position + 0.5);
        branch.px_position = (int)(real_pos * (double)this.branch_width);
      }

      var cr = Gdk.cairo_create (this.window);
      this.set_double_buffered(true);

      var surface = cr.get_group_target();
      var cr_background = new Cairo.Context(
                            new Cairo.Surface.similar(surface, 
                                                      Cairo.Content.COLOR, 
                                                      this.graph_width, 
                                                      this.graph_height)
                          );
      cr_background.set_source_rgb(0xee/255.0, 0xee/255.0, 0xec/255.0);
      cr_background.paint();
      cr_background.translate(0, (double)TimelineProperties.PADDING);

      var cr_foreground = new Cairo.Context(
                            new Cairo.Surface.similar(surface, 
                                                      Cairo.Content.COLOR_ALPHA, 
                                                      this.graph_width, 
                                                      this.graph_height)
                          );
      cr_foreground.translate(0, (double)TimelineProperties.PADDING);

      cr.rectangle((double)TimelineProperties.PADDING, (double)TimelineProperties.PADDING,
                   this.graph_width, this.graph_height);
      cr.set_source_rgb(0.0,0.0,0.0);
      cr.stroke();
      //this.RenderScale(cr);
      int y = 8, r, t = this.newest_timestamp - this.oldest_timestamp;
      double graph_height = (double)this.graph_height - ((double)TimelineProperties.PADDING * 2.0) + 1.0;
      double p, j, zoom = graph_height/ this.calculate_zoom();
      int offset = (int)(zoom * ((double)(this.start_timestamp - this.oldest_timestamp) / (double)t));
      offset = (int)graph_height - (int)zoom + offset;

      cr_foreground.translate(0, offset);
      cr_background.translate(0, offset);

      foreach (var node in this.nodes) {
        y = y + 16;
        node.px_position = y;
        r = node.timestamp - this.oldest_timestamp;
        j = (double)t - (double)r;
        p = j/(double)t;
        node.px_position = (int)(p * zoom);
        foreach (var edge in node.edges) { 
          if (edge.child == node) {
            // Render the edges onto the underneath surface
            edge.Render(cr_background);
          }
        }
        // Render the node onto the ontop surface
        node.Render(cr_foreground);
      }
      // composite surfaces together
      cr.set_source_surface(cr_background.get_group_target(), 
                            (double)TimelineProperties.PADDING, 
                            (double)TimelineProperties.PADDING);
      cr.paint();
      cr.set_source_surface(cr_foreground.get_group_target(), 
                            (double)TimelineProperties.PADDING, 
                            (double)TimelineProperties.PADDING);
      cr.paint();
      this.RenderControls(cr);
      return true;
    }
  }
}
