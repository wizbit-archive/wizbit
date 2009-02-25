using GLib;
using Wiz;

class TestBit : TestSuiteWithTempDir {
	private Wiz.Commit dummy_commit(Wiz.Bit obj, string data, Commit? parent) {
		var cb = obj.get_commit_builder();
		if (parent != null)
			cb.add_parent(parent);
		var f = new Wiz.File(null);
		f.set_contents(data);
		cb.file = f;
		return cb.commit();
	}

	public void test_wiz_store() {
		var store = new Wiz.Store("repo_uuid", "data/wiz_store");
		var obj = store.create_bit();
		assert( obj != null );

		var same_obj = store.open_bit(obj.uuid);
		assert( same_obj != null );
		assert( obj.uuid == same_obj.uuid );
	}

	public void test_wiz_bit_1() {
		var obj = new Wiz.Bit("SOMENAME", "data/wiz_bit");

		var v1 = dummy_commit(obj, "FOOBAR", null);
		var v2 = dummy_commit(obj, "BARFOO", obj.primary_tip);

		obj = new Wiz.Bit("SOMENAME", "data/wiz_bit");

		v2 = obj.primary_tip;
		assert( v2 != null );
		assert( v2.committer != null );
		assert( v2.parents.length() == 1 );
		var mf = v2.file.get_mapped_file();
		assert( Memory.cmp(mf.get_contents(), "BARFOO", 6) == 0 );

		v1 = v2.parents.nth_data(0);
		assert( v1 != null );
		assert( v1.committer != null);
		assert( v1.parents.length() == 0 );
		mf = v2.file.get_mapped_file();
		assert( Memory.cmp(mf.get_contents(), "FOOBAR", 6) == 0 );
	}

	public void test_wiz_refs_1() {
		var obj = new Wiz.Bit("REFSTEST", "data/wiz_refs_1");
		dummy_commit(obj, "BARFOO", obj.primary_tip);
		dummy_commit(obj, "FOOBAR", obj.primary_tip);
		assert( obj.tips.length() == 1 );
	}

	public void test_wiz_refs_2() {
		var obj = new Wiz.Bit("REFSTEST2", "data/wiz_refs_2");
		dummy_commit(obj, "BARFOO", obj.primary_tip);
		dummy_commit(obj, "FOOBAR", obj.primary_tip);

		var obj_2 = new Wiz.Bit("REFSTEST2", "tests/data/wiz_refs_2");
		assert( obj.tips.length() == 1 );
	}

	public static void main (string[] args) {
		Test.init (ref args);
		var me = new TestBit();
		var ts = new TestSuite("bits");
		ts.add(new TestCase("store_1", 0, me.setup, me.test_wiz_store, me.teardown));
		ts.add(new TestCase("bit_1", 0, me.setup, me.test_wiz_bit_1, me.teardown));
		ts.add(new TestCase("refs_1", 0, me.setup, me.test_wiz_refs_1, me.teardown));
		ts.add(new TestCase("refs_2", 0, me.setup, me.test_wiz_refs_2, me.teardown));
		TestSuite.get_root().add_suite(ts);
		Test.run();
	}
}
