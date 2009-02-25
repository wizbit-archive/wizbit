using GLib;

namespace Wiz {

	public class CommitIterator : Object {
		public static delegate void Gatherer(CommitIterator iter, Commit v);
		Gatherer gather;

		List<Commit> visited;
		Queue<Commit> queue;
		Commit current;

		public CommitIterator(Gatherer gather) {
			this.visited = new List<Commit>();
			this.queue = new Queue<Commit>();
			this.gather = gather;
		}

		public bool have_visited(Commit version) {
			foreach (var v in this.visited)
				if (v.version_uuid == version.version_uuid)
					return true;
			return false;
		}

		public void prepend_queue(Commit version) {
			this.queue.push_head(version);
		}

		public void append_queue(Commit version) {
			this.queue.push_tail(version);
		}

		public void append_visited(Commit version) {
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
		
		public Commit get() {
			return this.current;
		}

		public static void DepthFirstGatherer(CommitIterator iter, Commit v) {
			// Visit each parent, depth first
			foreach (var p in v.parents)
				iter.prepend_queue(p);
		}

		public static void BreadthFirstGatherer(CommitIterator iter, Commit v) {
			// Visit each parent, breadth first
			foreach (var p in v.parents)
				iter.append_queue(p);
		}

		public static void MainlineGatherer(CommitIterator iter, Commit v) {
			// Visit the first parent
			if (v.parents.length() > 0)
				iter.append_queue(v.parents.nth_data(0));
		}

		public static void NoHuntGatherer(CommitIterator iter, Commit v) {
			// Don't queue any nodes to visit
		}
	}

}
