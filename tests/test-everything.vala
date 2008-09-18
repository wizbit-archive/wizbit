using GLib;
using Wiz;
using Graph;

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
}

public void test_wiz_bit_2() {
	var obj = new Wiz.Bit("SOMENAME", "data/wiz_bit");
	
	var v2 = obj.primary_tip;
	assert( v2 != null );
	assert( v2.author != null );
	assert( v2.previous != null );
	assert( v2.read_as_string() == "BARFOO" );

	var v1 = v2.previous;
	assert( v1.author != null);
	assert( v1.previous == null);
	assert( v1. read_as_string() == "FOOBAR" );
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

public void test_graph() {
	var store = new Graph.Store("data/graph");

	var blob = new Graph.Blob(store);
	blob.set_contents_from_file("data/blob-data");
	blob.write();

	assert( blob.uuid.len() == 40 );

	var commit = new Graph.Commit(store);
	commit.blob = blob;
	commit.parents.append( new Graph.Commit.from_uuid(store, "some random uuid") );
	commit.author = "John Carr <john.carr@unrouted.co.uk>";
	commit.committer = "John Carr <john.carr@unrouted.co.uk>";
	commit.message = "Foo bar foo bar";
	commit.write();

	assert( commit.uuid.len() == 40 );

	/* OK, lets try and read 'stuff' back. */
	var c = new Graph.Commit.from_uuid(store, commit.uuid);
	c.unserialize();

	assert( c.blob.uuid == blob.uuid );
	assert( c.author == "John Carr <john.carr@unrouted.co.uk>" );
	assert( c.committer == "John Carr <john.carr@unrouted.co.uk>" );
	assert( c.message == "Foo bar foo bar" );
}

public static void main (string[] args) {
	if (!FileUtils.test("data", FileTest.IS_DIR)) { 
		DirUtils.create_with_parents("data", 0755);
		/* Should write some data to the file data/blob-data */
	}
	Test.init (ref args);
	Test.add_func("/wizbit/store/1", test_wiz_store);
	Test.add_func("/wizbit/bit/1", test_wiz_bit_1);
	Test.add_func("/wizbit/bit/2", test_wiz_bit_2);
	Test.add_func("/wizbit/refs/1", test_wiz_refs_1);
	Test.add_func("/wizbit/refs/2", test_wiz_refs_2);
	Test.add_func("/wizbit/graph/1", test_graph);
	Test.run();
}
