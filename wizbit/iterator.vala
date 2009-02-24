using GLib;

namespace Wiz {

	public class VersionIterator : Object {
		public static delegate void Gatherer(VersionIterator iter, Version v);
		Gatherer gather;

		List<Version> visited;
		Queue<Version> queue;
		Version current;

		public VersionIterator(Gatherer gather) {
			this.visited = new List<Version>();
			this.queue = new Queue<Version>();
			this.gather = gather;
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

		public void append_queue(Version version) {
			this.queue.push_tail(version);
		}

		public void append_visited(Version version) {
			this.visited.append(version);
		}

		public bool next() {
			var v = this.queue.pop_head();
			while (v!=null && this.have_visited(v))
				v = this.queue.pop_head();

			if (v == null)
				return false;

			gather(this, v);

			this.current = v;
			this.append_visited(v);

			return true;
		}
		
		public Version get() {
			return this.current;
		}

		public static void DepthFirstGatherer(VersionIterator iter, Version v) {
			// Visit each parent, depth first
			foreach (var p in v.parents)
				iter.prepend_queue(p);
		}

		public static void BreadthFirstGatherer(VersionIterator iter, Version v) {
			// Visit each parent, breadth first
			foreach (var p in v.parents)
				iter.append_queue(p);
		}

		public static void MainlineGatherer(VersionIterator iter, Version v) {
			// Visit the first parent
			if (v.parents.length() > 0)
				iter.append_queue(v.parents.nth_data(0));
		}

		public static void NoHuntGatherer(VersionIterator iter, Version v) {
			// Don't queue any nodes to visit
		}
	}

}