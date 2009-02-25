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
			this.parent_hash = parent_hash;
			if (this.parent_hash != null) {
				this.temp_file = this.mk_temp();
			}
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

		public GLib.InputStream read() {
			return this.temp_file.read(null);
		}

		public GLib.OutputStream append_to() {
			return this.temp_file.append_to(FileCreateFlags.PRIVATE, null);	
		}

		public GLib.OutputStream replace() {
			return this.temp_file.replace(null, false, FileCreateFlags.PRIVATE, null);
		}

		/*
		 * Hashing function, generates a hash of this file once the hash is 
		 * generated this file can no longer be changed, all other writes
		 * should land on a new commit.
		 */
		public string hash() {
			return "HASH GENERATED ON CLOSE?";
		}

		public string get_path() {
			return this.temp_file.get_path();
		}
	}
}
