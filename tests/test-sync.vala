using GLib;
using Wizbit;

public class SyncServer : Object {
	public Wizbit.Store store { private get; construct; }

	public SyncServer(Wizbit.Store store) {
		this.store = store;
	}

	public List<Version> do_you_have(List<Version> versions) {
		var retval = new List<Version>();
		foreach (val v in versions)
			if (false)
				retval.append(v);
		return retval;
	}
}

public class SyncClient : Object {
	public Wizbit.Store store { private get; construct; }

	public SyncClient(Wizbit.Store store, SyncServer server) {
		this.store = store;
	}

	construct {
		this.iter = Wizbit.BreadthFirstIterator();
	}

	public void sync(SyncServer server) {
		int size = 4;
		while (!this.iter.end) {
			List<Version> list = self.iter.get(size);
			foreach (var v in server.do_you_have( list ) ) {
				/* foreach (var p in v.parents)
					self.iter.kick_out(p);*/
				self.iter.kick_out(v.previous);
			}
			size *= 2;
		}
	}
}

void test_sync(void)
{
	var a = new Wiz.Store("some_uuid", "data/sync_a");

	var z = a.create_bit();
	var a18 = z.create_next_version_from_string("18");
	var a17 = z.create_next_version_from_string("17");
	var a16 = z.create_next_version_from_string("16");
	var a15 = z.create_next_version_from_string("15");
	var a14 = z.create_next_version_from_string("14");
	var a13 = z.create_next_version_from_string("13", a18);
	var a12 = z.create_next_version_from_string("12", a17);
	var a11 = z.create_next_version_from_string("11", a16);
	var a10 = z.create_next_version_from_string("10", a14); // [a14, a15]);
	var a9 = z.create_next_version_from_string("9", a10); // [a10, a11]);
	var a8 = z.create_next_version_from_string("8", a13);
	var a7 = z.create_next_version_from_string("7", a12);
	var a6 = z.create_next_version_from_string("6", a9);
	var a5 = z.create_next_version_from_string("5", a9);
	var a4 = z.create_next_version_from_string("4", a8);
	var a3 = z.create_next_version_from_string("3", a7);
	var a2 = z.create_next_version_from_string("2", a6);
	var a1 = z.create_next_version_from_string("1", a5);
	// a.tips = [a1, a2, a3, a4]

	/*
	var b = new Wiz.Store("some_uuid", "data/sync_b");
	b18 = y.create_next_version_from_string("18");
	b16 = y.create_next_version_from_string("16");
	b15 = y.create_next_version_from_string("15");
	b14 = y.create_next_version_from_string("14");
	b13 = y.create_next_version_from_string("13", [b18]);
	b11 = y.create_next_version_from_string("11", [b16]);
	b10 = y.create_next_version_from_string("10", [b14, b15]);
	b9 = y.create_next_version_from_string("9", [b10, b11]);
	b8 = y.create_next_version_from_string("8", [b13]);
	b6 = y.create_next_version_from_string("6", [b9]);
	b4 = y.create_next_version_from_string("4", [b8]);
	// b.tips = [b6, b4]
	*/
}
