using GLib;
using Wizbit;

public class SyncServer : Object {
	public store { private get; construct; }

	SyncServer(Wizbit.Store store) {
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
	
}

void test_sync(void)
{
	
}
