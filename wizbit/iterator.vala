using GLib;

namespace Wiz {

	/**
	 * WizCommitIterator:
	 * A generic iterator object for browsing over history
	 */
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

		/**
		 * wiz_commit_iterator_have_visited:
		 * @returns: true if we have visited this node already, false otherwise
		 */
		public bool have_visited(Commit version) {
			foreach (var v in this.visited)
				if (v.version_uuid == version.version_uuid)
					return true;
			return false;
		}

		/**
		 * wiz_commit_iterator_prepend_queue:
		 * Queues a @WizCommit to be visited next
		 */
		public void prepend_queue(Commit version) {
			this.queue.push_head(version);
		}

		/**
		 * wiz_commit_iterator_append_queue:
		 * Queues a @WizCommit to be visited last
		 */
		public void append_queue(Commit version) {
			this.queue.push_tail(version);
		}

		/**
		 * wiz_commit_iterator_append_visited:
		 * Record that we have visited a @WizCommit or no longer
		 * need to visit it
		 */
		public void append_visited(Commit version) {
			this.visited.append(version);
		}

		/**
		 * wiz_commit_iterator_next:
		 * @returns: True if there is a @WizCommit to look at, False otherrwise
		 * Advance to the next @WizCommit
		 */
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
		
		/**
		 * wiz_commit_iterator_get:
		 * @returns: A @WizCommit for the current history point
		 */
		public Commit get() {
			return this.current;
		}

		/**
		 * wiz_commit_iterator_depth_first:
		 * A delegate that allows @WizCommitIterator to iterate over history
		 * depth first.
		 */
		public static void depth_first(CommitIterator iter, Commit v) {
			// Visit each parent, depth first
			foreach (var p in v.parents)
				iter.prepend_queue(p);
		}

		/**
		 * wiz_commit_iterator_breadth_first:
		 * A delegate that allows @WizCommitIterator to iterate over history
		 * breadth first.
		 */
		public static void breadth_first(CommitIterator iter, Commit v) {
			// Visit each parent, breadth first
			foreach (var p in v.parents)
				iter.append_queue(p);
		}

		/**
		 * wiz_commit_iterator_mainline:
		 * A delegate that allows @WizCommitIterator to iterate over the mainline
		 * of history.
		 */
		public static void mainline(CommitIterator iter, Commit v) {
			// Visit the first parent
			if (v.parents.length() > 0)
				iter.append_queue(v.parents.nth_data(0));
		}

		/**
		 * wiz_commit_iterator_no_hunt:
		 * A delegate that no-ops the @WizCommit gathering part of @WizCommitIterator.
		 *
		 * This allows the user to finely control which @WizCommit objects to visit,
		 * but take advantage of the iterator boilerplate and 'have visited' logic.
		 */
		public static void no_hunt(CommitIterator iter, Commit v) {
			// Don't queue any nodes to visit
		}
	}

}
