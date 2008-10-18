using GLib;
using Wiz;
using Graph;

public void test_store_new() {
	/*
	 * This testcase creates 10,000 commit stores in memory
	 * In each one it creates a commit and then asserts that
	 * there is only one tip.
	 *
	 * This ensures that we are able to create a LOT of databases
	 * and that we are commiting to a different database each time
	 * (otherwise the number of tips would go up)
	 */
	var foo = new List<CommitStore>();
	for (int i=0; i<10000; i++) {
		var test = new CommitStore(":memory:");
		var c = new RarCommit();
		c.blob = "1234";
		test.store_commit(c);
		assert(test.get_tips("fsfs").length() == 1);
		foo.append(test);
	}
}

public void test_commit_lookup() {
	/*
	 * Commit to a CommitStore and then try and read it back out
	 */
	var s = new CommitStore("data/foo");

	var c1 = new RarCommit();
	c1.blob = "1234";
	s.store_commit(c1);

	var c1_lookup = s.lookup_commit(c1.uuid);
	assert(c1.blob == "1234");
}

public void test_commit() {
	var s = new CommitStore("data/foo");

	var c1 = new RarCommit();
	c1.blob = "rararar";
	s.store_commit(c1);

	var c2 = new RarCommit();
	c2.blob = "rararararar";
	c2.parents.append(c1.uuid);
	s.store_commit(c2);

	var tips = s.get_tips("sdsdsd");
	assert(tips.length() == 1);
}

public static void main (string[] args) {
	if (!FileUtils.test("data", FileTest.IS_DIR)) { 
		DirUtils.create_with_parents("data", 0755);
		/* Should write some data to the file data/blob-data */
	}
	Test.init (ref args);
	Test.add_func("/wizbit/commit_store/store_new", test_store_new);
	Test.add_func("/wizbit/commit_store/commit_lookup", test_commit_lookup);
	Test.add_func("/wizbit/commit_store/1", test_commit);
	Test.run();
}
