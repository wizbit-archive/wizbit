using GLib;
using Wiz;

class TestSync : TestSuiteWithTempDir {

	private Wiz.Commit dummy_commit(Wiz.Bit bit, string data, Wiz.Commit? parent = null)
	{
		var cb = bit.get_commit_builder();
		if (parent!=null)
			cb.add_parent(parent);
		cb.blob = data;
		return cb.commit();
	}

	public void test_simple_1()
	{
		var a = new Wiz.Store("some_uuid", Path.build_filename(this.directory, "sync_simple_1_a"));

		var z = a.create_bit();

		assert( z.tips.length() == 0 );

		var a1 = dummy_commit(z, "1");
		var a2 = dummy_commit(z, "2", a1);
		var a3 = dummy_commit(z, "3", a2);
		var a4 = dummy_commit(z, "4", a3);
		var a5 = dummy_commit(z, "5", a4);

		assert( z.tips.length() == 1 );

		var a6 = dummy_commit(z, "6", a2);
		var a7 = dummy_commit(z, "7", a6);
		var a8 = dummy_commit(z, "8", a7);
		var a9 = dummy_commit(z, "9", a8);

		assert( z.tips.length() == 2 );

		var b = new Wiz.Store("some_uuid", Path.build_filename(this.directory, "sync_simple_1_b"));

		var sa = new SyncSource(a);
		var sb = new SyncClient(b);
		sb.pull(sa);

		var ta = new SyncSource(a);
		var tb = new SyncClient(b);
		sb.pull(ta);

		var a10 = dummy_commit(z, "10", a2);
		var a11 = dummy_commit(z, "11", a3);

		assert( z.tips.length() == 4 );

		var ua = new SyncSource(a);
		var ub = new SyncClient(b);
		ub.pull(ua);

		var z2 = b.open_bit(z.uuid);
		assert( z.tips.length() == z2.tips.length() );
		assert( z.primary_tip.version_uuid == z2.primary_tip.version_uuid );
	}
}

public static void main (string[] args) {
	Test.init (ref args);

	var t = new TestSync();

	var ts = new TestSuite("sync");
	ts.add(new TestCase("simple_1", 0, t.setup, t.test_simple_1, t.teardown));
	TestSuite.get_root().add_suite(ts);

	Test.run();
}
