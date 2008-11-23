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

	Wiz.Version branch_tip;
	stdout.printf("Creating a faux history\n");
	obj.test_create_next_version_from_string("FOO", null, 1227395050);
	branch_tip = obj.primary_tip;

	obj.test_create_next_version_from_string("BAR", branch_tip, 1227395100);
	branch_tip = obj.primary_tip;

	obj.test_create_next_version_from_string("QUX", branch_tip, 1227395150);
	obj.test_create_next_version_from_string("QUUX", obj.primary_tip, 1227395160);

	obj.test_create_next_version_from_string("BAZ", branch_tip, 1227395180);
	branch_tip = obj.primary_tip;

	obj.test_create_next_version_from_string("CORGE", branch_tip, 1227395200);
	obj.test_create_next_version_from_string("GRAULT", branch_tip, 1227395220);

	stdout.printf("Creating a timeline widget\n");
	Wiz.Timeline t = new Wiz.Timeline (store, obj.uuid);
	win.add (t);

	win.show_all ();

	Gtk.main ();
}
