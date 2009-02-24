using GLib;
using Wiz.Private;

class TestBlobStore : TestSuiteWithTempDir {
	public void test_graph() {
		var store = new BlobStore(this.directory);
		var blob = new Blob(store);
		blob.set_contents_from_file(Config.TESTDATADIR + "blob-data");
		blob.write();
		assert( blob.uuid.len() == 40 );
	}

	static void main(string[] args) {
		Test.init(ref args);
		var me = new TestBlobStore();
		var ts = new TestSuite("blobstore");
		ts.add(new TestCase("create_blob_from_file", 0, me.setup, me.test_graph, me.teardown));
		TestSuite.get_root().add_suite(ts);
		Test.run();
	}
}
