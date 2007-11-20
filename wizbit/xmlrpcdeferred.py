import gobject

import xmlrpclib

class XMLRPCDeferred (gobject.GObject):
    """Object representing the delayed result of an XML-RPC
    request.

    .is_ready: bool
      True when the result is received; False before then.
    .value : any
      Once is_ready=True, this attribute contains the result of the
      request.  If this value is an instance of the xmlrpclib.Fault
      class, then some exception occurred during the request's
      processing.

    """
    __gsignals__ = {
            'ready': (gobject.SIGNAL_RUN_FIRST, gobject.TYPE_NONE, ())
    }
    def __init__ (self, transport, http):
        self.__gobject_init__()
        self.transport = transport
        self.http = http
        self.value = None
        self.is_ready = False

        sock = self.http._conn.sock
        self.src_id = gobject.io_add_watch(sock,
                                           gobject.IO_IN | gobject.IO_HUP,
                                           self.handle_io)

    def handle_io (self, source, condition):
        # Triggered when there's input available on the socket.
        # The assumption is that all the input will be available
        # relatively quickly.
        self.read()

        # Returning false prevents this callback from being triggered
        # again.  We also remove the monitoring of this file
        # descriptor.
        gobject.source_remove(self.src_id)
        return False

    def read (self):
        errcode, errmsg, headers = self.http.getreply()

        if errcode != 200:
            raise ProtocolError(
                host + handler,
                errcode, errmsg,
                headers
                )

        try:
            result = xmlrpclib.Transport._parse_response(self.transport,
                                                         self.http.getfile(), None)
        except xmlrpclib.Fault, exc:
            result = exc

        self.value = result
        self.is_ready = True
        self.emit('ready')

    def __len__ (self):
        # XXX egregious hack!!!
        # The code in xmlrpclib.ServerProxy calls len() on the object
        # returned by the transport, and if it's of length 1 returns
        # the contained object.  Therefore, this __len__ method
        # returns a completely fake length of 2.
        return 2 


class GXMLRPCTransport (xmlrpclib.Transport):
    def request(self, host, handler, request_body, verbose=0):
        # issue XML-RPC request

        h = self.make_connection(host)
        if verbose:
            h.set_debuglevel(1)

        self.send_request(h, handler, request_body)
        self.send_host(h, host)
        self.send_user_agent(h)
        self.send_content(h, request_body)

        self.verbose = verbose

        return XMLRPCDeferred(self, h)

