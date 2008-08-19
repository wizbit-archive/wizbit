using GLib;
using ZLib;

namespace Git {

	class Store : GLib.Object {
		/* The store just provides a way to read or write from the store.
		   It hides whether or not we are dealing with loose or packed objects
		*/

		private GLib.Vfs vfs;

		public string directory { get; construct; }

		Store(string directory) {
			this.directory = directory;
		}

		construct {
			this.vfs = new GLib.Vfs();
		}

		private string get_path_for_uuid(string uuid) {
			return this.directory + "/" + uuid.substring(1,2) + "/" + uuid.substring(3,40);
		}

		public GLib.InputStream read(string uuid) {
			string path = this.get_path_for_uuid(uuid);
			File file = this.vfs.get_file_for_path(path);
			return file.read(null);
		}
	}

	class Object : GLib.Object {
		public Store store { get; construct; }
		public string uuid { get; construct; }

		Object(Store store, string uuid) {
			this.store = store;
			this.uuid = uuid;
		}
	}

	class Blob : Object {
		GLib.InputStream read() {
			return this.store.read(this.uuid);
		}
	}

	class Tree : Object {
		void unserialize() {
		}
	}

	class Commit : Object {
		void unserialize() {
			GLib.InputStream stream = this.store.read(this.uuid);

			/* read stuff read stuff read stuff */
		}
	}

	class Tag : Object {
		public Commit commit { get; set; }

		void unserialize() {
			GLib.InputStream stream = this.store.read(this.uuid);

			/* read stuff read stuff read stuff */
		}
	}

	/*
	class Test {
		static int main() {
			Store store = new Store();
			Commit commit = store.get_commit('dfdfdfjsldkjflskdjf');
			while (commit) {
				commit = commit.get_parent();
			}

			Blob tmp = new Blob();
			tmp.set_contents(stream);
			Tree tmp2 = new Tree();
			tmp2.append(tmp);
			Commit commit = new Commit();
			tmp.tree = tmp2;
			store.commit(commit);
		}
	}*/

}
