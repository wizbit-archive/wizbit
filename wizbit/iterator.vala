/**
 * SECTION: iterator
 * @short_description: Iterating over history
 *
 * The #WizCommitIterator object is used when iterating over history.
 *
 * It provides the common code for iterating over history, such as not visiting a node
 * twice. A delegate, #WizCommitIteratorGatherer, is used to provide the specific iterating
 * behaviour, such as depth first or breadth first.
 */

using GLib;

namespace Wiz {

	/**
	 * WizCommitIterator:
	 *
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
		 * @self: The iterator to check
		 * @commit: The commit to check for
		 * @returns: true if we have visited this node already, false otherwise
		 */
		public bool have_visited(Commit commit) {
			foreach (var v in this.visited)
				if (v.version_uuid == commit.version_uuid)
					return true;
			return false;
		}

		/**
		 * wiz_commit_iterator_prepend_queue:
		 * @self: The iterator to update
		 * @commit: The commit to prepend to the queue
		 *
		 * Queues a #WizCommit to be visited next
		 */
		public void prepend_queue(Commit commit) {
			this.queue.push_head(commit);
		}

		/**
		 * wiz_commit_iterator_append_queue:
		 * @self: The iterator to update
		 * @commit: The commit to append to the queue
		 *
		 * Queues a #WizCommit to be visited last
		 */
		public void append_queue(Commit commit) {
			this.queue.push_tail(commit);
		}

		/**
		 * wiz_commit_iterator_append_visited:
		 * @self: The iterator to update
		 * @commit: The commit to append to the visited list
		 *
		 * Record that we have visited a #WizCommit or no longer
		 * need to visit it
		 */
		public void append_visited(Commit commit) {
			this.visited.append(commit);
		}

		/**
		 * wiz_commit_iterator_next:
		 * @self: The iterator to advance.
		 * @returns: True if there is a #WizCommit to look at, False otherwise
		 *
		 * Advances to the next #WizCommit
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
		 * @self: The iterator to access
		 * @returns: A @WizCommit for the current history point
		 */
		public new Commit get() {
			return this.current;
		}

		/**
		 * wiz_commit_iterator_depth_first:
		 * @iter: An iterator to update
		 * @commit: A commit to inspect
		 *
		 * A delegate that allows #WizCommitIterator to iterate over history
		 * depth first.
		 */
		public static void depth_first(CommitIterator iter, Commit commit) {
			// Visit each parent, depth first
			foreach (var p in commit.parents)
				iter.prepend_queue(p);
		}

		/**
		 * wiz_commit_iterator_breadth_first:
		 * @iter: An iterator to update
		 * @commit: A commit to inspect
		 *
		 * A delegate that allows #WizCommitIterator to iterate over history
		 * breadth first.
		 */
		public static void breadth_first(CommitIterator iter, Commit commit) {
			// Visit each parent, breadth first
			foreach (var p in commit.parents)
				iter.append_queue(p);
		}

		/**
		 * wiz_commit_iterator_mainline:
		 * @iter: An iterator to update
		 * @commit: A commit to inspect
		 *
		 * A delegate that allows #WizCommitIterator to iterate over the mainline
		 * of history.
		 */
		public static void mainline(CommitIterator iter, Commit commit) {
			// Visit the first parent
			if (commit.parents.length() > 0)
				iter.append_queue(commit.parents.nth_data(0));
		}

		/**
		 * wiz_commit_iterator_no_hunt:
		 * @iter: An iterator to update
		 * @commit: A commit to inspect
		 *
		 * A delegate that no-ops the #WizCommit gathering part of #WizCommitIterator.
		 *
		 * This allows the user to finely control which #WizCommit objects to visit,
		 * but take advantage of the iterator boilerplate and 'have visited' logic.
		 */
		public static void no_hunt(CommitIterator iter, Commit commit) {
			// Don't queue any nodes to visit
		}
	}

}
