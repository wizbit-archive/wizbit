using GLib;
using Wiz;

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

	var v1 = obj.create_next_version_from_string("FOOBAR", null);
	var v2 = obj.create_next_version_from_string("BARFOO", obj.primary_tip);

	obj = new Wiz.Bit("SOMENAME", "data/wiz_bit");

	v2 = obj.primary_tip;
	assert( v2 != null );
	assert( v2.committer != null );
	assert( v2.parents.length() == 1 );
	assert( Memory.cmp(v2.read_as_string(), "BARFOO", 6) == 0 );

	v1 = v2.parents.nth_data(0);
	assert( v1 != null );
	assert( v1.committer != null);
	assert( v1.parents.length() == 0 );
	assert( Memory.cmp(v1.read_as_string(), "FOOBAR", 6) == 0 );
}

public void test_wiz_refs_1() {
	var obj = new Wiz.Bit("REFSTEST", "data/wiz_refs_1");
	obj.create_next_version_from_string("BARFOO", obj.primary_tip);
	obj.create_next_version_from_string("FOOBAR", obj.primary_tip);
	assert( obj.tips.length() == 1 );
}

public void test_wiz_refs_2() {
	var obj = new Wiz.Bit("REFSTEST2", "data/wiz_refs_2");
	obj.create_next_version_from_string("BARFOO", obj.primary_tip);
	obj.create_next_version_from_string("FOOBAR", obj.primary_tip);

	var obj_2 = new Wiz.Bit("REFSTEST2", "tests/data/wiz_refs_2");
	assert( obj.tips.length() == 1 );
}

public static void main (string[] args) {
	if (!FileUtils.test("data", FileTest.IS_DIR)) { 
		DirUtils.create_with_parents("data", 0755);
		/* Should write some data to the file data/blob-data */
	}
	Test.init (ref args);
	Test.add_func("/wizbit/store/1", test_wiz_store);
	Test.add_func("/wizbit/bit/1", test_wiz_bit_1);
	Test.add_func("/wizbit/refs/1", test_wiz_refs_1);
	Test.add_func("/wizbit/refs/2", test_wiz_refs_2);
	Test.run();
}
