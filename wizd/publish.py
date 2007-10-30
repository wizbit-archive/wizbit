import dbus
import gobject
import avahi
import threading
import sys
from dbus.mainloop.glib import DBusGMainLoop

"""
Class for publishing a service on DNS-SD using Avahi.
Creates a thread to handle requests
"""
class ServicePublisher (threading.Thread):
    def __init__(self, name, type, port, txt = "", domain = "", host = ""):
        threading.Thread.__init__(self)

        gobject.threads_init()
        self._name = name
        self._type = type
        self._port = port
        self._txt = txt
        self._domain = ""
        self._host = ""
        self._group = None
        self._rename_count = 12 # Counter so we only rename after collisions a sensible number of times

    def run(self):
        DBusGMainLoop( set_as_default=True )
        self._main_loop = gobject.MainLoop()
        self._bus = dbus.SystemBus()

        self._server = dbus.Interface(
                self._bus.get_object( avahi.DBUS_NAME, avahi.DBUS_PATH_SERVER ),
                avahi.DBUS_INTERFACE_SERVER )

        self._server.connect_to_signal( "StateChanged", self._server_state_changed )
        self._server_state_changed( self._server.GetState() )

        self._main_loop.run()

        if not self._group is None:
            self._group.Free()

    def stop(self):
        self._main_loop.quit()

    def _add_service(self):
        if self._group is None:
            self._group = dbus.Interface(
                    self._bus.get_object( avahi.DBUS_NAME, self._server.EntryGroupNew()),
                    avahi.DBUS_INTERFACE_ENTRY_GROUP)
            self._group.connect_to_signal('StateChanged', self._entry_group_state_changed)

        print "Adding service '%s' of type '%s' ..." % (self._name, self._type)

        self._group.AddService(
                avahi.IF_UNSPEC,    #interface
                avahi.PROTO_UNSPEC, #protocol
                0,                  #flags
                self._name, self._type,
                self._domain, self._host,
                dbus.UInt16(self._port),
                avahi.string_array_to_txt_array(self._txt))
        self._group.Commit()

    def _remove_service(self):
        if not self._group is None:
            self._group.Reset()

    def _server_state_changed(self, state):
        if state == avahi.SERVER_COLLISION:
            print "WARNING: Server name collision"
            self._remove_service()
        elif state == avahi.SERVER_RUNNING:
            self._add_service()

    def _entry_group_state_changed(self, state, error):
        print "state change: %i" % state

        if state == avahi.ENTRY_GROUP_ESTABLISHED:
            print "Service established."
        elif state == avahi.ENTRY_GROUP_COLLISION:
            self._rename_count = self._rename_count - 1
            if rename_count > 0:
                name = server.GetAlternativeServiceName(name)
                print "WARNING: Service name collision, changing name to '%s' ..." % name
                self._remove_service()
                self._add_service()

            else:
                print "ERROR: No suitable service name found after %i retries, exiting." % n_rename
                self._main_loop.quit()
        elif state == avahi.ENTRY_GROUP_FAILURE:
            print "Error in group state changed", error
            self._main_loop.quit()
            return

if __name__ == "__main__":
    sp = ServicePublisher("test","_test._tcp",1234)
    sp.start()

    chr = sys.stdin.read(1)
    sp.stop()


