import dbus
import gobject
import avahi
import threading
import sys
from dbus.mainloop.glib import DBusGMainLoop

DBusGMainLoop( set_as_default=True )

"""
Class for publishing a service on DNS-SD using Avahi.
"""
class ServicePublisher (gobject.GObject):
    __gsignals__ = {
            'error': (gobject.SIGNAL_RUN_FIRST, gobject.TYPE_NONE,(gobject.TYPE_STRING,))
    }
    def __init__(self, name, type, port, txt = "", domain = "", host = ""):
        self.__gobject_init__()
        self._name = name
        self._type = type
        self._port = port
        self._txt = txt
        self._domain = ""
        self._host = ""
        self._group = None
        self._rename_count = 12 # Counter so we only rename after collisions a sensible number of times

        self._bus = dbus.SystemBus()

        self._server = dbus.Interface(
                self._bus.get_object( avahi.DBUS_NAME, avahi.DBUS_PATH_SERVER ),
                avahi.DBUS_INTERFACE_SERVER )

        self._server.connect_to_signal( 'StateChanged', self._server_state_changed )
        print "calling GetState"
        self._server_state_changed( self._server.GetState() )

    def __del__(self):
        if not self._group is None:
            self._group.Free()

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
                print "ERROR: No suitable service name found after %i retries" % n_rename
                self.emit("error", "Service name collision failure")
                self._remove_service()
        elif state == avahi.ENTRY_GROUP_FAILURE:
            print "Error in group state changed", error
            return

class ServiceBrowser(gobject.GObject):
    __gsignals__ = {
            'service-found': (gobject.SIGNAL_RUN_FIRST, gobject.TYPE_NONE,(gobject.TYPE_STRING, gobject.TYPE_STRING)),
            'service-removed': (gobject.SIGNAL_RUN_FIRST, gobject.TYPE_NONE,(gobject.TYPE_STRING, gobject.TYPE_STRING))
    }

    def __init__(self, type, domain = ""):
        self.__gobject_init__()
        bus = dbus.SystemBus()
        server = dbus.Interface(bus.get_object(avahi.DBUS_NAME, avahi.DBUS_PATH_SERVER), avahi.DBUS_INTERFACE_SERVER)
        print "creating service browser for ",type
        self._browser = dbus.Interface(bus.get_object(avahi.DBUS_NAME, server.ServiceBrowserNew(avahi.IF_UNSPEC, avahi.PROTO_INET, type, domain, dbus.UInt32(0))), avahi.DBUS_INTERFACE_SERVICE_BROWSER)
        self._browser.connect_to_signal('ItemNew', self._new_service)
        self._browser.connect_to_signal('ItemRemove', self._remove_service)
        self.services = {}


    def _new_service(self, interface, protocol, name, type, domain, flags):
        print "new service:",interface, protocol, name, type, domain, flags
        self.services[name]=type
        self.emit('service-found', name, type)

    def _remove_service(self, interface, protocol, name, type, domain, flags):
        print "remove service:", interface, protocol, name, type, domain, flags
        self.emit('service-removed', name, type)
        self.services.remove(name)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        name = sys.argv[1]
    else:
        name = "test"

    sp = ServicePublisher(name,"_test._tcp",1234)
    sb = ServiceBrowser("_test._tcp")

    mainloop = gobject.MainLoop()
    try:
        mainloop.run()
    except KeyboardInterrupt:
        pass
