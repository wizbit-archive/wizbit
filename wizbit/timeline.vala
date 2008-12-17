/**
 * $LGPL header$
 */

/**
 * TODO
 * 1_  Create renderer for the scale.
 * 2x  Clean up some of the calculations
 * 3x  Optimize the shizzle out of it! 
       - Merge update_from_store and update_branches
         - Separate nicely from DB
       - Push out update_branch_positions to on configure not on expose
       - Push oout update_node_positions to when zoom has changed not on expose
 * 4_  Rename a bunch of things which are horribly named!
 * 5x  Node click zones calculations
 * 6.  Setting the selected node will scroll it to center
 * 7.  Work out the node globbing (nodes close to each other combind and size increases)
 * 8x  work out the horizontal/vertical positioning stuff
 * 9x  Fix hugging bug for negative columns
 * 10. Animations while timeline view changes, don't let zooming/panning
 *     be jumpy. Branches can slide and fade...
 * 11. use CIEXYZ colourspace for branch colouring
 * 12. Create the gradient blend for the column edges.
 * For Future Release (FFR);
 * x. Kinetic scrolling - add timing/timer stuff into signal handlers
 */

using GLib;
using Gtk;
using Cairo;

namespace Wiz {
  public enum TimelineProperties {
    HORIZONTAL = 0,
    VERTICAL = 1,
    PADDING = 8,
    SCALE_INDENT = 50 // TODO 4
  }
  // TODO 4 (width = length?)
  public enum TimelineHandle {
    NONE = 0,
    LIMIT_OLD = 1,
    SLIDER = 2,
    LIMIT_NEW = 3,
    WIDTH = 9,
    HEIGHT = 13,
    INDENT = 14
  }
  public enum TimelineUnit {
    MINUTES,
    HOURS,
    DAYS,
    MONTHS,
    YEARS
  }

  // TODO 4
  public enum TimelineNodeType {
    NORMAL,
    ROOT,
    PRIMARY_TIP,
    TIP
  }

  // A class for animated branchess
  // TODO 10, 11
  private class TimelineBranch : GLib.Object {
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
  private class TimelineEdge : GLib.Object {
    public TimelineNode parent;
    public TimelineNode child;

    public TimelineEdge(TimelineNode parent, TimelineNode child) {
      this.parent = parent;
      this.child = child;
    }

    public void render(Cairo.Context cr, double max_angle, int orientation) {
      // Draw a line from each parent.x/y to child.x/y
      int kx, ky; // Kink position
      int px, py, cx, cy;
      double odist, adist;
      if (orientation == (int)TimelineProperties.VERTICAL) {
        px = parent.branch.px_position;
        py = parent.px_position;
        cx = child.branch.px_position;
        cy = child.px_position;
      } else {
        py = parent.branch.px_position;
        px = parent.px_position;
        cy = child.branch.px_position;
        cx = child.px_position;
      }
      if (orientation == (int)TimelineProperties.VERTICAL) {
        odist = py - cy;
        adist = px - cx;
      } else {
        odist = px - cx;
        adist = py - cy;
      }
      if (odist < 0) { odist = odist * -1; }
      if (adist < 0) { adist = adist * -1; }
      double angle = Math.atan( odist/adist ) * (180.0/Math.PI);

      cr.move_to(px, py);
      if (orientation == (int)TimelineProperties.VERTICAL) {
        if (angle < max_angle) {
          kx = cx;
          ky = (int)(Math.tan(max_angle*(Math.PI/180.0)) * adist);
          cr.line_to(kx, py-ky);
        }
      } else {
        if (angle > max_angle) {
          ky = cy;
          kx = (int)(Math.tan(max_angle*(Math.PI/180.0)) * adist);
          cr.line_to(px+kx, ky);
        }
      }
      
      cr.line_to(cx, cy);
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
  private class TimelineNode : GLib.Object {
    private TimelineBranch t_branch = null;
    public bool visible { get; set; }
    public int node_type { get; set; } // TODO 4
    public int px_position;
    public int size;
    public string uuid;
    public int timestamp;
    public bool selected { get; set; }

    // Might not be best to make this weak
    public weak List<TimelineEdge> edges { get; construct; }

    public TimelineBranch branch {
      get {
        return this.t_branch;
      }
      set {
        if (this.t_branch != null) {
          this.t_branch.nodes.remove(this);
          // Update the oldest node timestamp?
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
      this.node_type = TimelineNodeType.NORMAL;
      this.selected = false;
      this.size = 15; // Edge size should be set based on branch_width
                      // and globbing of nodes
    }

    public void add_edge(TimelineNode node) {
      this.add_child(node);
      node.add_parent(this);
    }

    public void add_child(TimelineNode node) {
      this.edges.append(new TimelineEdge(this, node));
    }

    public void add_parent(TimelineNode node) {
      this.edges.append(new TimelineEdge(node, this));
    }

    public bool at_coords(int x, int y, int orientation) {
      double o = 0, a = 0;
      int nx, ny;
      if (orientation == (int)TimelineProperties.VERTICAL) {
        nx = this.branch.px_position;
        ny = this.px_position;
      } else {
        ny = this.branch.px_position;
        nx = this.px_position;
      }
      // TODO 8
      o = (nx - x) - (int)TimelineProperties.PADDING - 4;
      a = (ny - y) + (int)TimelineProperties.PADDING;
      if (o < 0) { o = o * -1; }
      if (a < 0) { a = a * -1; }

      double h = Math.sqrt((o*o)+(a*a));
      if (h < 0) { h = h * -1; }
      if (h < this.size) {
        stdout.printf("hit! %f %s\n", h, this.uuid);
        return true;
      }
      stdout.printf("hyp: %f %s\n", h, this.uuid);
      return false;
    }

    public void render(Cairo.Context cr, int orientation) {
      int x, y;
      if (orientation == (int)TimelineProperties.VERTICAL) {
        x = this.branch.px_position;
        y = this.px_position;
      } else {
        y = this.branch.px_position;
        x = this.px_position;
      }

      if (this.node_type == TimelineNodeType.PRIMARY_TIP) {
        if (orientation == (int)TimelineProperties.VERTICAL) {
          cr.arc_negative(x, y, this.size, 0, Math.PI);
          cr.move_to(x+this.size,y);
          cr.line_to(x,y+this.size);
          cr.line_to(x-this.size,y);
        } else {
          cr.arc_negative(x, y, this.size, Math.PI/2, Math.PI+(Math.PI/2));
          cr.move_to(x,y-this.size);
          cr.line_to(x-this.size,y);
          cr.line_to(x,y+this.size);
        }
        cr.set_source_rgb(0x34/255.0,0x65/255.0,0xa4/255.0);
        cr.fill_preserve();
        cr.set_source_rgb(0x20/255.0,0x4a/255.0,0x87/255.0);
        cr.stroke();
      } else if (this.node_type == TimelineNodeType.TIP) {
        if (orientation == (int)TimelineProperties.VERTICAL) {
          cr.arc_negative(x, y, this.size, 0, Math.PI);
          cr.move_to(x+this.size,y);
          cr.line_to(x,y+this.size);
          cr.line_to(x-this.size,y);
        } else {
          cr.arc_negative(x, y, this.size, Math.PI/2, Math.PI+(Math.PI/2));
          cr.move_to(x,y-this.size);
          cr.line_to(x-this.size,y);
          cr.line_to(x,y+this.size);
        }
        cr.set_source_rgb(0x73/255.0,0xd2/255.0,0x16/255.0);
        cr.fill_preserve();
        cr.set_source_rgb(0x4e/255.0,0x9a/255.0,0x06/255.0);
        cr.stroke();
      } else if (this.node_type == TimelineNodeType.ROOT) {
        if (orientation == (int)TimelineProperties.VERTICAL) {
          cr.arc(x, y, this.size, 0, Math.PI);
          cr.move_to(x+this.size,y);
          cr.line_to(x,y-this.size);
          cr.line_to(x-this.size,y);
        } else {
          cr.arc(x, y, this.size, Math.PI/2, Math.PI+(Math.PI/2));
          cr.move_to(x,y+this.size);
          cr.line_to(x+this.size,y);
          cr.line_to(x,y-this.size);
        }

        cr.set_source_rgb(this.branch.fill_r, 
                          this.branch.fill_g,
                          this.branch.fill_b);
        cr.fill_preserve();
        cr.set_source_rgb(this.branch.stroke_r, 
                          this.branch.stroke_g,
                          this.branch.stroke_b);
        cr.stroke();        
      } else {
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
  }

  public class Timeline : Gtk.Widget {
    private Bit bit = null;
    private Store store = null;
    private CommitStore commit_store = null;

    // The dag itself
    private TimelineNode primary_tip = null;
    private TimelineNode root = null;
    private TimelineNode selected = null; // TODO 6
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
    private double zoomed_extent = 0;

    // Grabbed information for the controls
    private int grab_handle;
    private int grab_offset;

    // Drawing information, what's our currentt zoom level and offset from
    // the start of the timeline
    private double offset { get; set; }
    private double edge_angle_max { get; set; }

    // Orientation of the timeline and controls
    public int orientation_timeline = TimelineProperties.HORIZONTAL;
    public int orientation_controls = TimelineProperties.HORIZONTAL;

    // The size of the graph, we exclude the padding and position occupied by  
    // the controls.
    public int graph_height {
      get {
        if (this.orientation_controls == (int)TimelineProperties.HORIZONTAL) { 
          return this.widget_height - (int)TimelineProperties.SCALE_INDENT;
        } else {
          return this.widget_height;
        }
      }
    }
    public int graph_width {
      get {
        if (this.orientation_controls == (int)TimelineProperties.HORIZONTAL) { 
          return this.widget_width;
        } else {
          return this.widget_width - (int)TimelineProperties.SCALE_INDENT;
        }
      }
    }

    // Pixel width of an individual branch
    public int branch_width {
      get {
        if (this.orientation_timeline == (int)TimelineProperties.VERTICAL) { 
          int rows = this.highest_branch_position - this.lowest_branch_position + 1;
          return this.graph_width / rows;
        } else {
          int rows = this.highest_branch_position - this.lowest_branch_position + 1;
          return this.graph_height / rows;
        } 
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
          this.update_from_store();
        }
      }
    }

    public string selected_uuid {
      get {
        return this.selected.uuid;
      }
      set {
        this.selected.selected = false;
        this.selected = null;
        foreach (var node in this.nodes) {
          if (node.uuid == value) {
            this.selected = node;
            break;
          }
        }
        // TODO 6
        if (this.selected != null) { /*this.scroll_to_node(this.selected);*/ }
      }
    }

    public signal void selection_changed ();

    // We can construct with no bit specified, and use bit_uuid to open the bit
    public Timeline(Store store, string? bit_uuid) {
      this.set_double_buffered(true);
      this.nodes = new List<TimelineNode>();
      this.tips = new List<TimelineNode>();
      this.branches = new List<TimelineBranch>();
      this.mouse_down = false;
      this.selected = null;
      this.lowest_branch_position = 0;
      this.store = store;
      this.bit_uuid = bit_uuid;
    }

    public override void size_request (out Gtk.Requisition requisition) {
      requisition.width = 400;
      requisition.height = 220;
    }

    public override void size_allocate (Gdk.Rectangle allocation) {
      this.allocation = (Gtk.Allocation)allocation;
 
      if ((this.get_flags () & Gtk.WidgetFlags.REALIZED) == 0)
        return;
      this.window.move_resize (this.allocation.x, this.allocation.y,
                               this.allocation.width, this.allocation.height);

      // size has changed so we update the position calculations
      this.update_branch_positions();
      this.update_node_positions();
    }

    public override void realize () {
      this.set_flags (Gtk.WidgetFlags.REALIZED);
      var attrs = Gdk.WindowAttr ();
      attrs.window_type = Gdk.WindowType.CHILD;
      attrs.width = this.allocation.width;
      attrs.wclass = Gdk.WindowClass.INPUT_OUTPUT;
      attrs.event_mask = this.get_events() | Gdk.EventMask.EXPOSURE_MASK | 
                                             Gdk.EventMask.POINTER_MOTION_MASK |
                                             Gdk.EventMask.BUTTON_PRESS_MASK |
                                             Gdk.EventMask.BUTTON_RELEASE_MASK;
      this.window = new Gdk.Window (this.get_parent_window (), attrs, 0);
      this.window.set_user_data (this);
      this.style = this.style.attach (this.window);
      this.style.set_background (this.window, Gtk.StateType.NORMAL);
      this.window.move_resize (this.allocation.x, this.allocation.y,
                               this.allocation.width, this.allocation.height);
      // Initial positioning calculations, now that we know how bit the widget is
      this.update_branch_positions();
      this.update_node_positions();
    }

    public override void unrealize () {
      this.window.set_user_data (null);
    }

    private TimelineNode get_node(string uuid, bool prepend) {
      foreach (var node in this.nodes) {
        if (node.uuid == uuid) {
          return node;
        }
      }
      var node = new TimelineNode(uuid, this.commit_store.get_timestamp(uuid));
      if (prepend) {
        this.nodes.prepend(node);
      } else {
        this.nodes.append(node);
      }
      return node;
    }

    private void update_from_store () {
      assert(this.commit_store != null);
      string child_uuid = "";
      string root = this.commit_store.get_root();
      string primary_tip = this.commit_store.get_primary_tip();      
      this.primary_tip = this.get_node(primary_tip, false);
      this.tips.append(this.primary_tip);
      this.primary_tip.node_type = TimelineNodeType.PRIMARY_TIP;
      TimelineNode node = this.primary_tip;
      TimelineBranch branch = new TimelineBranch(null);
      this.branches.append(branch);
      branch.position = 0;

      // Step backward over parents until we hit the root
      while (true) {
        var children = this.commit_store.get_forwards(node.uuid);
        foreach (var child in children) {
          if (child == child_uuid) { continue; }
          var child_node = this.get_node(child, false);
          node.add_edge(child_node);
          this.recurse_children(child_node, new TimelineBranch(branch));
        }
        child_uuid = node.uuid;
        node.branch = branch;
        if (node.uuid == root) {
          this.root = node;
          this.root.node_type = TimelineNodeType.ROOT;
          break;
        }
        var last_node = node;
        node = this.get_node(this.commit_store.get_backward(node.uuid), true);
        node.add_edge(last_node);
      }
      this.newest_timestamp = this.primary_tip.timestamp;
      this.oldest_timestamp = this.root.timestamp;
      this.start_timestamp = this.oldest_timestamp;
      this.end_timestamp = this.newest_timestamp;
      this.update_branches();
    }

    private void update_branches () {
      int i, j, d;
      /* HUGGING */ 
      // Now that all the branches exist, and the reflogs of each tip assigned
      // to a branch. We can arrange the branches into the densest space.
      for (i = 1; i < this.branches.length(); i++ ) {
        d = 1;
        var branch = this.branches.nth_data(i);
        for (j = 1; j < i; j++ ) {
          var branch_match = this.branches.nth_data(j);
          if ((branch.oldest > branch_match.newest) ||
              (branch.newest < branch_match.oldest)) {
            branch.position = branch_match.position;
          } else if (branch.oldest < branch_match.oldest) {
            branch.position = branch_match.position + 1;
          } else if (branch.oldest > branch_match.oldest) {
            // TODO 9 I think this now works... not sure without a much more complex graph...
            if (branch.position > 0) {
              if ((branch_match.position + branch.position) > branch_match.position) {
                branch.position = branch.position * -1; 
              }
            } else if (branch_match.position < 0) {
              if ((branch_match.position + branch.position) < branch_match.position) {
                branch.position = branch.position * -1; 
              }
            }
          } else {
            // This should never ever happen
            stdout.printf("Branch position wasn't hugged\n");
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
      node.branch = branch;
      if (this.branches.index(branch) < 0) {
        this.branches.append(branch);
      }

      var first_child = this.commit_store.get_forward(node.uuid);
      if (first_child == null) {
        node.node_type = TimelineNodeType.TIP;
        this.tips.append(node);
        return;
      }
      var child_node = this.get_node(first_child, false);
      node.add_edge(child_node);
      this.recurse_children(child_node, branch);

      var children = this.commit_store.get_forwards(node.uuid);
      foreach (var child in children) {
        // All other children are on new branches
        if (child == first_child) { continue; }
        var child_node = this.get_node(child, false);
        node.add_edge(child_node);
        this.recurse_children(child_node, new TimelineBranch(branch));
      }
    }

    // TODO 10
    private void update_visibility() {
      foreach (var node in this.nodes) {
        if ((node.timestamp <= this.end_timestamp) && 
            (node.timestamp >= this.start_timestamp)) {
          node.visible = true;
        } else {
          node.visible = false;
        }
      }
    }

    private void update_branch_positions() {
      for (var i = 0; i < this.branches.length(); i++ ) {
        var branch = this.branches.nth_data(i);
        var real_pos = (branch.position - this.lowest_branch_position + 0.5);
        branch.px_position = (int)(real_pos * this.branch_width);
      }
    }

    private void update_node_positions() {
      int position;
      double odist, adist, angle;
      double t = this.newest_timestamp - this.oldest_timestamp;
      double r;
      this.calculate_zoom();
      foreach (var node in this.nodes) {
        r = node.timestamp - this.oldest_timestamp;
        position = (int)(((t - r) / t) * this.zoomed_extent);
        if (this.orientation_timeline == (int)TimelineProperties.HORIZONTAL) {
          position = (int)this.graph_width - position;
        }
        node.px_position = position;
      }
      this.edge_angle_max = 45.0;
      foreach (var node in this.nodes) {
        foreach (var edge in node.edges) { 
          if (edge.child != node) {
            continue;
          }
          // TODO 7
          if (edge.parent.branch.px_position == node.branch.px_position) {
            continue;
          }
          // Opposite and adjacent distances
          odist = edge.parent.px_position - node.px_position;
          adist = edge.parent.branch.px_position - node.branch.px_position;

          if (odist < 0) { odist = odist * -1; }
          if (adist < 0) { adist = adist * -1; }
          angle = Math.atan( odist/adist ) * (180.0/Math.PI);
          if (angle < this.edge_angle_max) { this.edge_angle_max = angle; }
        }
      }
    }

    /*
     * Update the timestamp's from where the position controls are.
     *
     */
    // TODO 8
    private void update_controls(int x) {
      int last_start = this.start_timestamp;
      int last_end = this.end_timestamp;
      if (this.grab_handle > (int)TimelineHandle.NONE) {
        var xpos = x - this.grab_offset;
        if (this.grab_handle == TimelineHandle.LIMIT_OLD) {
          this.start_timestamp = this.scale_pos_to_timestamp(xpos);
        } else if (this.grab_handle == TimelineHandle.LIMIT_NEW) {
          this.end_timestamp = this.scale_pos_to_timestamp(xpos);
        } else if (this.grab_handle == TimelineHandle.SLIDER) {
          var click_timestamp = this.scale_pos_to_timestamp(xpos);
          var half_time = (this.end_timestamp - this.start_timestamp)/2;
          var tmp_s = click_timestamp - half_time;
          var tmp_e = click_timestamp + half_time;
          if ((tmp_s >= this.oldest_timestamp) && 
              (tmp_e <= this.newest_timestamp)) {
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
        if ((last_start != this.start_timestamp) ||
            (last_end != this.end_timestamp)) {
          this.update_node_positions();
        }
      }
    }

    private void calculate_zoom() {
      double t = this.newest_timestamp - this.oldest_timestamp;
      double r = this.end_timestamp - this.start_timestamp;
      double offset = this.start_timestamp - this.oldest_timestamp;
      if (this.orientation_timeline == (int)TimelineProperties.VERTICAL) {
        double graph_height = this.graph_height - this.branch_width;
        this.zoomed_extent = graph_height / (r / t);
        offset = this.zoomed_extent * (offset / t);
        this.offset = graph_height - this.zoomed_extent + offset;
      } else {
        double graph_width = this.graph_width - this.branch_width;
        this.zoomed_extent = graph_width / (r / t);
        offset = this.zoomed_extent * (offset / t);
        this.offset = 0 - graph_width + this.zoomed_extent - offset - this.branch_width;
      }
    }
    /* Converts a timestamp into a scale horizontal position. */
    // TODO 8
    private int timestamp_to_scale_pos(int timestamp) {
      var range = this.newest_timestamp - this.oldest_timestamp;
      double pos = (double)(timestamp - this.oldest_timestamp) / (double)range;
      return (int)Math.ceil((pos * (double)this.widget_width) + (double)TimelineProperties.PADDING + 0.5); 
    }

    // TODO 8
    private int scale_pos_to_timestamp(int xpos) {
      double ratio = (xpos - (double)TimelineProperties.PADDING + 0.5) / (this.widget_width);
      return (int) Math.ceil(((this.newest_timestamp - this.oldest_timestamp) * 
                               ratio
                             ) + this.oldest_timestamp
                            );
    }

    // Get the tick timestamp equal to are larger than start timestamp
    private int get_lowest_scale_timestamp(int start_timestamp, TimelineUnit unit) {
      Time t = Time.gm((time_t) start_timestamp);
      t.second = 0;
      if (unit == TimelineUnit.MINUTES) {
        t.minute = t.minute + 1;
      } else if (unit == TimelineUnit.HOURS) {
        t.minute = 0;
        t.hour = t.hour + 1;
      } else if (unit == TimelineUnit.DAYS) {
        t.minute = 0;
        t.hour = 0;
        t.day = t.day + 1;
      } else if (unit == TimelineUnit.MONTHS) {
        t.minute = 0;
        t.hour = 0;
        t.day = 0;
        t.month = t.month + 1;
      } else if (unit == TimelineUnit.YEARS) {
        t.minute = 0;
        t.hour = 0;
        t.day = 0;
        t.month = 0;
        t.year = t.year + 1;
      }
      return (int)t.mktime();
    }

    // Get the tick timestamp equal to are larger than start timestamp
    private int get_highest_scale_timestamp(int end_timestamp, TimelineUnit unit) {
      Time t = Time.gm((time_t) end_timestamp);
      t.second = 0;
      if (unit == TimelineUnit.MINUTES) {
        t.minute = t.minute - 1;
      } else if (unit == TimelineUnit.HOURS) {
        t.minute = 0;
        t.hour = t.hour - 1;
      } else if (unit == TimelineUnit.DAYS) {
        t.minute = 0;
        t.hour = 0;
        t.day = t.day - 1;
      } else if (unit == TimelineUnit.MONTHS) {
        t.minute = 0;
        t.hour = 0;
        t.day = 0;
        t.month = t.month - 1;
      } else if (unit == TimelineUnit.YEARS) {
        t.minute = 0;
        t.hour = 0;
        t.day = 0;
        t.month = 0;
        t.year = t.year - 1;
      }
      return (int)t.mktime();
    }

    private int get_next_scale_timestamp(int timestamp, TimelineUnit unit) {
      if (unit == TimelineUnit.MINUTES) {
        return timestamp + 60;
      } else if (unit == TimelineUnit.HOURS) {
        return timestamp + (60 * 60);
      } else if (unit == TimelineUnit.DAYS) {
        return timestamp + (60 * 60 * 24);
      } else if (unit == TimelineUnit.MONTHS) {
        Time t = Time.gm((time_t) timestamp);
        t.month = t.month + 1;
        return (int)t.mktime();
      } else if (unit == TimelineUnit.YEARS) {
        return timestamp + (60 * 60 * 24 * 365);
      }
      return 0;
    }

    // Returns the best scale unit for the range of time between start and 
    // end timestamps.  
    private TimelineUnit get_scale_unit(int start_timestamp, int end_timestamp) {
      int t = end_timestamp - start_timestamp;
      // This isn't the best way to do this but nevermind :/
      if (t < 60 * 60 ) {
        return TimelineUnit.MINUTES;
      } else if (t < 60 * 60 * 24) { 
        return TimelineUnit.HOURS;
      } else if (t < 60 * 60 * 24 * 30) { 
        return TimelineUnit.DAYS;
      } else if (t < 60 * 60 * 24 * 365) { 
        return TimelineUnit.MONTHS;
      }
      return TimelineUnit.YEARS;
    }

    // TODO 8
    public override bool button_press_event (Gdk.EventButton event) {
      this.mouse_down = true;
      this.mouse_press_x = (int)event.x;
      this.mouse_press_y = (int)event.y;
      var st = this.timestamp_to_scale_pos(this.start_timestamp) - 5;
      var et = this.timestamp_to_scale_pos(this.end_timestamp) + 5;
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
        // TODO 8 - update controls should pick point by orientation
        this.update_controls(this.mouse_release_x);
        this.queue_draw();
      } else if (Gtk.drag_check_threshold(this, this.mouse_press_x,
                                               this.mouse_press_y,
                                               this.mouse_release_x,
                                               this.mouse_release_y)) {
        // TODO FFR - This is for kinetic scrolling
        // Drag threshold was exceeded
        // create release timestamp (milliseconds)
        // this.button_release_timestamp = ?
        // calculate the distance travelled in that time and therefore the speed
        // start a timer which controls the speed/positioning (kinetic scroll)
        // horizontal scrolling will change the zoom level
      } else {
        // TODO 6
        // A click event occurred
        TimelineNode last = this.selected;
        this.selected = null;
        foreach (var node in this.nodes) {
          if (node.at_coords(this.mouse_release_x, this.mouse_release_y,
                             this.orientation_timeline)) {
            if (node != last) {
              last.selected = false;
              this.selected = node;
              this.selected.selected = true;
            } else {
              this.selected = node;
            } 
            break; 
          }
        }
        if (this.selected != last) {
          this.selection_changed();
          this.queue_draw();
        }
      }
      this.grab_handle = TimelineHandle.NONE;
      return true;
    }

    // TODO 8
    public override bool motion_notify_event (Gdk.EventMotion event) {
      if (this.mouse_down && this.grab_handle > (int)TimelineHandle.NONE) {
        if (event.x != this.mouse_press_x) {
          this.update_controls((int)event.x);
          this.queue_draw();
        }
        return true;
      }

      // TODO FFR part of kinetic scrolling
      // if the button is down elsewhere 
      //    pan widget to current co-ords
      return false;
    }

    public override bool expose_event (Gdk.EventExpose event) {
      var cr = Gdk.cairo_create (this.window);
      var surface = cr.get_group_target();
      var cr_background = new Cairo.Context(
                            new Cairo.Surface.similar(surface, 
                                                      Cairo.Content.COLOR, 
                                                      this.graph_width, 
                                                      this.graph_height)
                          );
      var cr_foreground = new Cairo.Context(
                            new Cairo.Surface.similar(surface, 
                                                      Cairo.Content.COLOR_ALPHA, 
                                                      this.graph_width, 
                                                      this.graph_height)
                          );

      if (this.orientation_timeline == (int)TimelineProperties.VERTICAL) {
        cr_foreground.translate(0, (double)this.branch_width/2.0 + this.offset);
        cr_background.translate(0, (double)this.branch_width/2.0 + this.offset);
      } else {
        cr_foreground.translate((double)this.branch_width/2.0 + this.offset, 0);
        cr_background.translate((double)this.branch_width/2.0 + this.offset, 0);
      }
      cr_background.set_source_rgb(0xee/255.0, 0xee/255.0, 0xec/255.0);
      cr_background.paint();

      this.render_scale(cr_background);
      foreach (var node in this.nodes) {
        foreach (var edge in node.edges) { 
          if (edge.child == node) {
            // Render the edges onto the underneath surface
            edge.render(cr_background, 
                        this.edge_angle_max, 
                        (int)this.orientation_timeline);
          }
          // TODO 12
          // Don't render all of strokes one after the other, wait until all of
          // the nodes have drawn their lines and stroke it all at once with
          // a pattern generated from the branch positions
        }
        // Render the node onto the ontop surface
        node.render(cr_foreground, (int)this.orientation_timeline);
      }
      cr.rectangle((double)TimelineProperties.PADDING, 
                   (double)TimelineProperties.PADDING,
                   this.graph_width, this.graph_height);
      cr.set_source_rgb(0.0,0.0,0.0);
      cr.stroke();
      // composite surfaces together
      cr.set_source_surface(cr_background.get_group_target(), 
                            (double)TimelineProperties.PADDING, 
                            (double)TimelineProperties.PADDING);
      cr.paint();
      cr.set_source_surface(cr_foreground.get_group_target(), 
                            (double)TimelineProperties.PADDING, 
                            (double)TimelineProperties.PADDING);
      cr.paint();
      this.render_controls(cr);
      return true;
    }

    private void scroll_to_timestamp(int timestamp) {
      // TODO 6
      // Start a timer which ramps from the current place to the timestamp
      // We work out the new timestamp by taking the distance between
      // the range, halving it and setting the start and end timestamps
      // accordingly. Same as we do with motion on the slider.
    }

    private void render_scale(Cairo.Context cr) {
      TimelineUnit scaleunit = this.get_scale_unit(this.start_timestamp,
                                                   this.end_timestamp);
      double t = this.newest_timestamp - this.oldest_timestamp;
      double r = this.end_timestamp - this.start_timestamp;
      int timestamp = get_highest_scale_timestamp(this.start_timestamp, scaleunit);
      int end_timestamp = get_lowest_scale_timestamp(this.newest_timestamp, scaleunit);
      int px_pos;
      if (this.orientation_timeline == (int)TimelineProperties.VERTICAL) {
        cr.move_to((this.graph_width/2) + 0.5, 
                   (-1*this.offset) - (this.branch_width/2));
        cr.line_to((this.graph_width/2) + 0.5, 
                   (this.branch_width/2) + this.graph_width + (-1*this.offset));
      } else {
        cr.move_to((-1*this.offset) - (this.branch_width/2), 
                   (this.graph_height/2) + 0.5);
        cr.line_to((this.branch_width/2) + this.graph_width + (-1*this.offset), 
                   (this.graph_height/2) + 0.5);
      }
      while (timestamp < end_timestamp) {
        r = timestamp - this.oldest_timestamp;
        px_pos= (int)(((t - r) / t) * this.zoomed_extent);
        if (this.orientation_timeline == (int)TimelineProperties.VERTICAL) {
          px_pos = (int)this.graph_width - px_pos;
          cr.move_to((this.graph_width/2) + 0.5, px_pos + 0.5);
          cr.line_to((this.graph_width/2) + 8.5, px_pos + 0.5);
        } else {
          px_pos = (int)this.graph_width - px_pos;
          cr.move_to(px_pos + 0.5, (this.graph_height/2) + 0.5);
          cr.line_to(px_pos + 0.5, (this.graph_height/2) + 8.5);
        }
        timestamp = get_next_scale_timestamp(timestamp, scaleunit);      
      }
      cr.set_line_width(1);
      cr.set_source_rgb(0.0,0.0,0.0);
      cr.stroke();
    }

    private void render_controls_scale(Cairo.Context cr) {
      TimelineUnit scaleunit = this.get_scale_unit(this.oldest_timestamp, 
                                                 this.newest_timestamp);
      if (this.orientation_controls == (int)TimelineProperties.VERTICAL) {
        // TODO 8
      } else { 
        cr.rectangle((double)TimelineProperties.PADDING + 0.5, 
                     this.widget_height + 0.5,
                     this.widget_width, (double)TimelineProperties.PADDING);
      }
      int timestamp = get_lowest_scale_timestamp(this.oldest_timestamp, scaleunit);
      int px_pos;
      while (timestamp < this.newest_timestamp) {
        px_pos = timestamp_to_scale_pos(timestamp);
        if (this.orientation_controls == (int)TimelineProperties.VERTICAL) {
          // TODO 8
        } else {
          cr.move_to(px_pos + 0.5, this.widget_height - 8.5);
          cr.line_to(px_pos + 0.5, this.widget_height + (double)TimelineProperties.PADDING + 0.5);
        }
        timestamp = get_next_scale_timestamp(timestamp, scaleunit);
      }
      cr.set_source_rgb(0.0,0.0,0.0);
      cr.stroke();
    }

    // TODO 8
    private void render_controls_handle(Cairo.Context cr, int timestamp) {
      var hpos = this.timestamp_to_scale_pos(timestamp);
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

    // TODO 8
    private void render_controls_background(Cairo.Context cr) {
      cr.rectangle((double)TimelineProperties.PADDING + 0.5, 
                   this.widget_height - 22.5,
                   this.widget_width, 6.0);
      var pattern = new Cairo.Pattern.linear(0, this.widget_height - 22.5, 
                                             0, this.widget_height - 16.5);
      pattern.add_color_stop_rgb(0, 0x88/255.0, 0x8a/255.0, 0x85/255.0);
      pattern.add_color_stop_rgb(1, 0xee/255.0, 0xee/255.0, 0xec/255.0);
      cr.set_line_width(1);
      cr.set_source (pattern);
      cr.fill_preserve();
      cr.set_source_rgb(0x55/255.0, 0x57/255.0, 0x53/255.0);
      cr.stroke();
    }

    // TODO 8
    private void render_controls_slider(Cairo.Context cr) {
      int start_pos = this.timestamp_to_scale_pos(this.start_timestamp);
      int end_pos = this.timestamp_to_scale_pos(this.end_timestamp);
      double center = (this.end_timestamp - this.start_timestamp)/2;
      center = center + this.start_timestamp;
      center = (double)this.timestamp_to_scale_pos((int)center) - 3.5; 

      cr.rectangle (start_pos + 4.5, this.widget_height - 24.5,
                    end_pos - start_pos - 9, 9);
      var pattern = new Cairo.Pattern.linear(0, this.widget_height - 24.5, 
                                         0,this.widget_height - 15.5);
      pattern.add_color_stop_rgb(0, 0x72/255.0,0x9f/255.0,0xcf/255.0);
      pattern.add_color_stop_rgb(1, 0x34/255.0,0x65/255.0,0xa4/255.0);
      cr.set_source (pattern);
      cr.fill_preserve();
      cr.set_source_rgb(0x20/255.0,0x4a/255.0,0x87/255.0);
      // Render some ticks in the middle of the slider
      for (var i = 0; i < 3; i++) {
        cr.move_to(center + (i * 3), this.widget_height - 22.5);
        cr.line_to(center + (i * 3), this.widget_height - 17.5);
      }
      cr.stroke();
      // Slider Highlight
      cr.set_source_rgba(0xff/255.0,0xff/255.0,0xff/255.0, 20/100.0);
      cr.rectangle (start_pos + 5.5, this.widget_height - 23.5,
                    end_pos - start_pos - 11, 7);
      cr.stroke();
    }

    private void render_controls(Cairo.Context cr) {
      this.render_controls_background(cr);
      this.render_controls_slider(cr);
      this.render_controls_handle(cr, this.start_timestamp);
      this.render_controls_handle(cr, this.end_timestamp);
      this.render_controls_scale(cr);
    }
  }
}
