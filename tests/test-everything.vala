using GLib;
using Wiz;
using Store;

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

		public void test_store() {
			Store.Store store = new Store.Store("tests/data");

			Store.Blob blob = new Store.Blob(store);
			blob.set_contents_from_file("/tmp/foo");
			blob.write();
			
			stdout.printf("blob: %s\n", blob.uuid);

			Store.Commit commit = new Store.Commit(store);
			commit.blob = blob;
			commit.parents.append( new Store.Commit.from_uuid(store, "some random uuid") );
			commit.author = "John Carr <john.carr@unrouted.co.uk>";
			commit.committer = "John Carr <john.carr@unrouted.co.uk>";
			commit.message = "Foo bar foo bar";
			commit.write();

			stdout.printf("commit: %s\n", commit.uuid);

			/* OK, lets try and read 'stuff' back. */
			Store.Commit c = new Store.Commit.from_uuid(store, commit.uuid);
			c.unserialize();

			assert( c.author == "John Carr <john.carr@unrouted.co.uk>" );
			assert( c.committer == "John Carr <john.carr@unrouted.co.uk>" );
			assert( c.message == "Foo bar foo bar" );
		}

		public void test_wizbit_2() {
			Wiz.Object obj = new Wiz.Object("SOMENAME");

			Wiz.Version v1 = obj.create_next_version_from_string("FOOBAR", null);
			assert( v1.author != null );
			assert (v1.previous != null );

			Wiz.Version v2 = obj.create_next_version_from_string("BARFOO", v1);
			assert( v2.author != null );
			assert( v2.previous == null );
		}

		public void test_wizbit_3() {
			Wiz.Object obj = new Wiz.Object("SOMENAME");

			Wiz.Version v2 = obj.primary_tip;
			Wiz.Version v1 = v2.previous;
		}

		static int main(string[] args) {
			Test test = new Test();
			test.test_store();
			test.test_wizbit_2();
			test.test_wizbit_3();
			return 0;
		}
	}
}
