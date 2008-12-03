using GLib;
using Wiz;

public static void main(string[] args) {
	Gtk.init (ref args);

	Gtk.Window win = new Gtk.Window (Gtk.WindowType.TOPLEVEL);
	win.set_border_width (5);
	win.set_title ("Wizbit Timeline Widget");
	win.destroy += Gtk.main_quit;

	var store = new Wiz.Store("repo_uuid", "data/wiz_store");
	var obj = store.create_bit();
	assert( obj != null );
	/* Create a branching history which will look good, need to forge the
	 * timestamps to give it good positioning to test everything
	 *
	 */

	Wiz.Version a, b, c, d; // Branches
	stdout.printf("Creating a faux history\n");
	obj.test_create_next_version_from_string("FOO", null, 1225274400);            // ROOT
	obj.test_create_next_version_from_string("BAR", obj.primary_tip, 1225360800); // NODE 1
	obj.test_create_next_version_from_string("QUX", obj.primary_tip, 1225447200); // NODE 2
  b = obj.primary_tip;
  c = obj.primary_tip;
	obj.test_create_next_version_from_string("QUUX", obj.primary_tip, 1225558800);// NODE 3
  a = obj.primary_tip;
  d = obj.primary_tip;

	obj.test_create_next_version_from_string("BAZ", b, 1225620000);               // NODE 4
  b = obj.primary_tip;

	obj.test_create_next_version_from_string("CORGE", d, 1225620600);             // NODE 5
  d = obj.primary_tip;

	obj.test_create_next_version_from_string("CORGE", c, 1225706400);             // TIP 1

	obj.test_create_next_version_from_string("GRAULT", b, 1225707000);            // Node 6
  b = obj.primary_tip;

	obj.test_create_next_version_from_string("BAZ", d, 1225707600);               // NODE 7
  d = obj.primary_tip;
	obj.test_create_next_version_from_string("BAZ", d, 1225792800);               // TIP 2

	obj.test_create_next_version_from_string("BAZ", b, 1225879200);               // NODE 8
  b = obj.primary_tip;

	obj.test_create_next_version_from_string("GRAULT", a, 1225879800);            // NODE 9
  a = obj.primary_tip;
  d = obj.primary_tip;

	obj.test_create_next_version_from_string("CORGE", d, 1225904400);             // NODE 10
  d = obj.primary_tip;
	obj.test_create_next_version_from_string("CORGE", d, 1225965600);             // TIP 3

	obj.test_create_next_version_from_string("GRAULT", b, 1225966200);            // TIP 4

	obj.test_create_next_version_from_string("CORGE", a, 1225990800);             // NODE 11
  a = obj.primary_tip;
	obj.test_create_next_version_from_string("CORGE", a, 1226052000);             // NODE 12
  a = obj.primary_tip;
	obj.test_create_next_version_from_string("CORGE", a, 1226077200);             // PRIMARY TIP

	stdout.printf("Creating a timeline widget\n");
	Wiz.Timeline t = new Wiz.Timeline (store, obj.uuid);
	win.add (t);

	win.show_all ();

	Gtk.main ();
}
