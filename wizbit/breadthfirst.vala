using GLib;

namespace Wiz {
	public class BreadthFirstIterator : Object {
		List<Version> visited;
		Queue<Version> queue;

		public bool end { get; private set; default = true; }

		public BreadthFirstIterator() {
			this.visited = new List<Version>();
			this.queue = new Queue<Version>();
		}

		public void add_version(Version v) {
			this.queue.push_tail(v);
			this.end = false;
		}

		public void add_visited(Version v) {
			this.visited.append(v);
		}

		bool have_visited(Version v) {
			foreach (var visited in this.visited)
				if (v.version_uuid == visited.version_uuid)
					return true;
			return false;
		}

		public Version? next() {
			var p = this.queue.pop_head();
			while(p!=null && this.have_visited(p))
				p = this.queue.pop_head();

			if (p == null)
				return null;

			foreach (var par in p.parents)
				this.queue.push_tail(par);

			if (this.queue.get_length() == 0)
				this.end = true;

			this.add_visited(p);

			return p;
		}

		public List<Version> get(uint size) {
			var retval = new List<Version>();
			var i = size;
			while (i > 0 && !this.end) {
				var foo = this.next();
				if (foo == null) {
					this.end = true;
					continue;
				}
				retval.append(foo);
				i--;
			}
			return retval;
		}

		public void kick_out(Version v) {
			for (int i = 0; i < this.queue.get_length(); i++) {
				if (v.version_uuid == this.queue.peek_nth(i).version_uuid) {
					this.queue.pop_nth(i);
					break;
				}

				foreach (var p in v.parents) {
					if (p.version_uuid == this.queue.peek_nth(i).version_uuid) {
						this.queue.pop_nth(i);
						break;
					}
				}
			}
			if (this.queue.get_length() == 0)
				this.end = true;
		}
	}
}
