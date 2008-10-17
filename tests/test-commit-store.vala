using GLib;
using Wiz;
using Graph;

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
	Test.add_func("/wizbit/commit_store/1", test_commit);
	Test.run();
}
