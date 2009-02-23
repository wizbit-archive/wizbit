using GLib;

namespace Wiz {
	public class DepthFirstIterator : Object {
		List<Version> visited;
		Queue<Version> queue;
		Version current;

		public DepthFirstIterator() {
			this.visited = new List<Version>();
			this.queue = new Queue<Version>();
		}

		public bool have_visited(Version version) {
			foreach (var v in this.visited)
				if (v.version_uuid == version.version_uuid)
					return true;
			return false;
		}

		public void prepend_queue(Version version) {
			this.queue.push_head(version);
		}

		public void add_queue(Version version) {
			this.queue.push_tail(version);
		}

		public void add_visited(Version version) {
			this.visited.append(version);
		}

		public bool next() {
			var v = this.queue.pop_head();
			while (v!=null && this.have_visited(v))
				v = this.queue.pop_head();

			if (v == null)
				return false;

			foreach (var p in v.parents)
				this.prepend_queue(p);

			this.current = v;

			return true;
		}
		
		public Version get() {
			return this.current;
		}
	}
}
