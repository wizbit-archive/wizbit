/*
 * WARNING: This code is crack!!!
 * Currently uses both the internal and public API's to get the job done. The iterator and what nots need
 * refactoring to use the lower level APIs
 *
 * Then hopefully grab_commit / grab_blob won't be so rancid..
 */

using GLib;
using Wiz;
using Wiz.Private;

public class SyncSource : Object {
	public Wiz.Store store { private get; construct; }

	Wiz.Bit bit;
	Wiz.BreadthFirstIterator iter;
	uint size;

	public SyncSource(Wiz.Store store) {
		this.store = store;
	}

	public List<string> list_all_objects() throws GLib.FileError {
		var objs = new List<string>();
		var path = Path.build_filename(this.store.directory, "refs");
		var dir = Dir.open(path);
		var f = dir.read_name();
		while (f != null) {
			objs.append(f);
			f = dir.read_name();
		}
		return objs;
	}

	/*
	public List<string> search_for_all_objects() {
		var objs = this.list_all_objects();
		this.search_for_objects(objs);
		return objs;
	}

	public List<string> search_for_objects(List<string> objects) {
		/*
		 * search_for_objects
		 * @objects: A list of object ids that we want to pull
		 *
		 * Returns: A list of objects that arent on the source
		 *
		 * When pulling from a sync source, a client uses this method
		 * to set which objects to bfs over.
		 *
		 * FIXME: This is a bit FAIL because we can only pull objects
		 * we know about...
		 *//*
		this.size = 0;
		this.iter = new Wiz.BreadthFirstIterator();
		var retval = new List<string>();
		foreach (var o in objects) {
			if (this.store.has_bit(o)) {
				var bit = this.store.open_bit(o);
				foreach (var t in bit.tips) {
					this.iter.add_version(t);
					this.size++;
				}
			} else {
				retval.append(o);
			}
		}
		return retval;
	}
	*/

	public void search_for_object(string obj) {
		this.size = 0;
		this.iter = new Wiz.BreadthFirstIterator();
		if (this.store.has_bit(obj)) {
			this.bit = this.store.open_bit(obj);
			foreach (var t in bit.tips) {
				this.iter.add_version(t);
				this.size++;
			}
		}
	}

	/**
	 * sync_source_search_for_shas:
	 * @versions: A list of versions to kick out of the iterator
	 * @returns: A list of versions found by the breadth first search
	 *
	 * Does stuff with a monkey
	 */
	public List<string> search_for_shas(Queue<string> versions) {
		for (uint i = 0; i < versions.get_length(); i++) {
			var v = versions.peek_nth(i);
			var wz = this.bit.open_version(v);
			this.iter.kick_out(wz);
		}

		var retval = new List<string>();
		var found = this.iter.get_multiple(this.size);
		foreach (var f in found) {
			retval.append(f.version_uuid);
		}
		this.size *= 2;
		debug("%u", retval.length());
		return retval;
	}

	public string grab_commit(string bit_uuid, string version_uuid) {
		var b = this.store.open_bit(bit_uuid);
		var c = b.commits.lookup_commit(version_uuid);

		var builder = new StringBuilder();
		builder.append("blob %s\n".printf(c.blob));
		foreach (var parent in c.parents)
			builder.append("parent %s\n".printf(parent));
		builder.append("committer %s\n".printf(c.committer));
		builder.append("timestamp %d %d\n".printf(c.timestamp, c.timestamp2));

		return builder.str;
	}

	public string grab_blob(string bit_uuid, string version_uuid) {
		var b = this.store.open_bit(bit_uuid);
		var v = new Version(b, version_uuid);
		return "%.*s".printf(v.get_length(), v.read_as_string());
	}
}

public class SyncClient : Object {
	Wiz.BreadthFirstIterator iter;

	public Wiz.Store store { private get; construct; }

	public SyncClient(Wiz.Store store) {
		this.store = store;
		this.iter = new Wiz.BreadthFirstIterator();
	}

	public void pull(SyncSource server) throws GLib.FileError {
		var bits = server.list_all_objects();
		foreach (var bit in bits) {
			server.search_for_object(bit);

			var want = new Queue<string>();
			var do_not_want = new Queue<string>();
			var shas = server.search_for_shas(do_not_want);

			while (shas.length() > 0) {
				do_not_want = new Queue<string>();
				foreach (var sha in shas) {
					if (this.has_version(bit, sha))
						do_not_want.push_tail(sha);
					else
						want.push_tail(sha);
				}
				shas = server.search_for_shas(do_not_want);
			}

			debug("there are %u blobs to pull", want.get_length());
			while (want.get_length() > 0) {
				var uuid = want.pop_tail();

				var blob = server.grab_blob(bit, uuid);
				this.drop_raw(blob);

				this.drop_commit(bit, uuid, server.grab_commit(bit, uuid));
			}
		}
	}

	private bool has_version(string bit, string version) {
		var b = this.store.open_bit(bit);
		return b.has_version(version);
	}

	private bool matches (char* begin, string keyword) {
		char* keyword_array = keyword;
		long len = keyword.len ();
		for (int i = 0; i < len; i++)
			if (begin[i] != keyword_array[i])
				return false;
		return true;
	}

	void drop_commit(string bit_uuid, string uuid, string raw) {
		char *bufptr;
		long size;
		long mark;
		long pos;

		var c = new Commit();
		c.uuid = uuid;

		bufptr = (char *) raw;
		size = raw.len();

		if (!matches(bufptr, "blob "))
			return;

		mark = pos = 5;
		while (bufptr[pos] != '\n' && pos < size)
			pos ++;

		c.blob = ((string)bufptr).substring(mark, pos-mark);
		mark = pos = pos+1;

		while (matches(&bufptr[pos], "parent ")) {
			mark = pos = pos + 7;
			while (bufptr[pos] != '\n' && pos < size)
				pos ++;

			c.parents.append(((string)bufptr).substring(mark, pos-mark));
			mark = pos = pos+1;
		}

		if (!matches(&bufptr[pos], "committer "))
			return;

		mark = pos = pos+10;
		while (bufptr[pos] != '\n' && pos < size)
			pos ++;

		c.committer = ((string)bufptr).substring(mark, pos-mark);

		pos += 1;

		if (!matches(&bufptr[pos], "timestamp "))
			return;

		mark = pos = pos+10;
		while (bufptr[pos] != ' ' && pos < size)
			pos ++;
		string tmptimestamp = ((string)bufptr).substring(mark, pos-mark);
		c.timestamp = tmptimestamp.to_int();

		mark = pos = pos + 1;
		while (bufptr[pos] != '\n' && pos < size)
			pos ++;
		string tmptimestamp2 = ((string)bufptr).substring(mark, pos-mark);
		c.timestamp2 = tmptimestamp2.to_int();

		var bit = this.store.open_bit(bit_uuid);
		bit.commits.store_commit(c);
	}

	void drop_raw(string raw) throws GLib.FileError {
		Checksum sha1 = new Checksum(ChecksumType.SHA1);
		sha1.update((uchar [])raw, raw.len());
		string sha1_string = sha1.get_string();

		string drop_dir = Path.build_filename(this.store.directory, "objects", sha1_string.substring(0,2));
		if (!FileUtils.test(drop_dir, FileTest.IS_DIR))
			DirUtils.create_with_parents(drop_dir, 0755);
		string drop_path = Path.build_filename(drop_dir, sha1_string.substring(2));
		FileUtils.set_contents(drop_path, raw);
	}
}
