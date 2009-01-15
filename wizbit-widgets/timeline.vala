/**
 * $LGPL header$
 */

/**
 * TODO
 * 1x  Create renderer for the scale.
 * 2x  Clean up some of the calculations
 * 3_  Optimize the shizzle out of it!
       - Merge update_from_store and update_branches
         - Separate nicely from DB
       - Push out update_branch_positions to on configure not on expose
       - Push oout update_node_positions to when zoom has changed not on expose
       * Cut down number of rendering redraws by using the offset to 
         composite layers and only redraw parts when required.
 * 4_  Rename a bunch of things which are horribly named!
 * 5x  Node click zones calculations
 * 6x  Setting the selected node will scroll it to center
 * 7x  Work out the node globbing (nodes close to each other combind and size increases)
 * 8x  work out the horizontal/vertical positioning stuff
 * 9x  Fix hugging bug for negative columns
 * 10. Animations while timeline view changes, don't let zooming/panning
 *     be jumpy.
 * 11. use CIEXYZ colourspace for branch colouring
 * 12. Create the gradient blend for the column edges.
 * 13x Kinetic scrolling - add timing/timer stuff into signal handlers
 */

using GLib;
using Gtk;
using Cairo;
using Wiz;

namespace WizWidgets {
  public enum Constant {
    HORIZONTAL = 0,
    VERTICAL = 1
  }

  private enum Handle { // TODO 4
    NONE = 0,
    KINETIC = 1,
    LIMIT_OLD = 2,
    SLIDER = 3,
    LIMIT_NEW = 4
  }
  private enum Render {
    CONTROLS = 1,
    GRAPH = 2,
    SCALE = 4,
    BACKGROUND = 8
  }

  private enum TimeUnit {
    MINUTES,
    HOURS,
    DAYS,
    WEEKS,
    MONTHS,
    YEARS
  }

  // TODO 4
  private enum NodeType {
    NORMAL,
    ROOT,
    PRIMARY_TIP,
    TIP
  }

  // TODO 11
  private class Branch : GLib.Object {
    public Branch parent = null;
    public List<Node> nodes; // All the nodes that belong to this branch
    public int position;             // The position of this branch
    public int px_position = 0;      // This branches pixel position: x or y
    public int offset;               // The current offset position
    public int oldest = 0;
    public int newest = 0;

    public double stroke_r;
    public double stroke_g = 0.0;
    public double stroke_b = 0.0;

    public double fill_r;
    public double fill_g = 0.0;
    public double fill_b = 0.0;

    public Branch(Branch? parent) {
      this.stroke_r = 0xa4/255.0;
      this.fill_r = 0xcc/255.0;
      this.parent = parent;
      this.nodes = new List<Node>();
      this.position = 0;
    }
  }

  /* Each edge is a connetion in a certain direction, from the parent to the
   * child
   */
  private class Edge : GLib.Object {
    public Node parent;
    public Node child;

    public Edge(Node parent, Node child) {
      this.parent = parent;
      this.child = child;
    }

    public void render(Cairo.Context cr, double max_angle, Constant orientation) {
      // Draw a line from each parent.x/y to child.x/y
      int kx, ky; // Kink position
      int px, py, cx, cy;
      double odist, adist;
      if (orientation == Constant.VERTICAL) {
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
      if (orientation == Constant.VERTICAL) {
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
      if (orientation == Constant.VERTICAL) {
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
      // TODO 3, 12
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
  private class Node : GLib.Object {
    public List<Node> globbed_nodes;
    public Node globbed_by;
    public weak List<Edge> edges { get; construct; } // Might not be best to make this weak
    public bool globbed { get; set; }
    public bool visible { get; set; }
    public bool selected { get; set; }
    public string uuid;
    public int timestamp;
    public int node_type { get; set; } // TODO 4
    public int px_position;
    private Constant orientation;
    private Cairo.Context cr;
    private int animating;
    private int timer_id;
    public double size; // private/animated
    // private double size;
    private double opacity;
    private double end_size;

    private Branch t_branch = null;
    public Branch branch {
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

    public Node (string uuid, int timestamp) {
      this.uuid = uuid;
      this.timestamp = timestamp;
      this.edges = new List<Edge>();
      this.node_type = NodeType.NORMAL;
      this.selected = false;
      this.globbed = false;
      this.size;
    }

    public void add_edge(Node node) {
      this.add_child(node);
      node.add_parent(this);
    }

    public void add_child(Node node) {
      this.edges.append(new Edge(this, node));
    }

    public void add_parent(Node node) {
      this.edges.append(new Edge(node, this));
    }

    // FIXME padding and offset should be implicit... x and y should maybe be
    // branch_px and node_px for simplicity sake
    public bool at_coords(int x, int y, Constant orientation, int offset, int padding) {
      double o = 0, a = 0;
      int nx, ny;
      if (orientation == Constant.VERTICAL) {
        nx = this.branch.px_position;
        ny = this.px_position;
        o = (nx - x) + padding;
        a = (ny - y) - offset;
      } else {
        ny = this.branch.px_position;
        nx = this.px_position;
        o = (nx - x) + offset + 8;
        a = (ny - y) + padding;
      }
      if (o < 0) { o = o * -1; }
      if (a < 0) { a = a * -1; }
      double h = Math.sqrt((o*o)+(a*a));
      if (h < 0) { h = h * -1; }
      if (h < this.size) {
        return true;
      }
      return false;
    }

    public bool shrink(double size){
      return false;
    }
    public bool fade_out() {
      return false;
    }
    public bool fade_in() {
      return false;
    }
    public bool grow(double size) {
      return false;
    }

    private void render_tip() {
    }
    private void render_node() {
    }
    private void render_root() {
    }

    public void render(Cairo.Context cr, Constant orientation) {
      this.orientation = orientation;
      this.cr = cr;

      int x, y;
      if (orientation == Constant.VERTICAL) {
        x = this.branch.px_position;
        y = this.px_position;
      } else {
        y = this.branch.px_position;
        x = this.px_position;
      }

      if (this.node_type == NodeType.PRIMARY_TIP) {
        if (orientation == Constant.VERTICAL) {
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
      } else if (this.node_type == NodeType.TIP) {
        if (orientation == Constant.VERTICAL) {
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
      } else if (this.node_type == NodeType.ROOT) {
        if (orientation == Constant.VERTICAL) {
          cr.move_to(x+this.size,y);
          cr.arc(x, y, this.size, 0, Math.PI);
          cr.move_to(x+this.size,y);
          cr.line_to(x,y-this.size);
          cr.line_to(x-this.size,y);
        } else {
          cr.move_to(x,y+this.size);
          cr.line_to(x+this.size,y);
          cr.line_to(x,y-this.size);
          cr.arc_negative(x, y, this.size, Math.PI+(Math.PI/2), Math.PI/2);
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

      if (this.selected) {
        cr.arc(x, y, this.size, 0, 2.0 * Math.PI);
        cr.set_source_rgba(1,1,1,0.2);
        cr.fill_preserve();
        cr.set_source_rgba(1,1,1,0.4);
        cr.stroke();
      }
    }
  }

  public class Timeline : Gtk.Widget {
    private Wiz.Bit bit                   = null;
    private Wiz.Store store               = null;
    private Wiz.CommitStore commit_store  = null;

    // The dag itself
    private Node primary_tip              = null;
    private Node root                     = null;
    private Node selected                 = null;
    private List<Node> nodes;
    private List<Node> tips;

    // Branch hugging
    private List<Branch> branches;
    private int lowest_branch_position    = 0;
    private int highest_branch_position   = 0;

    // Node globbing
    private double node_min_size;
    private double node_max_size;
    private double node_glob_size;

    // Scale ranges
    private int oldest_timestamp;
    private int newest_timestamp;
    private int start_timestamp;
    private int end_timestamp;

    // Mouse handling
    private bool mouse_down               = false;
    private int mouse_press_x;
    private int mouse_press_y;
    private int mouse_release_x;
    private int mouse_release_y;
    private int mouse_last_x;
    private int mouse_last_y;
    private int mouse_direction;

    // Scrolling
    private int grab_handle;
    private int grab_offset;
    private double easing_radius;
    private double easing_diff;
    private double anim_start_time;
    private int anim_start_timestamp;
    private int anim_end_timestamp;
    private double anim_duration;

    // Kinetic scrolling
    private double kinetic_start_timestamp;
    private double kinetic_end_timestamp;
    private double kinetic_last_tick_timestamp;
    private int total_distance_travelled;
    private double velocity;
    private int pan_cursor_timestamp;
    private int pan_start_timestamp;
    private double pan_offset;

    // Drawing information
    // TODO 3
    private Cairo.Context cr;             // The widget cairo context
    private Cairo.Context cr_background;  // Render on zoom/resize
    private Cairo.Context cr_edges;       // Render on zoom/resize
    private Cairo.Context cr_nodes;       // Render on zoom/resize
    private Cairo.Context cr_controls;    // Render on zoom/scroll/resize
    private Cairo.Context cr_scale;       // Render on bit_uuid changed/resize
    private int do_render;
    private double offset;
    private double edge_angle_max;
    private double zoomed_extent = 0;
    public int padding { get; set; }
    public int controls_height { get; set; }
    public int handle_width { get; set; }
    public int scale_padding { get; set; }
    public int scale_height { get; set; }
    public bool draw_scale { get; set; }

    /*
     * The orientation of the timeline
     */
    public Constant orientation_timeline { get; set; }
    /*
     * The orientation of the controls
     */
    public Constant orientation_controls { get; set; }

    private int graph_height {
      get {
        if (this.orientation_controls == Constant.HORIZONTAL) {
          return this.widget_height - 
                 ( this.controls_height + 
                   this.scale_padding + 
                   this.scale_height + 
                   this.padding );
        } else {
          return this.widget_height;
        }
      }
    }
    private int graph_width {
      get {
        if (this.orientation_controls == Constant.HORIZONTAL) {
          return this.widget_width;
        } else {
          return this.widget_width - 
                 ( this.controls_height + 
                   this.scale_padding + 
                   this.scale_height + 
                   this.padding );
        }
      }
    }

    // Pixel width of an individual branch
    private int branch_width {
      get {
        if (this.orientation_timeline == Constant.VERTICAL) {
          int rows = this.highest_branch_position - this.lowest_branch_position + 1;
          return this.graph_width / rows;
        } else {
          int rows = this.highest_branch_position - this.lowest_branch_position + 1;
          return this.graph_height / rows;
        }
      }
    }

    // Size of the allocation
    private int widget_width {
      get {
        return this.allocation.width - ((2 * this.padding) + 1);
      }
    }
    private int widget_height {
      get {
        return this.allocation.height - ((2 * this.padding) + 1);
      }
    }

    /*
     * The UUID of the current bit
     */
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

    /*
     * The UUID of the selected version
     */
    public string? selected_uuid {
      get {
        if (this.selected != null) {
          return this.selected.uuid;
        }
        return null;
      }
      set {
        if (this.selected.uuid == value) {
          return;
        }
        this.selected.selected = false;
        this.selected = null;
        foreach (var node in this.nodes) {
          if (node.uuid == value) {
            if (node.globbed) {
              this.selected = node.globbed_by;
            } else {
              this.selected = node;
              break;
            }
          }
        }
        if (this.selected != null) {
          this.scroll_to_timestamp(this.selected.timestamp);
        }
      }
    }

    /*
     * A signal emitted when the selection is changed
     */
    public signal void selection_changed ();

    /* Construct a timeline widget
     * @param: store, a wizbit store
     * @param: bit_uuid, a wiz-bit to open
     */
    public Timeline(Wiz.Store store, string? bit_uuid) {
      this.set_double_buffered(true);
      this.nodes                  = new List<Node>();
      this.tips                   = new List<Node>();
      this.branches               = new List<Branch>();
      this.store                  = store;
      this.bit_uuid               = bit_uuid;
      this.draw_scale             = true;
      this.padding                = 8;
      this.controls_height        = 20;
      this.handle_width           = 13;
      this.scale_padding          = 2;
      this.scale_height           = 20;
      this.easing_radius          = 1.1;
      this.do_render              = (int)Render.CONTROLS | 
                                    (int)Render.GRAPH |
                                    (int)Render.SCALE |
                                    (int)Render.BACKGROUND;
      stdout.printf("render...%d\n", this.do_render);
      this.orientation_timeline   = Constant.HORIZONTAL;
      this.orientation_controls   = Constant.HORIZONTAL;
      
      double h = Math.sqrt(2);
      double angle_n = Math.acos((h/2.0)/this.easing_radius);
      double angle = Math.PI - (2 * angle_n);
      double angle_r = (((Math.PI/2) - angle)/2);

      this.easing_diff            = (Math.cos(angle_r)*this.easing_radius) - 1;
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
      this.create_surfaces();
      this.do_render = (int)Render.CONTROLS | 
                       (int)Render.GRAPH |
                       (int)Render.SCALE |
                       (int)Render.BACKGROUND;
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
      // Initial positioning calculations, now that we know the widge size
      this.update_branch_positions();
      this.update_node_positions();
      this.create_surfaces();
    }

    public override void unrealize () {
      this.window.set_user_data (null);
    }

    private Node get_node(string uuid, bool prepend) {
      foreach (var node in this.nodes) {
        if (node.uuid == uuid) {
          return node;
        }
      }
      var node = new Node(uuid, this.commit_store.get_timestamp(uuid));
      if (prepend) {
        this.nodes.prepend(node);
      } else {
        this.nodes.append(node);
      }
      return node;
    }

    private void recurse_children (Node node, Branch branch) {
      node.branch = branch;
      if (this.branches.index(branch) < 0) {
        this.branches.append(branch);
      }

      var first_child = this.commit_store.get_forward(node.uuid);
      if (first_child == null) {
        node.node_type = NodeType.TIP;
        this.tips.append(node);
        return;
      }
      Node child_node = this.get_node(first_child, false);
      node.add_edge(child_node);
      this.recurse_children(child_node, branch);

      var children = this.commit_store.get_forwards(node.uuid);
      foreach (var child in children) {
        // All other children are on new branches
        if (child == first_child) { continue; }
        child_node = this.get_node(child, false);
        node.add_edge(child_node);
        this.recurse_children(child_node, new Branch(branch));
      }
    }

    private void update_from_store () {
      assert(this.commit_store != null);
      string child_uuid = "";
      string root = this.commit_store.get_root();
      string primary_tip = this.commit_store.get_primary_tip();
      this.primary_tip = this.get_node(primary_tip, false);
      this.tips.append(this.primary_tip);
      this.primary_tip.node_type = NodeType.PRIMARY_TIP;
      Node node = this.primary_tip;
      Branch branch = new Branch(null);
      this.branches.append(branch);
      branch.position = 0;

      // Step backward over parents until we hit the root
      while (true) {
        var children = this.commit_store.get_forwards(node.uuid);
        foreach (var child in children) {
          if (child == child_uuid) { continue; }
          var child_node = this.get_node(child, false);
          node.add_edge(child_node);
          this.recurse_children(child_node, new Branch(branch));
        }
        child_uuid = node.uuid;
        node.branch = branch;
        if (node.uuid == root) {
          this.root = node;
          this.root.node_type = NodeType.ROOT;
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
      int max_globbed = 0;
      this.calculate_zoom();
      foreach (var node in this.nodes) {
        r = node.timestamp - this.oldest_timestamp;
        position = (int)(((t - r) / t) * this.zoomed_extent);
        if (this.orientation_timeline == Constant.HORIZONTAL) {
          position = (int)this.zoomed_extent - position + (this.branch_width/2);
        }
        node.px_position = position;
      }
      this.edge_angle_max = 45.0;
      this.node_min_size = this.branch_width / 4;
      this.node_max_size = (this.branch_width / 2) - 4;
      foreach (var node in this.nodes) {
        foreach (var edge in node.edges) {
          if (edge.child != node) {
            continue;
          }
          if (edge.parent.branch.px_position == node.branch.px_position) {
            // distance between nodes..
            int node_dist = node.px_position - edge.parent.px_position;
            node.globbed_nodes = new List<Node>();
            if ((node_dist < ((int)this.node_min_size - 1)) && 
                (edge.parent.node_type != NodeType.ROOT)) {
              // TODO 7 This should only be set if the node only has one child
              edge.parent.globbed = true;
              edge.parent.globbed_by = node;
              node.globbed_nodes.append(edge.parent);
              foreach (var globbed_node in edge.parent.globbed_nodes) {
                globbed_node.globbed = true;
                globbed_node.globbed_by = node;
                node.globbed_nodes.append(globbed_node);
              }
              edge.parent.globbed_nodes = new List<Node>();
              if (node.globbed_nodes.length() > max_globbed) {
                max_globbed = (int)node.globbed_nodes.length();
              }
            } else {
              edge.parent.globbed = false;
              edge.parent.globbed_by = null;
            }
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
      if (max_globbed > 0) {
        this.node_glob_size = (this.node_max_size - this.node_min_size) / max_globbed;
      }
      this.do_render = this.do_render | (int)Render.GRAPH; 
    }

    /*
     * Update the timestamp's from where the position controls are.
     *
     */
    // TODO 8
    private void update_controls(int x) {
      int last_start = this.start_timestamp;
      int last_end = this.end_timestamp;
      if (this.grab_handle > (int)Handle.NONE) {
        var xpos = x - this.grab_offset;
        if (this.grab_handle == Handle.LIMIT_OLD) {
          this.start_timestamp = this.scale_pos_to_timestamp(xpos);
        } else if (this.grab_handle == Handle.LIMIT_NEW) {
          this.end_timestamp = this.scale_pos_to_timestamp(xpos);
        } else if (this.grab_handle == Handle.SLIDER) {
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
          this.calculate_zoom();
          this.do_render = this.do_render |  (int)Render.CONTROLS; 
        }
        int old_diff = last_end - last_start;
        int new_diff = this.end_timestamp - this.start_timestamp;
        if (old_diff != new_diff) {
          this.update_node_positions();
          this.do_render = this.do_render | (int)Render.BACKGROUND;
        }
      }
    }

    private void calculate_zoom() {
      double t = this.newest_timestamp - this.oldest_timestamp;
      double r = this.end_timestamp - this.start_timestamp;
      double offset = this.start_timestamp - this.oldest_timestamp;
      if (this.orientation_timeline == Constant.VERTICAL) {
        double graph_height = this.graph_height - this.branch_width;
        this.zoomed_extent = graph_height / (r / t);
        offset = this.zoomed_extent * (offset / t);
        this.offset = graph_height - this.zoomed_extent + offset;
      } else {
        double graph_width = this.graph_width - this.branch_width;
        this.zoomed_extent = graph_width / (r / t);
        offset = this.zoomed_extent * (offset / t);
        this.offset = this.zoomed_extent - offset - this.graph_width;
      }
    }
    /* Converts a timestamp into a scale horizontal position. */
    // TODO 8
    private int timestamp_to_scale_pos(int timestamp) {
      var range = this.newest_timestamp - this.oldest_timestamp;
      double pos = (double)(timestamp - this.oldest_timestamp) / (double)range;
      return (int)Math.ceil((pos * (double)this.widget_width) + this.padding + 0.5);
    }

    // TODO 8
    private int scale_pos_to_timestamp(int xpos) {
      double t = this.newest_timestamp - this.oldest_timestamp;
      double ratio = (xpos - this.padding + 0.5) / (this.widget_width);
      return (int) Math.ceil((t * ratio) + this.oldest_timestamp);
    }

    private int graph_pos_to_timestamp(int px_pos, double offset) {
      double t = this.newest_timestamp - this.oldest_timestamp;
      offset = this.zoomed_extent - (offset + this.graph_width);
      px_pos = px_pos + this.padding + (int)offset;
      double ratio = px_pos / this.zoomed_extent;
      return (int) Math.ceil(this.oldest_timestamp + (t * ratio));
    }

    // Get the tick timestamp equal to are larger than start timestamp
    private int get_lowest_scale_timestamp(int start_timestamp, TimeUnit unit) {
      Time t = Time.gm((time_t) start_timestamp);
      t.second = 0;
      if (unit == TimeUnit.MINUTES) {
        t.minute = t.minute + 1;
      } else if (unit == TimeUnit.HOURS) {
        t.minute = 0;
        t.hour = t.hour + 1;
      } else if (unit == TimeUnit.DAYS) {
        t.minute = 0;
        t.hour = 0;
        t.day = t.day + 1;
      } else if (unit == TimeUnit.WEEKS) {
        t.minute = 0;
        t.hour = 0;
        return ((int)t.mktime() + ((6 - t.weekday) * 60 * 60 * 24));
      } else if (unit == TimeUnit.MONTHS) {
        t.minute = 0;
        t.hour = 0;
        t.day = 0;
        t.month = t.month + 1;
      } else if (unit == TimeUnit.YEARS) {
        t.minute = 0;
        t.hour = 0;
        t.day = 0;
        t.month = 0;
        t.year = t.year + 1;
      }
      return (int)t.mktime();
    }

    // Get the tick timestamp equal to are larger than start timestamp
    private int get_highest_scale_timestamp(int end_timestamp, TimeUnit unit) {
      Time t = Time.gm((time_t) end_timestamp);
      t.second = 0;
      if (unit == TimeUnit.HOURS) {
        t.minute = 0;
      } else if (unit == TimeUnit.DAYS) {
        t.minute = 0;
        t.hour = 0;
      } else if (unit == TimeUnit.MONTHS) {
        t.minute = 0;
        t.hour = 0;
        t.day = 0;
      } else if (unit == TimeUnit.WEEKS) {
        t.minute = 0;
        t.hour = 0;
        return ((int)t.mktime() - ((t.weekday-6) * 60 * 60 * 24));
      } else if (unit == TimeUnit.YEARS) {
        t.minute = 0;
        t.hour = 0;
        t.day = 0;
        t.month = 0;
      }
      return (int)t.mktime();
    }

    private int get_next_scale_timestamp(int timestamp, TimeUnit unit) {
      if (unit == TimeUnit.MINUTES) {
        return timestamp + 60;
      } else if (unit == TimeUnit.HOURS) {
        return timestamp + (60 * 60);
      } else if (unit == TimeUnit.DAYS) {
        return timestamp + (60 * 60 * 24);
      } else if (unit == TimeUnit.WEEKS) {
        Time t = Time.gm((time_t) timestamp);
        if (t.weekday == 1) {
          return timestamp + (60 * 60 * 24 * 5);
        } else {
          return timestamp + (60 * 60 * 24 * 2);
        }
      } else if (unit == TimeUnit.MONTHS) {
        Time t = Time.gm((time_t) timestamp);
        t.month = t.month + 1;
        return (int)t.mktime();
      } else if (unit == TimeUnit.YEARS) {
        return timestamp + (60 * 60 * 24 * 365);
      }
      return 0;
    }

    // Returns the best scale unit for the range of time between start and
    // end timestamps.
    private TimeUnit get_scale_unit(int start_timestamp, int end_timestamp) {
      int t = end_timestamp - start_timestamp;
      // This isn't the best way to do this but nevermind :/
      if (t < 60 * 60 ) {
        return TimeUnit.MINUTES;
      } else if (t < 60 * 60 * 24) {
        return TimeUnit.HOURS;
      } else if (t < 60 * 60 * 24 * 7) {
        return TimeUnit.DAYS;
      } else if (t < 60 * 60 * 24 * 30) {
        return TimeUnit.WEEKS;
      } else if (t < 60 * 60 * 24 * 365) {
        return TimeUnit.MONTHS;
      }
      return TimeUnit.YEARS;
    }

    private bool pan_to_timestamp(int timestamp) {
      int pan_diff = (timestamp - this.pan_cursor_timestamp);
      int diff = this.end_timestamp - this.start_timestamp;
      bool ret = true;
      this.start_timestamp = this.pan_start_timestamp - pan_diff;
      this.end_timestamp = this.start_timestamp + diff;

      if (this.start_timestamp < this.oldest_timestamp) {
        this.start_timestamp = this.oldest_timestamp;
        this.end_timestamp = this.start_timestamp + diff;
        ret = false;
      }
      if (this.end_timestamp > this.newest_timestamp) {
        this.end_timestamp = this.newest_timestamp;
        this.start_timestamp = this.end_timestamp - diff;
        ret = false;
      }
      this.calculate_zoom();
      this.do_render = this.do_render | (int)Render.CONTROLS;
      this.queue_draw();
      return ret;
    }

    private bool move_to_timestamp(int timestamp) {
      int diff = (this.end_timestamp - this.start_timestamp) / 2;
      if (this.start_timestamp + diff == timestamp) {
        return false;
      }
      this.start_timestamp = timestamp - diff;
      this.end_timestamp = timestamp + diff;

      if (this.start_timestamp < this.oldest_timestamp) {
        this.start_timestamp = this.oldest_timestamp;
        this.end_timestamp = this.start_timestamp + (diff * 2);
      }
      if (this.end_timestamp > this.newest_timestamp) {
        this.end_timestamp = this.newest_timestamp;
        this.start_timestamp = this.end_timestamp - (diff * 2);
      }
      this.calculate_zoom();
      this.do_render = this.do_render | (int)Render.CONTROLS;
      this.queue_draw();
      return true;
    }

    private bool scroll_tick() {
      double t;
      TimeVal tv = TimeVal();
      tv.get_current_time();
      t = ((double)tv.tv_usec/1000000)+tv.tv_sec;
      t = t - this.anim_start_time;
      t = (t/this.anim_duration);

      double b = 1 - t + this.easing_diff;
      double angle_b = Math.acos(b/this.easing_radius);
      double a = Math.sin(angle_b) * this.easing_radius;
      double d = a - this.easing_diff;
      int diff = this.anim_end_timestamp - this.anim_start_timestamp;

      this.move_to_timestamp( this.anim_start_timestamp + (int)(diff * d) );
      if ((t > 1) || this.mouse_down) {
        return false;
      } else {
        return true;
      }
    }

    private void scroll_to_timestamp(int timestamp) {
      int diff = (this.end_timestamp - this.start_timestamp) / 2;

      this.anim_start_timestamp = this.start_timestamp + diff;

      if (timestamp > this.newest_timestamp - diff) {
        timestamp = this.newest_timestamp - diff;
      }
      if (timestamp < this.oldest_timestamp + diff) {
        timestamp = this.oldest_timestamp + diff;
      }
      this.anim_end_timestamp = timestamp;
      TimeVal t = TimeVal();
      t.get_current_time();
      this.anim_start_time = ((double)t.tv_usec/1000000)+t.tv_sec;
      this.anim_duration = (double)(this.anim_end_timestamp - this.anim_start_timestamp);
      this.anim_duration = (this.anim_duration/diff)*2;
      if (this.anim_duration < 0) { this.anim_duration = this.anim_duration * -1; }
      Timeout.add (30, scroll_tick);
    }

    // TODO 8
    private bool kinetic_tick() {
      if ((int)this.velocity > -20 && (int)this.velocity < 20 || this.mouse_down) {
        return false;
      }

      double t;
      TimeVal tv = TimeVal();
      tv.get_current_time();
      t = ((double)tv.tv_usec/1000000)+tv.tv_sec;

      double tmp = t - this.kinetic_last_tick_timestamp;
      this.kinetic_last_tick_timestamp = t;
      t = tmp;

      double seconds = t;
      double dist = seconds * (this.velocity);
      this.total_distance_travelled = this.total_distance_travelled + (int) dist;

      int px_pos = (int)(this.mouse_release_x - this.total_distance_travelled);
      int timestamp = this.graph_pos_to_timestamp(px_pos, this.pan_offset);
      this.pan_to_timestamp(timestamp);
      this.velocity = this.velocity * 0.95;
      return true;
    }

    private void kinetic_scroll() {
      TimeVal t = TimeVal();
      t.get_current_time();
      int dist = 0;
      this.kinetic_end_timestamp = ((double)t.tv_usec/1000000)+t.tv_sec;
      if (this.orientation_timeline == Constant.HORIZONTAL) {
        dist = this.mouse_press_x - this.mouse_release_x;
      } else {
        dist = this.mouse_press_y - this.mouse_release_y;
      }
      this.velocity = dist/(this.kinetic_end_timestamp - this.kinetic_start_timestamp);
      this.pan_offset = this.offset;
      int timestamp = this.graph_pos_to_timestamp(this.mouse_release_x, this.pan_offset);
      this.pan_start_timestamp = this.start_timestamp;
      this.pan_cursor_timestamp = timestamp;
      this.total_distance_travelled = 0;
      this.kinetic_last_tick_timestamp = this.kinetic_end_timestamp;
      this.pan_to_timestamp(timestamp);
      Timeout.add(30, kinetic_tick);
    }

    // TODO 8
    public override bool button_press_event (Gdk.EventButton event) {
      this.mouse_down = true;
      this.mouse_press_x = (int)event.x;
      this.mouse_press_y = (int)event.y;
      this.mouse_last_x = (int)event.x;
      this.mouse_last_y = (int)event.y;
      // These numbers are based on the size of the handles?!
      var st = this.timestamp_to_scale_pos(this.start_timestamp) - 5;
      var et = this.timestamp_to_scale_pos(this.end_timestamp) + 5;
      var sv = this.widget_height - this.scale_height - this.scale_padding - this.controls_height + this.padding;
      var ev = this.widget_height - this.scale_height - this.scale_padding + this.padding;
      this.velocity = 0;

      // Cursor over the controls
      if (this.mouse_press_y > sv &&
          this.mouse_press_y < ev &&
          this.mouse_press_x >= st &&
          this.mouse_press_x <= et ) {
        // figure out which part of the control we're over
        if (this.mouse_press_x <= st + 10) {
          // Over left handle
          this.grab_handle = Handle.LIMIT_OLD;
          this.grab_offset = this.mouse_press_x - st;
        } else if (this.mouse_press_x >= et - 10) {
          // Over right handle
          this.grab_handle = Handle.LIMIT_NEW;
          this.grab_offset = this.mouse_press_x - et;
        } else {
          // Over the slider bar
          this.grab_handle = Handle.SLIDER;
          this.grab_offset = this.mouse_press_x - (st + ((et - st)/2));
        }
      // Cursor over the graph
      } else if ((this.mouse_press_x > this.padding) &&
                 (this.mouse_press_x < this.graph_width + this.padding) &&
                 (this.mouse_press_y > this.padding) &&
                 (this.mouse_press_y < this.graph_height + this.padding)) {
        this.grab_handle = Handle.KINETIC;
        this.mouse_direction = 0;
        TimeVal t = TimeVal();
        t.get_current_time();
        this.kinetic_start_timestamp = ((double)t.tv_usec/1000000)+t.tv_sec;
        this.pan_offset = this.offset;
        this.pan_cursor_timestamp = this.graph_pos_to_timestamp(this.mouse_press_x, this.pan_offset);
        this.pan_start_timestamp = this.start_timestamp;
        this.pan_to_timestamp(this.pan_cursor_timestamp);
      } else {
        this.grab_handle = Handle.NONE;
      }
      stdout.printf("Grab %d\n", this.grab_handle);
      return true;
    }

    public override bool button_release_event (Gdk.EventButton event) {
      this.mouse_down = false;
      this.mouse_release_x = (int)event.x;
      this.mouse_release_y = (int)event.y;
      if (this.grab_handle > (int)Handle.KINETIC) {
        // TODO 8 - update controls should pick point by orientation
        this.update_controls(this.mouse_release_x);
        this.queue_draw();
      } else if (Gtk.drag_check_threshold(this, this.mouse_press_x,
                                                this.mouse_press_y,
                                                this.mouse_release_x,
                                                this.mouse_release_y) &&
                 (this.grab_handle == (int)Handle.KINETIC)) {
        this.kinetic_scroll();
      } else {
        Node last = this.selected;
        this.selected = null;
        foreach (var node in this.nodes) {
          if (node.at_coords(this.mouse_release_x, this.mouse_release_y,
                             this.orientation_timeline,
                             (int)(this.offset+(this.branch_width/2)),this.padding)) {
            if (node != last) {
              this.selected = node;
              this.selected.selected = true;
            } else {
              this.selected = node;
            }
            break;
          }
        }
        if (this.selected.globbed) {
          this.selected.selected = false;
          this.selected = this.selected.globbed_by;
          this.selected.selected = true;
        }
        if (this.selected != last) {
          last.selected = false;
          this.selection_changed();
          if (this.selected != null) {
            this.scroll_to_timestamp(this.selected.timestamp);
          }
          this.queue_draw();
        }
      }
      this.grab_handle = Handle.NONE;
      return true;
    }

    // TODO 8
    public override bool motion_notify_event (Gdk.EventMotion event) {
      bool ret = false;
      int direction;
      if (this.mouse_down) {  
        if (this.grab_handle > (int)Handle.KINETIC) {
          if (event.x != this.mouse_press_x) {
            this.update_controls((int)event.x);
            this.queue_draw();
          }
          ret = true;
        } else if (this.grab_handle == (int)Handle.KINETIC) {
          int timestamp = this.graph_pos_to_timestamp(((int)event.x), this.pan_offset);
          this.pan_to_timestamp(timestamp);
          direction = this.mouse_direction;
          if (this.orientation_timeline == Constant.VERTICAL) {
            this.mouse_direction = this.mouse_last_y - (int)event.y;
          } else {
            this.mouse_direction = this.mouse_last_x - (int)event.x;
          }
          if (this.mouse_direction > 0) {
            this.mouse_direction = 1;
          } else if (this.mouse_direction < 0) {
            this.mouse_direction = -1;
          }
          if (direction != this.mouse_direction && this.mouse_direction != 0) {
            this.mouse_press_x = (int)event.x;
            this.mouse_press_y = (int)event.y;            
            TimeVal t = TimeVal();
            t.get_current_time();
            this.kinetic_start_timestamp = ((double)t.tv_usec/1000000)+t.tv_sec;
            stdout.printf("Direction change %d\n", this.mouse_direction);
          }
          ret = true;
        }
        this.mouse_last_x = (int)event.x;
        this.mouse_last_y = (int)event.y;
      }
      return ret;
    }

    // TODO 3
    public override bool expose_event (Gdk.EventExpose event) {
      this.cr = Gdk.cairo_create (this.window);
      if ((this.do_render & (int)Render.CONTROLS) == (int)Render.CONTROLS) {
        this.render_controls();
      }
      if ((this.do_render & (int)Render.GRAPH) == (int)Render.GRAPH) {
        this.render_graph();
      }
      if ((this.do_render & (int)Render.SCALE) == (int)Render.SCALE) {
        this.render_scale();
      }
      if ((this.do_render & (int)Render.BACKGROUND) == (int)Render.BACKGROUND) {
        this.render_background();
      }
      this.composite();
      this.do_render = 0;
      return true;
    }

    private void render_background() {    
      int graph_width = 0;
      int graph_height = 0;
      if (this.orientation_timeline == Constant.VERTICAL) {
        graph_width     = this.graph_width;
        graph_height    = (int)this.zoomed_extent + (int)(1.5*this.branch_width);
      } else {
        graph_width     = (int)this.zoomed_extent + (int)(1.5*this.branch_width);
        graph_height    = this.graph_height;
      }

      this.cr_background = new Cairo.Context(
                             new Cairo.Surface.similar(this.cr.get_group_target(),
                                                       Cairo.Content.COLOR,
                                                       graph_width,
                                                       graph_height)
                           );
      Cairo.Context cr_tmp = new Cairo.Context(
                               new Cairo.Surface.similar(this.cr.get_group_target(),
                                                         Cairo.Content.COLOR_ALPHA,
                                                         graph_width,
                                                         graph_height)
                             );
      this.cr_background.set_source_rgb(0xee/255.0, 0xee/255.0, 0xec/255.0);
      this.cr_background.paint();
      TimeUnit scaleunit = this.get_scale_unit(this.start_timestamp,
                                               this.end_timestamp);
      double t = this.newest_timestamp - this.oldest_timestamp;
      double r = this.end_timestamp - this.start_timestamp;
      int timestamp = get_highest_scale_timestamp(this.oldest_timestamp, scaleunit);
      int end_timestamp = get_highest_scale_timestamp(this.newest_timestamp, scaleunit);
      end_timestamp = get_next_scale_timestamp(end_timestamp, scaleunit);
      int px_pos, px_width = 0;
      double [] dash = new double[2];
      Pango.Layout layout;
      int fontw, fonth;
      string unit = null;

      dash[0] = 1.5;
      dash[1] = 2.0;
      this.cr_background.save();
      this.cr_background.set_dash(dash, 2);
      this.cr_background.set_line_width(1);
      this.cr_background.set_source_rgba(0.0,0.0,0.0, 0.4);
      while (timestamp <= end_timestamp) {
        unit = null;
        r = timestamp - this.oldest_timestamp;
        px_pos = (int)(((t - r) / t) * this.zoomed_extent);
        if (this.orientation_timeline == Constant.VERTICAL) {
          this.cr_background.move_to((this.graph_width/2) + 0.5, px_pos + 0.5);
          this.cr_background.line_to((this.graph_width/2) + 8.5, px_pos + 0.5);
          this.cr_background.stroke();
        } else {
          px_pos = (int)this.zoomed_extent - px_pos;
          Time tm = Time.gm((time_t) timestamp);

          if (scaleunit == TimeUnit.MINUTES) {
            unit = tm.format("%H:%M");
          } else if (scaleunit == TimeUnit.HOURS) {
            unit = tm.format("%H:00");
          } else if (scaleunit == TimeUnit.DAYS) {
            unit = tm.format("%A");
          } else if (scaleunit == TimeUnit.WEEKS) {
            if (tm.weekday == 6) {
              r = 60 * 60 * 24 * 2;
              px_width = (int)(((r / t) * this.zoomed_extent) + 1);
              this.cr_background.save();
              this.cr_background.rectangle(px_pos, 0, px_width, this.graph_height);
              this.cr_background.set_source_rgba(0,0,0,0.06);
              this.cr_background.fill();
              this.cr_background.restore();
            } else if (tm.weekday == 1) {
              unit = tm.format("Week %V %G");
              r = 60 * 60 * 24 * 2.5;
              px_width = (int)(((r / t) * this.zoomed_extent) + 1);
            }
          } else if (scaleunit == TimeUnit.MONTHS) {
            unit = tm.format("%B");
          } else if (scaleunit == TimeUnit.YEARS) {
            unit = tm.format("%G");
          } else {
            unit = null;
          }

          this.cr_background.save();
          this.cr_background.set_source_rgba(0,0,0,1);
          this.cr_background.move_to(px_pos+0.5, 0);
          this.cr_background.line_to(px_pos+0.5, this.graph_height);
          this.cr_background.stroke();
          this.cr_background.restore();

          if (unit != null) {
            layout = this.create_pango_layout (unit);
            layout.get_pixel_size (out fontw, out fonth);
            cr_tmp.move_to (px_pos + px_width - (fontw/2), 0);
            cr_tmp.set_source_rgba(0,0,0,0.4);
            Pango.cairo_update_layout (cr_tmp, layout);
            Pango.cairo_show_layout (cr_tmp, layout);
          }
        }
        timestamp = get_next_scale_timestamp(timestamp, scaleunit);
      }

      this.cr_background.set_source_rgba(0,0,0,1);
      if (this.orientation_timeline == Constant.VERTICAL) {
        //TODO 8
      } else {
        int steps = (this.highest_branch_position - this.lowest_branch_position);

        for (var i = 1; i <= steps; i++) {
          this.cr_background.move_to(0, (i*this.branch_width)+0.5);
          this.cr_background.line_to(this.zoomed_extent + this.branch_width,
                                     (i*this.branch_width)+0.5);
        }
      }
      this.cr_background.stroke();
      this.cr_background.restore();

      if (scaleunit != TimeUnit.WEEKS) {
        this.cr_background.save();
        var pattern = new Cairo.Pattern.linear(0, 12, 0, 35);
        pattern.add_color_stop_rgba(0, 0xee/255.0, 0xee/255.0, 0xec/255.0, 1);
        pattern.add_color_stop_rgba(1, 0xee/255.0, 0xee/255.0, 0xec/255.0, 0);
        this.cr_background.set_source (pattern);
        this.cr_background.rectangle(0,0,this.zoomed_extent + this.branch_width, this.graph_height); // TODO 8
        this.cr_background.fill();
        this.cr_background.restore();
      }
      this.cr_background.set_source_surface(cr_tmp.get_group_target(), 0, 0);
      this.cr_background.paint();
    }

    // TODO 3
    private void render_scale() {
      TimeUnit scaleunit = this.get_scale_unit(this.oldest_timestamp,
                                               this.newest_timestamp);
      TimeUnit graphunit = (TimeUnit)((int)scaleunit - 1);
      int timestamp = get_highest_scale_timestamp(this.oldest_timestamp, graphunit);
      int next_timestamp;
      int graphheight;
      int topheight = 0;
      int px_pos;
      int px_end;
      double gap;

      this.cr_scale.set_line_width(1);
      this.cr_scale.save();
      if (this.orientation_controls == Constant.VERTICAL) {
        // TODO 8
      } else {
        this.cr_scale.rectangle(0.5, 4.5, this.widget_width, 15);
        this.cr_scale.set_source_rgba(0.0,0.12,0.4,0.6);
        this.cr_scale.stroke();
        this.cr_scale.rectangle(0, 0, this.widget_width, 20);
        this.cr_scale.clip();
      }

      while (timestamp < this.newest_timestamp) {
        next_timestamp = get_next_scale_timestamp(timestamp, graphunit);
        graphheight = this.commit_store.get_commits_between_timestamps(timestamp, next_timestamp);
        if (graphheight > topheight) {
          topheight = graphheight;
        }
        timestamp = next_timestamp;
      }
      gap = 15.0 / topheight;

      timestamp = get_highest_scale_timestamp(this.oldest_timestamp, graphunit);
      while (timestamp < this.newest_timestamp) {
        px_pos = timestamp_to_scale_pos(timestamp);
        next_timestamp = get_next_scale_timestamp(timestamp, graphunit);
        px_end = timestamp_to_scale_pos(next_timestamp);
        graphheight = this.commit_store.get_commits_between_timestamps(timestamp, next_timestamp);
        if (this.orientation_controls == Constant.VERTICAL) {
          // TODO 8
        } else {
          this.cr_scale.rectangle(px_pos + 2.5, 15 - (int)(graphheight * gap) + 4.5,
                       px_end - px_pos -4, (int)(graphheight * gap));
        }
        timestamp = next_timestamp;
      }
      this.cr_scale.set_source_rgba(0.0,0.12,0.4,0.2);
      this.cr_scale.fill_preserve();
      this.cr_scale.set_source_rgba(0.0,0.12,0.4,0.4);
      this.cr_scale.stroke();
      this.cr_scale.restore();
      timestamp = get_lowest_scale_timestamp(this.oldest_timestamp, scaleunit);
      while (timestamp < this.newest_timestamp) {
        px_pos = timestamp_to_scale_pos(timestamp);
        if (this.orientation_controls == Constant.VERTICAL) {
          // TODO 8
        } else {
          this.cr_scale.move_to(px_pos + 0.5, 0);
          this.cr_scale.line_to(px_pos + 0.5, this.scale_height);
        }
        timestamp = get_next_scale_timestamp(timestamp, scaleunit);
      }
      this.cr_scale.set_source_rgba(0.0,0.12,0.4,0.6);
      this.cr_scale.stroke();
    }

    // TODO 8
    private void render_controls_handle(int timestamp) {
      double hhw = (double)this.handle_width / 2.0;

      var hpos = this.timestamp_to_scale_pos(timestamp);
      // Handle outline
      this.cr_controls.move_to(hpos - hhw, 0.5);
      this.cr_controls.line_to(hpos - hhw, (double)this.controls_height - 5.5);
      this.cr_controls.line_to(hpos, (double)this.controls_height - 0.5);
      this.cr_controls.line_to(hpos + hhw, (double)this.controls_height - 5.5);
      this.cr_controls.line_to(hpos + hhw, 0.5);
      this.cr_controls.line_to(hpos - hhw, 0.5);
      // Handle fill
      var pattern = new Cairo.Pattern.linear(hpos - 4.5, 0, hpos + 4.5, 0);
      pattern.add_color_stop_rgb(0, 0xee/255.0, 0xee/255.0, 0xec/255.0);
      pattern.add_color_stop_rgb(1, 0x88/255.0, 0x8a/255.0, 0x85/255.0);

      this.cr_controls.set_source (pattern);
      this.cr_controls.fill_preserve();
      this.cr_controls.set_source_rgb(0x55/255.0, 0x57/255.0, 0x53/255.0);
      this.cr_controls.stroke();

      hhw = hhw - 1;
      // Handle inner highlight
      this.cr_controls.move_to(hpos - hhw, 1.5);
      this.cr_controls.line_to(hpos - hhw, (double)this.controls_height - 6.15);
      this.cr_controls.line_to(hpos, this.controls_height - 2);
      this.cr_controls.line_to(hpos + hhw, (double)this.controls_height - 6.15);
      this.cr_controls.line_to(hpos + hhw, 1.5);
      this.cr_controls.line_to(hpos - hhw, 1.5);

      this.cr_controls.set_source_rgba(0xff/255.0,0xff/255.0,0xff/255.0, 20/100.0);
      this.cr_controls.stroke();
    }

    // TODO 8
    private void render_controls_slider() {
      var pattern = new Cairo.Pattern.linear(0, 3.5, 0, 9.5);
      pattern.add_color_stop_rgb(0, 0x88/255.0, 0x8a/255.0, 0x85/255.0);
      pattern.add_color_stop_rgb(1, 0xee/255.0, 0xee/255.0, 0xec/255.0);
      this.cr_controls.rectangle(0.5 + this.padding, 3.5, this.widget_width, 6.0);
      this.cr_controls.set_line_width(1);
      this.cr_controls.set_source (pattern);
      this.cr_controls.fill_preserve();
      this.cr_controls.set_source_rgb(0x55/255.0, 0x57/255.0, 0x53/255.0);
      this.cr_controls.stroke();

      int start_pos = this.timestamp_to_scale_pos(this.start_timestamp);
      int end_pos = this.timestamp_to_scale_pos(this.end_timestamp);
      double center = (this.end_timestamp - this.start_timestamp)/2;
      center = center + this.start_timestamp;
      center = (double)this.timestamp_to_scale_pos((int)center) - 3.5;

      this.cr_controls.rectangle (start_pos + 4.5, 0.5, end_pos - start_pos - 9, (double)this.controls_height - 6);
      pattern = new Cairo.Pattern.linear(0, 0.5, 0, (double)this.controls_height - 6);
      pattern.add_color_stop_rgb(0, 0x72/255.0,0x9f/255.0,0xcf/255.0);
      pattern.add_color_stop_rgb(1, 0x34/255.0,0x65/255.0,0xa4/255.0);
      this.cr_controls.set_source (pattern);
      this.cr_controls.fill_preserve();
      this.cr_controls.set_source_rgb(0x20/255.0,0x4a/255.0,0x87/255.0);
      // Render some ticks in the middle of the slider
      for (var i = 0; i < 3; i++) {
        this.cr_controls.move_to(center + (i * 3), 3.5);
        this.cr_controls.line_to(center + (i * 3), (double)this.controls_height - 9);
      }
      this.cr_controls.stroke();
      // Slider Highlight
      this.cr_controls.set_source_rgba(0xff/255.0,0xff/255.0,0xff/255.0, 20/100.0);
      this.cr_controls.rectangle (start_pos + 5.5, 1.5,
                    end_pos - start_pos - 11, (double)this.controls_height - 8);
      this.cr_controls.stroke();
    }

    private void render_controls() {
      this.cr_controls.set_operator(Cairo.Operator.CLEAR);
      this.cr_controls.paint();
      this.cr_controls.set_operator(Cairo.Operator.OVER);
      this.render_controls_slider();
      this.render_controls_handle(this.start_timestamp);
      this.render_controls_handle(this.end_timestamp);
    }

    private void render_graph() {
      int graph_width = 0;
      int graph_height = 0;
      if (this.orientation_timeline == Constant.VERTICAL) {
        graph_width     = this.graph_width;
        graph_height    = (int)this.zoomed_extent + (int)(1.5*this.branch_width);
      } else {
        graph_width     = (int)this.zoomed_extent + (int)(1.5*this.branch_width);
        graph_height    = this.graph_height;
      }

      this.cr_edges = new Cairo.Context(
                        new Cairo.Surface.similar(this.cr.get_group_target(),
                                                  Cairo.Content.COLOR_ALPHA,
                                                  graph_width,
                                                  graph_height)
                      );

      this.cr_nodes = new Cairo.Context(
                        new Cairo.Surface.similar(this.cr.get_group_target(),
                                                  Cairo.Content.COLOR_ALPHA,
                                                  graph_width,
                                                  graph_height)
                      );

      foreach (var node in this.nodes) {
        foreach (var edge in node.edges) {
          if (edge.child == node) {
            edge.render(this.cr_edges, this.edge_angle_max, this.orientation_timeline);
          }
        }
        if (!node.globbed) {
          node.size = (node.globbed_nodes.length() * this.node_glob_size) + this.node_min_size;
          node.render(this.cr_nodes, this.orientation_timeline);
        }
      }
      // TODO 12
      this.cr_edges.set_line_width(2);
      this.cr_edges.set_source_rgb(0.4,0,0);
      this.cr_edges.stroke();
    }

    private void create_surfaces() {
      this.cr = Gdk.cairo_create (this.window);
      var surface = this.cr.get_group_target();
      int controls_width = 0;
      int controls_height = 0;
      int scale_width = 0;
      int scale_height = 0;

      if (this.orientation_timeline == Constant.VERTICAL) {
        controls_height = this.widget_height + 1 + this.handle_width;
        controls_width  = this.controls_height;
        scale_height    = this.widget_height + 1;
        scale_width     = this.scale_height;
      } else {
        controls_height = this.controls_height;
        controls_width  = this.allocation.width + 1;
        scale_height    = this.scale_height;
        scale_width     = this.widget_width + 1;
      }

      this.cr_controls = new Cairo.Context(
                           new Cairo.Surface.similar(surface,
                                                     Cairo.Content.COLOR_ALPHA,
                                                     controls_width,
                                                     controls_height)
                         );
      this.cr_scale = new Cairo.Context(
                        new Cairo.Surface.similar(surface,
                                                  Cairo.Content.COLOR_ALPHA,
                                                  scale_width,
                                                  scale_height)
                      );
    }

    private void composite() {
      double gx = this.padding;
      double gy = this.padding;
      double cx = 0;
      double cy = 0;
      int cw = 0;
      int ch = 0;
      double sx = this.padding;
      double sy = this.padding;
      int sw = 0;
      int sh = 0;

      if (this.orientation_timeline == Constant.VERTICAL) {
        gy =  this.padding - (this.zoomed_extent - this.offset - this.graph_height); // TODO 8
        cx = (this.padding*2) + this.graph_width;
        sx = cx + this.controls_height + this.scale_padding;
        cw = this.controls_height;
        ch = this.allocation.height + 1;
        sw = this.scale_height;
        sh = this.widget_height + 1;
      } else {
        gx = this.padding - (this.zoomed_extent - this.offset - this.graph_width);
        cy = (this.padding*2) + this.graph_height;
        sy = cy + this.controls_height + this.scale_padding;
        cw = this.allocation.width + 1;
        ch = this.controls_height;
        sw = this.widget_width + 1;
        sh = this.scale_height;
      }

      this.cr.set_source_surface(this.cr_background.get_group_target(), gx, gy);
      this.cr.rectangle(this.padding, this.padding, this.graph_width, this.graph_height);
      this.cr.fill();

      this.cr.set_source_surface(this.cr_edges.get_group_target(), gx, gy);
      this.cr.rectangle(this.padding, this.padding, this.graph_width, this.graph_height);
      this.cr.fill();

      this.cr.set_source_surface(this.cr_nodes.get_group_target(), gx, gy);
      this.cr.rectangle(this.padding, this.padding, this.graph_width, this.graph_height);
      this.cr.fill();

      this.cr.set_line_width(1);
      this.cr.rectangle(this.padding + 0.5, this.padding + 0.5, 
                        this.graph_width, this.graph_height);
      this.cr.set_source_rgb(0.0,0.0,0.0);
      this.cr.stroke();

      this.cr.set_source_surface(this.cr_controls.get_group_target(), cx, cy);
      this.cr.rectangle(cx, cy, cw, ch);
      this.cr.fill();

      this.cr.set_source_surface(this.cr_scale.get_group_target(), sx, sy);
      this.cr.rectangle(sx, sy, sw, sh);
      this.cr.fill();
    }
  }
}
