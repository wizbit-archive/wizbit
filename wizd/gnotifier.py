import pyinotify
import gobject


class GNotifier(pyinotify.Notifier):
    """
    A notifier that can be attached to a mainloop
    """
    def __init__(self, watch_manager, default_proc_fun=pyinotify.ProcessEvent()):
        """
        Initialization.

        @param watch_manager: Watch Manager.
        @type watch_manager: WatchManager instance
        @param default_proc_fun: Default processing method.
        @type default_proc_fun: instance of ProcessEvent
        """
        pyinotify.Notifier.__init__(self, watch_manager, default_proc_fun)
        self._handler = gobject.io_add_watch(self._fd, gobject.IO_IN, self._process_io)

    def _process_io(self, foo, bar):
        self.read_events()
        self.process_events()
        return True

    def stop(self):
        gobject.source_remove(self._handler)
        pyinotify.Notifier.stop(self)

if __name__ == "__main__":
    import sys

    wm = pyinotify.WatchManager()
    n = GNotifier(wm)

    if len(sys.argv) > 1:
        name = sys.argv[1]
    else:
        name = "/tmp"
    wm.add_watch(name, pyinotify.EventsCodes.ALL_EVENTS, rec=True, auto_add=True)

    mainloop = gobject.MainLoop()
    try:
        mainloop.run()
    except KeyboardInterrupt:
        pass
