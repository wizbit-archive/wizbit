import pyinotify
import gobject


class GNotifier(pyinotify.Notifier):
    """
    A notifier that can be attached to a mainloop
    """
    def __init__(self, watch_manager, default_proc_fun=ProcessEvent()):
        """
        Initialization.

        @param watch_manager: Watch Manager.
        @type watch_manager: WatchManager instance
        @param default_proc_fun: Default processing method.
        @type default_proc_fun: instance of ProcessEvent
        """
        pyinotify.Notifier.__init__(self, watch_manager, default_proc_fun)
        self._handler = gobject.io_add_watch(self._fd, gobject.IO_IN, self._process_io)

    def _process_io(self):
        self.read_events()
        self.process_events()

    def stop(self):
        gobject.source_remove(self._handler)
        pyinotify.Notifier.stop(self)
