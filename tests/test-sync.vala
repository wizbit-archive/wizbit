using GLib;
using Wiz;

void test_simple_1()
{
	var a = new Wiz.Store("some_uuid", "data/sync_simple_1_a");

	var z = a.create_bit();

	assert( z.tips.length() == 0 );

	var a1 = z.create_next_version_from_string("1");
	var a2 = z.create_next_version_from_string("2", a1);
	var a3 = z.create_next_version_from_string("3", a2);
	var a4 = z.create_next_version_from_string("4", a3);
	var a5 = z.create_next_version_from_string("5", a4);

	assert( z.tips.length() == 1 );

	var a6 = z.create_next_version_from_string("6", a2);
	var a7 = z.create_next_version_from_string("7", a6);
	var a8 = z.create_next_version_from_string("8", a7);
	var a9 = z.create_next_version_from_string("9", a8);

	assert( z.tips.length() == 2 );

	var b = new Wiz.Store("some_uuid", "data/sync_simple_1_b");

	var sa = new SyncSource(a);
	var sb = new SyncClient(b);
	sb.pull(sa);

	var ta = new SyncSource(a);
	var tb = new SyncClient(b);
	sb.pull(ta);

	var a10 = z.create_next_version_from_string("10", a2);
	var a11 = z.create_next_version_from_string("11", a3);

	assert( z.tips.length() == 4 );

	var ua = new SyncSource(a);
	var ub = new SyncClient(b);
	ub.pull(ua);

	var z2 = b.open_bit(z.uuid);
	assert( z.tips.length() == z2.tips.length() );
	assert( z.primary_tip.version_uuid == z2.primary_tip.version_uuid );
}

public static void main (string[] args) {
	if (!FileUtils.test("data", FileTest.IS_DIR)) {
		DirUtils.create_with_parents("data", 0755);
		/* Should write some data to the file data/blob-data */
	}
	Test.init (ref args);
	Test.add_func("/wizbit/sync/1", test_simple_1);
	Test.run();
}
