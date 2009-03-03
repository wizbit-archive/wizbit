/**
 * SECTION: breadthfirst
 * @short_description: Breadth first iteration for sync
 *
 * This code provides a deprecated breadth first iterator which is used
 * by the sync code.
 */

using GLib;

namespace Wiz {
	public class BreadthFirstIterator : Object {
		List<Commit> visited;
		Queue<Commit> queue;
		Commit current;

		public BreadthFirstIterator() {
			this.visited = new List<Commit>();
			this.queue = new Queue<Commit>();
		}

		public void add_version(Commit v) {
			this.queue.push_tail(v);
		}

		public void add_visited(Commit v) {
			this.visited.append(v);
		}

		bool have_visited(Commit v) {
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

		public Commit get() {
			return this.current;
		}

		public List<Commit> get_multiple(uint size) {
			var retval = new List<Commit>();
			var i = size;
			while (this.next() && i > 0) {
				retval.append(this.get());
				i--;
			}
			return retval;
		}

		public void kick_out(Commit v) {
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
