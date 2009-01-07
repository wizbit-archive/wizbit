using GLib;
using Gtk;
using Wiz;
using WizWidgets;

public class Test.Widget : GLib.Object {
  public static Gtk.Label label;
  public static Wiz.Store store;
  public static Wiz.Bit bit;
  public static WizWidgets.Timeline timeline;

  public static void selection_changed() {
    stdout.printf("SELECTION CHANGED\n");
    string selected_uuid = timeline.selected_uuid;
    stdout.printf("%s\n", selected_uuid);
    //Wiz.Version ver = bit.open_version(selected_uuid);
    //string text = ver.read_as_string();
    label.set_text(selected_uuid);
  }

  public static void main(string[] args) {
	  Gtk.init (ref args);

	  Gtk.Window win = new Gtk.Window (Gtk.WindowType.TOPLEVEL);
	  win.set_border_width (5);
	  win.set_title ("Wizbit Timeline Widget");
	  win.destroy += Gtk.main_quit;
    store = new Wiz.Store("repo_uuid", "data/wiz_store");
    if (store.has_bit("WIZBIT_TIMELINE")) {
      bit = store.open_bit("WIZBIT_TIMELINE");
    } else {
      bit = store.open_bit("WIZBIT_TIMELINE");
    	assert( bit != null );
	    /* Create a branching history which will look good, need to forge the
	     * timestamps to give it good positioning to test everything
	     *
	     */

	    Wiz.Version a, b, c, d; // Branches
	    stdout.printf("Creating a faux history\n");
	    bit.test_create_next_version_from_string("FOO", null, 1225274400);            // ROOT
	    bit.test_create_next_version_from_string("BAR", bit.primary_tip, 1225359400); // NODE x
	    bit.test_create_next_version_from_string("BAR", bit.primary_tip, 1225360800); // NODE 1
	    bit.test_create_next_version_from_string("QUX", bit.primary_tip, 1225447200); // NODE 2
      b = bit.primary_tip;
      c = bit.primary_tip;
	    bit.test_create_next_version_from_string("QUUX", bit.primary_tip, 1225558800);// NODE 3
      a = bit.primary_tip;
      d = bit.primary_tip;

	    bit.test_create_next_version_from_string("BAZ", b, 1225620000);               // NODE 4
      b = bit.primary_tip;

	    bit.test_create_next_version_from_string("CORGE", d, 1225620600);             // NODE 5
      d = bit.primary_tip;

	    bit.test_create_next_version_from_string("CORGE", c, 1225706400);             // TIP 1

	    bit.test_create_next_version_from_string("GRAULT", b, 1225707000);            // Node 6
      b = bit.primary_tip;

	    bit.test_create_next_version_from_string("BAZ", d, 1225707600);               // NODE 7
      d = bit.primary_tip;
	    bit.test_create_next_version_from_string("BAZ", d, 1225792800);               // TIP 2

	    bit.test_create_next_version_from_string("BAZ", b, 1225879200);               // NODE 8
      b = bit.primary_tip;

	    bit.test_create_next_version_from_string("GRAULT", a, 1225879800);            // NODE 9
      a = bit.primary_tip;
      d = bit.primary_tip;

	    bit.test_create_next_version_from_string("CORGE", d, 1225904400);             // NODE 10
      d = bit.primary_tip;
	    bit.test_create_next_version_from_string("CORGE", d, 1225924600);             // TIP 3
      d = bit.primary_tip;
	    bit.test_create_next_version_from_string("CORGE", d, 1225938600);             // TIP 3
      d = bit.primary_tip;
	    bit.test_create_next_version_from_string("CORGE", d, 1225965600);             // TIP 3
      d = bit.primary_tip;
	    bit.test_create_next_version_from_string("CORGE", d, 1225969600);             // NODE 10
      d = bit.primary_tip;
	    bit.test_create_next_version_from_string("CORGE", d, 1225978600);             // NODE 10


	    bit.test_create_next_version_from_string("GRAULT", b, 1225966200);            // TIP 4

	    bit.test_create_next_version_from_string("CORGE", a, 1225990800);             // NODE 11
      a = bit.primary_tip;
	    bit.test_create_next_version_from_string("CORGE", a, 1225992800);             // NODE 11
      a = bit.primary_tip;
	    bit.test_create_next_version_from_string("CORGE", a, 1225997800);             // NODE 11
      a = bit.primary_tip;
	    bit.test_create_next_version_from_string("CORGE", a, 1226052000);             // NODE 12
      a = bit.primary_tip;
	    bit.test_create_next_version_from_string("CORGE", a, 1226077200);             // PRIMARY TIP
      a = bit.primary_tip;
	    bit.test_create_next_version_from_string("CORGE", a, 1226079800);             // PRIMARY TIP
      a = bit.primary_tip;
	    bit.test_create_next_version_from_string("CORGE", a, 1226083200);             // PRIMARY TIP
      a = bit.primary_tip;
	    bit.test_create_next_version_from_string("CORGE", a, 1226089200);             // PRIMARY TIP
      a = bit.primary_tip;
	    bit.test_create_next_version_from_string("CORGE", a, 1226094200);             // PRIMARY TIP
    }

	  stdout.printf("Creating a timeline widget\n");
	  timeline = new WizWidgets.Timeline (store, bit.uuid);
    timeline.selection_changed += selection_changed;

    var vbox = new Gtk.VBox(false, 8);
    label = new Gtk.Label("Label shows version contents please select a bit");
    vbox.add(label);
    vbox.add(timeline);
	  win.add (vbox);

	  win.show_all ();

	  Gtk.main ();
  }
}
