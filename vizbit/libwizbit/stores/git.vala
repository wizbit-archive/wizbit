using GLib;

/* FIXME:
 *
 * In order to get things moving as quickly as possible i am just vommiting code. As such there are
 * at *least* the following inconsistencies:
 *
 * 1. Sha1 is passed around as a string. In the tree this should definitely be a binary sha1 
 * (for Git compatibility)
 *
 * 2. Trees don't support subtrees. We don't actually need trees within trees for wizbit so i said
 * stuff it.
 *
 */

namespace Git {

	public class Store : GLib.Object {
		/* The store just provides a way to read or write from the store.
		   It hides whether or not we are dealing with loose or packed objects
		*/

		private GLib.Vfs vfs;

		public string directory { get; construct; }

		public Store(string directory) {
			this.directory = directory;
		}

		construct {
			this.vfs = new GLib.Vfs();
		}

		private string get_path_for_uuid(string uuid) {
			string folder = this.directory + "/" + uuid.substring(1,2);
			DirUtils.create_with_parents(folder,0755);
			return folder + "/" + uuid.substring(3,40);
		}

		public bool read(string uuid, out MappedFile obj) {
			string path = this.get_path_for_uuid(uuid);
			obj = new MappedFile(path, false);
			return true;
		}

		public string write(Object obj) {
			void *bufptr;
			long size;
			obj.serialize(out bufptr, out size);
			Checksum sha1 = new Checksum(ChecksumType.SHA1);
			sha1.update((uchar [])bufptr, size);
			string uuid = sha1.get_string();
			FileUtils.set_contents(this.get_path_for_uuid(uuid), (string)bufptr, size);
			return uuid;
		}
	}

	public class Object : GLib.Object {
		public bool parsed { get; set; }
		public Store store { get; construct; }
		public string uuid { get; set; }

		public Object(Store store) {
			this.store = store;
			this.parsed = true;
		}

		public Object.from_uuid(Store store, string uuid) {
			this.store = store;
			this.uuid = uuid;
			this.parsed = false;
		}

		public void write() {
			this.uuid = this.store.write(this);
		}

		public virtual void serialize(out void *bufptr, out long size) {}

		protected bool matches (char* begin, string keyword) {
			char* keyword_array = keyword;
			long len = keyword.len ();
			for (int i = 0; i < len; i++) {
				if (begin[i] != keyword_array[i]) {
					return false;
				}
			}
			return true;
		}

	}

	public class Blob : Object {
		private MappedFile file;
		private void *bufptr;
		private long size;

		MappedFile read() {
			MappedFile obj;
			this.store.read(this.uuid, out obj);
			return obj;
		}

		/* Duplicated because vala won't use the ones in Object yet */
		public Blob(Store store) {
			this.store = store;
			this.parsed = true;
		}
		public Blob.from_uuid(Store store, string uuid) {
			this.store = store;
			this.uuid = uuid;
			this.parsed = false;
		}

		public void set_contents_from_file(string path) {
			this.file = new MappedFile(path, false);
			this.bufptr = file.get_contents();
			this.size = file.get_length();
		}

		public override void serialize(out void *bufptr, out long size) {
			bufptr = this.bufptr;
			size = this.size;
		}
	}

	public class Tree : Object {
		private StringBuilder builder;

		public List<Blob> blobs;
		public List<Tree> trees;

		/* Duplicated because vala won't use the ones in Object yet */
		public Tree(Store store) {
			this.store = store;
			this.parsed = true;
		}
		public Tree.from_uuid(Store store, string uuid) {
			this.store = store;
			this.uuid = uuid;
			this.parsed = false;
		}

		construct {
			this.blobs = new List<Blob>();
			this.trees = new List<Tree>();
		}

		public void unserialize() {
			MappedFile obj;
			char *bufptr;
			long size;
			long mark, pos;

			if (!this.store.read(this.uuid, out obj))
				return;

			bufptr = obj.get_contents();
			size = obj.get_length();

			while (pos < size) {
				if (matches(&bufptr[pos], "tree ")) {
					mark = pos = pos + 5;
					while (bufptr[pos] != '\n')
						pos ++;
					this.trees.append( new Git.Tree.from_uuid(this.store, ((string)bufptr[pos]).substring(mark, pos-mark)) );
				}
				else if (matches(&bufptr[pos], "blob ")) {
					mark = pos = pos + 5;
					while (bufptr[pos] != '\n')
						pos ++;
					this.blobs.append( new Git.Blob.from_uuid(this.store, ((string)bufptr[pos]).substring(mark, pos-mark)) );
				}
				else {
					/* Throw an error */
					return;
				}
			}
		}

		public override void serialize(out void *bufptr, out long size) {
			this.builder = new StringBuilder();
			
			foreach (Blob blob in this.blobs)
				this.builder.printf("blob %s\n", blob.uuid);

			foreach (Tree obj in this.trees)
				this.builder.printf("tree %s\n", obj.uuid);

			bufptr = this.builder.str;
			size = this.builder.str.len();
		}
	}

	public class Commit : Object {
		private StringBuilder builder;

		private Tree _tree;
		public Tree tree {
			get {
				if (!this._tree.parsed)
					this._tree.unserialize();
				return this._tree;
			}
			set {
				this._tree = value;
			}
		}
		public List<Commit> parents;
		public string author { get; set; }
		public string committer { get; set; }
		public string message { get; set; }

		/* Duplicated because vala won't use the ones in Object yet */
		public Commit(Store store) {
			this.store = store;
			this.parsed = true;
		}
		public Commit.from_uuid(Store store, string uuid) {
			this.store = store;
			this.uuid = uuid;
			this.parsed = false;
		}

		construct {
			this.parents = new List<Commit>();
		}

		public void unserialize() {
			MappedFile obj;
			char *bufptr;
			long size;
			long mark;
			long pos;

			if (!this.store.read(this.uuid, out obj))
				return;

			bufptr = obj.get_contents();
			size = obj.get_length();

			if (!matches(bufptr, "tree "))
				return;

			mark = pos = 6;
			while (bufptr[pos] != '\n' && pos < size)
				pos ++;

			this.tree = new Git.Tree.from_uuid(this.store, ((string)bufptr).substring(mark, pos-mark));
			mark = pos = pos+1;

			while (matches(&bufptr[pos], "parent ")) {
				while (bufptr[pos] != '\n' && pos < size)
					pos ++;
				
				this.parents.append(new Git.Commit.from_uuid(this.store, ((string)bufptr).substring(mark, pos-mark)));
				mark = pos = pos+1;
			}

			if (!matches(&bufptr[pos], "author "))
				return;

			mark = pos = pos+7;
			while (bufptr[pos] != '\n' && pos < size)
				pos ++;

			this.author = ((string)bufptr).substring(mark, pos-mark);
			mark = pos = pos+1;

			if (!matches(&bufptr[pos], "committer "))
				return;

			mark = pos = pos+10;
			while (bufptr[pos] != '\n' && pos < size)
				pos ++;

			this.committer = ((string)bufptr).substring(mark, pos-mark);
			mark = pos = pos+1;

			this.message = ((string)bufptr).substring(mark, size-mark);
		}

		public override void serialize(out void *bufptr, out long size) {
			this.builder = new StringBuilder();
			this.builder.printf("tree %s\n", this.tree.uuid);
			foreach (Commit parent in this.parents)
				this.builder.printf("parent %s\n", parent.uuid);
			this.builder.printf("author %s\n", this.author);
			this.builder.printf("committer %s\n", this.committer);
			this.builder.printf("%s\n", this.message);

			bufptr = this.builder.str;
			size = this.builder.str.len();
		}
	}

	public class Tag : Object {
		private Commit _commit;
		public Commit commit { 
			get {
				if (!this._commit.parsed)
					this._commit.unserialize();
				return this._commit;
			}
			set {
				this._commit = value;
			}
		}

		/* Duplicated because vala won't use the ones in Object yet */
		public Tag(Store store) {
			this.store = store;
			this.parsed = true;
		}
		public Tag.from_uuid(Store store, string uuid) {
			this.store = store;
			this.uuid = uuid;
			this.parsed = false;
		}

		public void unserialize() {
			MappedFile obj;
			char *bufptr;
			long size;

			if (!this.store.read(this.uuid, out obj))
				return;

			bufptr = obj.get_contents();
			size = obj.get_length();
		}

		public override void serialize(out void *bufptr, out long size) {
		}
	}
}
