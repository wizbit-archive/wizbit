"""
This is a test implementation of Wizbit sync using mock objects.

The first phases uses a Breadth First Search on the mock DAG to exchange
a list of SHA1's with another mock DAG. When we encounter a commit that is
in both DAG's, the system knows it no longer has to visit parents of that
commit.

The number of SHA1's in each pass grows to try and minimize excessive round
tripping.

Once the SHA1's have been exchanged (either by running the process twice in
both directions, or by deriving the state from the conversation in the first
pass), the actual objects are exchanged.

When the object store is synchronized, we sync the tips. Somehow...
"""

class Commit(object):
    """
    Dummy commit object for testing our sync alg
    """

    def __init__(self, sha1, parents=[]):
        self.sha1 = sha1
        self.blob = "Here is some data\n" + sha1
        self.parents = parents

class Store(object):
    """
    Dummy store object for testing our sync alg
    """

    def __init__(self):
        self.store = {}
        self.tips = []

    def has(self, sha1):
        """
        has
        @sha1: Object to look for in store
        """
        return sha1 in self.store

    def get(self, sha1):
        """
        get
        @sha1: sha1 of object to retrieve
        """
        if self.has(sha1): return self.store[sha1]

    def commit(self, sha1, parents=[]):
        """
        commit
        @sha1: A sha1 for the commit to create
        @parents: A list of parents for the commit
        """
        commit = Commit(sha1, parents)
        self.store[sha1] = commit
        return commit

class BreadthFirstIterator(object):

    def __init__(self, store, queue):
        self.store = store
        self.queue = queue[:]
        self.visited = {}
        self.is_depleted = False

    def next(self):
        """
        next

        Actually does a breadth first search over the DAG.

        self.visited is used to keep track of which nodes we have already visited.
        This means we won't visit a node twice if branching occurs.

        self.queue is used to keep track of which nodes to visit next. We pop from
        the front and append parents to the end. This creates the effect of moving
        sideways over the DAG. Vala implementation can use GQueue.
        """
        # safe guard in case someone isn't suing is_depleted flag
        if len(self.queue) == 0:
            return None

        # find a node in the queue that we haven't already visited
        p = self.queue.pop(0)
        while p:
            if p.sha1 not in self.visited:
                break
            p = self.queue.pop(0)

        # queue up more nodes to visit
        for x in p.parents:
            self.queue.append(x)

        # record that we have visited this node and shouldn't go there again
        self.visited[p.sha1] = p

        # if the queue is empty, set the EOF marker
        # (just so we can while (!is_depleted) { p = next(); do_stuff(p); })
        if len(self.queue) == 0:
            self.is_depleted = True

        return p

    def get(self, size):
        """
        get
        @size: How many objects to retrieve from the iterator

        Calls next() size times, or until we have no more data.
        """
        i = size
        retval = []
        while i > 0 and not self.is_depleted:
            retval.append(self.next())
            i -= 1
        return retval

    def kick_out(self, sha_list):
        """
        kick_out
        @sha_list: A list of sha1's to remove from the queue. This will also
        remove parent commit objects from the queue.

        The current implementation relies on an assumption that we get a full
        list of sha1s to kick out, rather than just the top commits to kick out.
        This should be possible to fix, just too asleep to think of when we would
        stop iterating for more parents to kick out...
        Ahh, iterate through your parents until you hit a parent that isn't in your
        visited list.
        """
        # its got 3 loops! KILL IT!
        for sha1 in sha_list:
            commit = self.visited[sha1]
            for parent in commit.parents:
                for x in self.queue[:]:
                    if x.sha1 == parent.sha1:
                        self.queue.remove(x)
                        break

class SyncServer(object):

    def __init__(self, store):
        self.store = store

    def what_do_you_have(self, sha_list):
        """
        what_do_you_have
        @sha_list: A list of sha1's from a client that it has and whats to know if you do

        This function takes a list of sha1's and checks for their presence in the store.
        It returns a list of the ones that it does
        """
        retval = []
        for sha1 in sha_list:
            if self.store.has(sha1):
                retval.append(sha1)
        print "i already have: ", retval
        return retval

class SyncClient(object):

    def __init__(self, store):
        self.store = store
        self.iter = BreadthFirstIterator(store, store.tips)

    def sync(self, server):
        """
        sync
        @server: A 'server' to sync to

        Currently, we just do a sha1 exchange based on a breadth first search of the DAG.
        This allows the client to work out which objects it is missing. The initial
        implementation requires this to be run once in each direction, but the server
        should be able to BFS itself (with data received from client in the visited list)
        and end up knowing the objects both sides of the sync are missing (i.e. a list of
        objects to send and a list of objects to ask for)

        When this process is run, the client knows what objects the server is missing and
        can transmit them. Eventually, this will make use of packs...

        Eventually, the server will be able to work out what objects the client is missing
        and transmit those.

        The number of sha1's exchanged increases with each pass to try and avoid roundtrips.
        """
        size = len(self.store.tips)
        while not self.iter.is_depleted:
            sha_list = [x.sha1 for x in self.iter.get(size)]
            print "you can have: ", sha_list
            self.iter.kick_out( server.what_do_you_have(sha_list) )
            size *= 2

if __name__ == "__main__":
    a = Store()
    a18 = a.commit("18")
    a17 = a.commit("17")
    a16 = a.commit("16")
    a15 = a.commit("15")
    a14 = a.commit("14")
    a13 = a.commit("13", [a18])
    a12 = a.commit("12", [a17])
    a11 = a.commit("11", [a16])
    a10 = a.commit("10", [a14, a15])
    a9 = a.commit("9", [a10, a11])
    a8 = a.commit("8", [a13])
    a7 = a.commit("7", [a12])
    a6 = a.commit("6", [a9])
    a5 = a.commit("5", [a9])
    a4 = a.commit("4", [a8])
    a3 = a.commit("3", [a7])
    a2 = a.commit("2", [a6])
    a1 = a.commit("1", [a5])
    a.tips = [a1, a2, a3, a4]

    b = Store()
    b18 = b.commit("18")
    b16 = b.commit("16")
    b15 = b.commit("15")
    b14 = b.commit("14")
    b13 = b.commit("13", [b18])
    b11 = b.commit("11", [b16])
    b10 = b.commit("10", [b14, b15])
    b9 = b.commit("9", [b10, b11])
    b8 = b.commit("8", [b13])
    b6 = b.commit("6", [b9])
    b4 = b.commit("4", [b8])
    b.tips = [b6, b4]

    bx = SyncServer(b)
    ax = SyncClient(a)
    ax.sync(bx)
