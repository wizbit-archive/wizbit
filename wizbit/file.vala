using GLib;

namespace Wiz {

	/*
	 */
	public class File : GLib.Object {
		public string stream_name { get; set; }
		private string parent_hash;
		private GLib.File temp_file;

		public File() {
			GLib.File store = GLib.File.new_for_path(Environment.get_tmp_dir());
			this.temp_file = GLib.File.new_for_path(store.get_path() + "/" + generate_uuid());
		}

		internal File.from_blob(Wiz.Private.Blob blob) {
			// FIXME: Make temp file creation lazier
			// E.g. Replace case doesnt need to bother with checking out a temp file
			this.parent_hash = blob.uuid;
			this.temp_file = blob.get_temp_file();
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
		 * @self: The file object to set the contents of
		 * @contents: A string to load into the file object
		 * @length: The length of data to load into the file
		 *
		 * Set the contents of the file from a string.
		 */
		public void set_contents(string contents, long length = -1) throws FileError {
			FileUtils.set_contents(this.get_path(), contents, length);
		}

		/**
		 * wiz_file_get_mapped_file:
		 * @self: The file object from which to get a #GMappedFile
		 * @returns: A #GMappedFile object
		 */
		public MappedFile get_mapped_file() {
			return new MappedFile(this.get_path(), false);
		}

		/**
		 * wiz_file_read:
		 * @returns: A #GInputStream for reading from the resource
		 */
		public GLib.InputStream read() {
			return this.temp_file.read(null);
		}

		/**
		 * wiz_file_append_to
		 * @returns: A #GOutputStream for append to a resource
		 */
		public GLib.OutputStream append_to() {
			return this.temp_file.append_to(FileCreateFlags.PRIVATE, null);	
		}

		/**
		 * wiz_file_replace
		 * @returns: A #GOutputStream for replacing a resource
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
