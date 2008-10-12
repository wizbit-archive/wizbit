using GLib;
using Wiz;

public class SyncSource : Object {
	public Wiz.Store store { private get; construct; }

	uint size;
	Wiz.BreadthFirstIterator iter;

	public SyncSource(Wiz.Store store) {
		this.store = store;
	}

	public void search_for_all_objects() {
		var objs = new List<string>();

		/* at the moment we don't have api to list objects so lets enum
		 * ths tips folder
		 */
		var path = Path.build_filename(this.store.directory, "refs");
		var dir = Dir.open(path);
		var f = dir.read_name();
		while (f != null) {
			objs.append(f);
			f = dir.read_name();
		}

		this.search_for_objects(objs);
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
		 */
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

	public List<string> search_for_shas(Queue<string> versions) {
		/*
		 * search_for_shas
		 * @versions: A list of versions to kick out of the iterator
		 * 
		 * Returns: A list of versions found by the breadth first search
		 */
		for (uint i = 0; i < versions.get_length(); i++) {
			var v = versions.peek_nth(i);
			var wz = this.store.open_version("rarar", v);
			this.iter.kick_out(wz);
		}

		var retval = new List<string>();
		var found = this.iter.get(this.size);
		foreach (var f in found) {
			retval.append(f.version_uuid);
		}
		this.size *= 2;
		debug("%u", retval.length());
		return retval;
	}

	public string grab_commit(string version_uuid) {
		string outstr;
		uint outlen;
                string drop_path = Path.build_filename(this.store.directory, "objects", version_uuid.substring(0,2), version_uuid.substring(2, 40));
                FileUtils.get_contents(drop_path, out outstr, out outlen);
		return outstr;
	}

	public string grab_blob(string version_uuid) {
		var v = this.store.open_version("nomnom", version_uuid);
		return v.read_as_string();
	}

	public List<string> grab_tips(string bit_uuid) {
		var b = this.store.open_bit(bit_uuid);
		var retval = new List<string>();
		if (b.primary_tip != null) {
			retval.append(b.primary_tip.version_uuid);
			foreach (var t in b.tips) {
				if (t.version_uuid != b.primary_tip.version_uuid)
					retval.append(t.version_uuid);
			}
		}

		return retval;
	}
}

public class SyncClient : Object {
	Wiz.BreadthFirstIterator iter;

	public Wiz.Store store { private get; construct; }

	public SyncClient(Wiz.Store store) {
		this.store = store;
	}

	construct {
		this.iter = new Wiz.BreadthFirstIterator();
	}

	public void pull(SyncSource server) {
		/* Tell the server what objects we are interested in pulling */
		server.search_for_all_objects();

		var want = new Queue<string>();
		var do_not_want = new Queue<string>();
		var shas = server.search_for_shas(do_not_want);

		while (shas.length() > 0) {
			do_not_want = new Queue<string>();
			foreach (var sha in shas) {
				if (this.store.has_version(sha))
					do_not_want.push_tail(sha);
				else
					want.push_tail(sha);
			}
			shas = server.search_for_shas(do_not_want);
		}

		debug("there are %u blobs to pull", want.get_length());
		while (want.get_length() > 0) {
			var uuid = want.pop_tail();
			this.drop_raw(uuid, server.grab_commit(uuid));
			this.drop_raw(uuid, server.grab_blob(uuid));
		};
	}

	void drop_raw(string uuid, string raw) {
		string drop_path = Path.build_filename(this.store.directory, "objects", uuid.substring(0,2), uuid.substring(2, 40));
		FileUtils.set_contents(drop_path, raw);
	}
}
