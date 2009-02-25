using GLib;

namespace Wiz {

	/*
	 */
	public class File : GLib.Object {
		public string stream_name { get; set; }
		private string parent_hash;
		private GLib.File temp_file;

		/*
		 * @param parent_hash        the hash of the parent to duplicate for writing
		 */
		public File(string? parent_hash) {
			// FIXME: This class needs to be lazier.
			// E.g. Replace case doesnt need to boher with checking out a temp file
			this.parent_hash = parent_hash;
			if (this.parent_hash != null) {
				this.temp_file = this.mk_temp();
			} else {
				this.temp_file = this.mk_temp_new();
			}
		}

		internal File.from_blob(Wiz.Private.Blob blob) {
			this.parent_hash = blob.uuid;
			this.temp_file = blob.get_temp_file();
		}

		/*
		 * Create a new empty temp file for writing
		 */
		private GLib.File? mk_temp_new() {
			GLib.File store = GLib.File.new_for_path(Environment.get_home_dir());
			store = store.get_child(".wizbit").get_child("objects");
			return GLib.File.new_for_path(store.get_path() + "/" + generate_uuid());
		}

		/*
		 * Create a copy of the parent file in order to provide writing
		 */
		private GLib.File? mk_temp() {
			GLib.File src, dst, tmp;
			GLib.File store = GLib.File.new_for_path(Environment.get_home_dir());
			store = store.get_child(".wizbit").get_child("objects");

			// Open the parent for copying 
			string path = store.get_path() + "/" + this.parent_hash.substring(0,2) + 
			                                 "/" + this.parent_hash.substring(2,-1);
			src = GLib.File.new_for_path(path);
			if (!src.query_exists (null)) {
				stderr.printf ("Parent '%s' at '%s' doesn't exist.\n", 
				               this.parent_hash, src.get_path ());
				return null;
			}

			// Make sure the temp folder exists
			path = store.get_parent().get_path() + "/temp";
			tmp = GLib.File.new_for_path(path);
			if (!tmp.query_exists (null)) {
				try {
					tmp.make_directory(null);
				} catch (GLib.Error e) {
					stdout.printf("Caught GLib.Error %s\n", e.message);
				}
			}

			// Create a temporary destination file name
			path = tmp.get_path() + "/" + generate_uuid();
			dst = GLib.File.new_for_path(path);
			try {
				src.copy (dst, GLib.FileCopyFlags.NONE, null, null);
			} catch (GLib.Error e) {
				stdout.printf("Caught GLib.Error %s\n", e.message);
			}

			// Serve the GLib.File of the temporary file up
			return dst;
		}

		/**
		 * wiz_file_get_contents:
		 * @returns: The contents of the file as a string.
		 */
		public string get_contents() throws FileError {
			string contents;
			long length;
			FileUtils.get_contents(this.get_path(), out contents, out length);
			return contents;
		}

		/**
		 * wiz_file_set_contents:
		 * @returns: Set the contents of the file from a string.
		 */
		public void set_contents(string contents, long length = -1) throws FileError {
			FileUtils.set_contents(this.get_path(), contents, length);
		}

		/**
		 * wiz_file_get_mapped_file:
		 * @returns: A GLib.MappedFile object
		 */
		public MappedFile get_mapped_file() {
			return new MappedFile(this.get_path(), false);
		}

		/**
		 * wiz_file_read:
		 * @returns: A GLib.InputStream for reading from the resource
		 */
		public GLib.InputStream read() {
			return this.temp_file.read(null);
		}

		/**
		 * wiz_file_append_to
		 * @returns: A GLib.OutputStream for append to a resource
		 */
		public GLib.OutputStream append_to() {
			return this.temp_file.append_to(FileCreateFlags.PRIVATE, null);	
		}

		/**
		 * wiz_file_replace
		 * @returns: A GLib.OutputStream for replacing a resource
		 */
		public GLib.OutputStream replace() {
			return this.temp_file.replace(null, false, FileCreateFlags.PRIVATE, null);
		}

		/**
		 * wiz_file_hash:
		 * Hashing function, generates a hash of this file once the hash is 
		 * generated this file can no longer be changed, all other writes
		 * should land on a new commit.
		 */
		public string hash() {
			return "HASH GENERATED ON CLOSE?";
		}

		/**
		 * wiz_file_get_path:
		 */
		public string get_path() {
			return this.temp_file.get_path();
		}
	}
}
