using GLib;

namespace Wiz {
	public class BreadthFirstIterator : Object {
		List<Version> visited;
		Queue<Version> queue;

		public bool end { get; private set; default = false; }

		construct {
			this.visited = new List<Version>();
			this.queue = new Queue<Version>();
		}

		public void add_version(Version v) {
			this.queue.push_tail(v);
		}

		bool have_visited(Version v) {
			foreach (var visited in this.visited)
				if (v.version_uuid == visited.version_uuid)
					return true;
			return false;
		}

		public Version next() {
			var p = this.queue.pop_head();
			while(p!=null && !this.have_visited(p))
				p = this.queue.pop_head();

			/*foreach (var p in popped.parents) {
				this.queue.append(p);
			}*/
			if (p.previous != null)
				this.queue.push_tail(p.previous);

			if (this.queue.get_length() == 0)
				this.end = true;

			return p;
		}

		public void kick_out(Version v) {
			for (int i = 0; i < this.queue.get_length(); i++) {
				if (v.version_uuid == this.queue.peek_nth(i).version_uuid) {
					this.queue.pop_nth(i);
					break;
				}
			}
			if (this.queue.get_length() == 0)
				this.end = true;
		}
	}
}
