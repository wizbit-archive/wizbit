using GLib;
using Wiz;
using Graph;

namespace Wiz {
	class Test : GLib.Object {
		public void test_wizbit_1() {
			/*
			GLib.Cancellable c;
			OutputStream stream;

			Object obj = new Object();

			stream = obj.create_next_version();
			stream.write("test", 4, c);
			stream.close(c);

			stream = obj.create_next_version();
			stream.write("testing rules", 13, c);
			stream.close(c);

			stream = obj.create_next_version();
			stream.write("testing sucks", 13, c);
			stream.close(c);
			*/
		}

		public void test_graph() {
			var store = new Graph.Store("tests/data");

			var blob = new Graph.Blob(store);
			blob.set_contents_from_file("/tmp/foo");
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

			assert( c.author == "John Carr <john.carr@unrouted.co.uk>" );
			assert( c.committer == "John Carr <john.carr@unrouted.co.uk>" );
			assert( c.message == "Foo bar foo bar" );
		}

		public void test_wizbit_2() {
			var obj = new Wiz.Object("SOMENAME");

			var v1 = obj.create_next_version_from_string("FOOBAR", null);
			var v2 = obj.create_next_version_from_string("BARFOO", v1);
		}

		public void test_wizbit_3() {
			var obj = new Wiz.Object("SOMENAME");
			
			var v2 = obj.primary_tip;
			assert( v2 != null );
			assert( v2.author != null );
			assert( v2.previous != null );

			var v1 = v2.previous;
			assert( v1.author != null);
			assert( v1.previous == null);
		}

		public void test_wizbit_4() {
			var store = new Wiz.Store("repo_uuid", "tests/data/wiz_4");
			var obj = store.create_object();
			assert( obj != null );
		}

		static int main(string[] args) {
			var test = new Test();
			test.test_graph();
			test.test_wizbit_2();
			test.test_wizbit_3();
			return 0;
		}
	}
}
