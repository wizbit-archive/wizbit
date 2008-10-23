using GLib;
using Wiz;
using Graph;

RarCommit create_dummy_commits(CommitStore store, uint no_commits, RarCommit ?graft_point = null) {
	RarCommit cur = graft_point;

	for (uint i=0; i<no_commits; i++) {
		var nw = new RarCommit();
		if (cur != null)
			nw.parents.append(cur.uuid);
		nw.blob = "abc123";
		cur = store.store_commit(nw);
	}

	return cur;
}

RarCommit create_merge(CommitStore store, RarCommit c1, RarCommit c2) {
	var c = new RarCommit();
	c.parents.append(c1.uuid);
	c.parents.append(c2.uuid);
	c.blob = "abc123";
	store.store_commit(c);
	return c;
}

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
		var test = new CommitStore(":memory:", "foo");
		create_dummy_commits(test, 1);
		assert(test.get_tips().length() == 1);
		foo.append(test);
	}
}

public void test_commit_lookup() {
	/*
	 * Commit to a CommitStore and then try and read it back out
	 */
	var s = new CommitStore(":memory:", "foo");
	var c = create_dummy_commits(s, 1);

	var c1_lookup = s.lookup_commit(c.uuid);
	assert(c1_lookup.uuid == c.uuid);
	assert(c1_lookup.blob == "abc123");
}

public void test_commit() {
	var s = new CommitStore(":memory:", "foo");
	create_dummy_commits(s, 2);

	var tips = s.get_tips();
	assert(tips.length() == 1);
}

public void test_primary_tip() {
	var s = new CommitStore(":memory:", "foo");
	var c = create_dummy_commits(s, 1);

	var pt = s.get_primary_tip();
	assert(c.uuid == pt);
}

public void test_forward() {
	var s = new CommitStore(":memory:", "foo");
	create_dummy_commits(s, 10);

	var foo = s.get_root();
	var bar = s.get_primary_tip();

	var cur = foo;
	while (cur != bar) {
		cur = s.get_forward(cur);
		assert(cur != null);
	}
	assert(s.get_forward(cur) == null);
}

public void test_forwards() {
	/* Try and traverse from root to tip and from tip to root */
	var s = new CommitStore(":memory:", "foo");
	create_dummy_commits(s, 10);

	var foo = s.get_root();
	var bar = s.get_primary_tip();

	var cur = foo;
	var nxt = s.get_forwards(cur);
	while (nxt.length() == 1) {
		assert(cur != bar);
		cur = nxt.nth_data(0);
		assert(cur != foo);
		nxt = s.get_forwards(cur);
	}
	assert(nxt.length() == 0);
	assert(cur == bar);
}

void test_forwards_multiple() {
	var s = new CommitStore(":memory:", "foo");
	var root = create_dummy_commits(s, 1);
	var tip1 = create_dummy_commits(s, 1, root);
	var tip2 = create_dummy_commits(s, 1, root);

	var forward = s.get_forwards(root.uuid);
	assert(forward.length() == 2);
	assert(forward.nth_data(0) == tip1.uuid);
	assert(forward.nth_data(1) == tip2.uuid);
}

public void test_backward() {
	var s = new CommitStore(":memory:", "foo");
	create_dummy_commits(s, 10);

	var bar = s.get_primary_tip();
	var foo = s.get_root();

	var cur = bar;
	while (cur != foo) {
		cur = s.get_backward(cur);
		assert(cur != null);
	}
	assert(s.get_backward(cur) == null);
}

public void test_backwards() {
	var s = new CommitStore(":memory:", "foo");
	create_dummy_commits(s, 10);

	var bar = s.get_primary_tip();
	var foo = s.get_root();

	var cur = bar;
	var prv = s.get_backwards(cur);
	while (prv.length() == 1) {
		assert(cur != foo);
		cur = prv.nth_data(0);
		assert(cur != bar);
		prv = s.get_backwards(cur);
	}
	assert(prv.length() == 0);
	assert(cur == foo);
}

void test_backwards_multiple() {
	var s = new CommitStore(":memory:", "foo");
	var root = create_dummy_commits(s, 1);
	var c1 = create_dummy_commits(s, 10, root);
	var c2 = create_dummy_commits(s, 10, root);
	var tip = create_merge(s, c1, c2);

	var back = s.get_backwards(tip.uuid);
	assert(back.length() == 2);
	assert(back.nth_data(0) == c1.uuid);
	assert(back.nth_data(1) == c2.uuid);
}

public void test_get_root() {
	var s = new CommitStore(":memory:", "foo");
	assert(s.get_root() == null);

	var c = create_dummy_commits(s, 1);
	assert(s.get_root() == c.uuid);

	for (uint i=0; i<100; i++) {
		var tmp = create_dummy_commits(s, 1, c);
		assert(tmp.uuid != c.uuid);
		assert(s.get_root() == c.uuid);
	}
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
	Test.add_func("/wizbit/commit_store/primary_tip", test_primary_tip);
	Test.add_func("/wizbit/commit_store/forward", test_forward);
	Test.add_func("/wizbit/commit_store/forwards", test_forwards);
	Test.add_func("/wizbit/commit_store/forwards_multiple", test_forwards_multiple);
	Test.add_func("/wizbit/commit_store/backward", test_backward);
	Test.add_func("/wizbit/commit_store/backwards", test_backwards);
	Test.add_func("/wizbit/commit_store/backwards_multiple", test_backwards_multiple);
	Test.add_func("/wizbit/commit_store/get_root", test_get_root);
	Test.run();
}
