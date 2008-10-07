using GLib;

/* FIXME:
 *
 * In order to get things moving as quickly as possible i am just vommiting code. As such there are
 * at *least* the following inconsistencies:
 *
 * 1. This list of fixmes is out of date.
 *
 */

namespace Graph {

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
			string folder = Path.build_filename(this.directory, uuid.substring(0,2));
			DirUtils.create_with_parents(folder, 0755);
			return Path.build_filename(folder, uuid.substring(2,40));
		}

		public bool exists(string uuid) {
			return FileUtils.test(this.get_path_for_uuid(uuid), FileTest.EXISTS);
		}

		public MappedFile read(string uuid) {
			string path = this.get_path_for_uuid(uuid);
			return new MappedFile(path, false);
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


	}

	public class Blob : Object {
		private MappedFile file;
		private void *bufptr;
		private long size;

		public MappedFile read() {
			return this.store.read(this.uuid);
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

		public void set_contents(void *bufptr, long size) {
			this.bufptr = bufptr;
			this.size = size;
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

	public class Commit : Object {
		private StringBuilder builder;

		public Blob blob { get; set; }
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

			obj = this.store.read(this.uuid);
			if (obj == null)
				return;

			bufptr = obj.get_contents();
			size = obj.get_length();

			if (!matches(bufptr, "blob "))
				return;

			mark = pos = 5;
			while (bufptr[pos] != '\n' && pos < size)
				pos ++;

			this.blob = new Blob.from_uuid(this.store, ((string)bufptr).substring(mark, pos-mark));
			mark = pos = pos+1;

			while (matches(&bufptr[pos], "parent ")) {
				mark = pos = pos + 7;
				while (bufptr[pos] != '\n' && pos < size)
					pos ++;

				this.parents.append(new Commit.from_uuid(this.store, ((string)bufptr).substring(mark, pos-mark)));
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

		private bool matches (char* begin, string keyword) {
			char* keyword_array = keyword;
			long len = keyword.len ();
			for (int i = 0; i < len; i++)
				if (begin[i] != keyword_array[i])
					return false;
			return true;
		}

		public override void serialize(out void *bufptr, out long size) {
			this.builder = new StringBuilder();
			this.builder.append("blob %s\n".printf(this.blob.uuid));
			foreach (Commit parent in this.parents)
				this.builder.append("parent %s\n".printf(parent.uuid));
			this.builder.append("author %s\n".printf(this.author));
			this.builder.append("committer %s\n".printf(this.committer));
			this.builder.append(this.message);

			bufptr = this.builder.str;
			size = this.builder.str.len();
		}
	}
}
