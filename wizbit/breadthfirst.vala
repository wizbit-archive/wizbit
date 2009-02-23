using GLib;

namespace Wiz {
	public class BreadthFirstIterator : Object {
		List<Version> visited;
		Queue<Version> queue;
		Version current;

		public BreadthFirstIterator() {
			this.visited = new List<Version>();
			this.queue = new Queue<Version>();
		}

		public void add_version(Version v) {
			this.queue.push_tail(v);
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

		public bool next() {
			var p = this.queue.pop_head();
			while(p!=null && this.have_visited(p))
				p = this.queue.pop_head();

			if (p == null)
				return false;

			foreach (var par in p.parents)
				this.queue.push_tail(par);

			this.add_visited(p);
			this.current = p;

			return true;
		}

		public Version get() {
			return this.current;
		}

		public List<Version> get_multiple(uint size) {
			var retval = new List<Version>();
			var i = size;
			while (this.next() && i > 0) {
				retval.append(this.get());
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
		}
	}
}
