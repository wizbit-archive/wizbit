using GLib;
using Wiz;
using Git;

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

		public void test_git_reader() {
			Git.Store store = new Git.Store("../../wizbit/.git/objects");

			Git.Blob blob = new Git.Blob(store);
			blob.set_contents_from_file("/tmp/foo");
			blob.write();

			Git.Tree tree = new Git.Tree(store);
			tree.blobs.append(blob);
			tree.write();

			Git.Commit commit = new Git.Commit(store);
			commit.tree = tree;
			commit.parents.append( new Git.Commit.from_uuid(store, "some random uuid") );
			commit.author = "John Carr <john.carr@unrouted.co.uk>";
			commit.committer = "John Carr <john.carr@unrouted.co.uk>";
			commit.message = "Foo bar foo bar";
			commit.write();

			stdout.printf("test_git_reader [OK]\n");
		}

		static int main(string[] args) {
			Test test = new Test();
			test.test_git_reader();
			return 0;
		}
	}
}
