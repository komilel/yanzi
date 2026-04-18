"""urix — клиентский транспорт (unix socket, non-blocking)."""

import json
import select
import socket

from urix_rpc import encode_request, parse_message

DEFAULT_SOCKET = "/run/urix.sock"


class UrixClient:
    def __init__(self, sock_path=DEFAULT_SOCKET):
        self.sock_path = sock_path
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(sock_path)
        self.sock.setblocking(False)
        self._buf = b""
        self._next_id = 1

    def send(self, method, params=None):
        """Send an RPC request. Returns the request id."""
        req_id = self._next_id
        self._next_id += 1
        msg = encode_request(method, params, req_id)
        self.sock.sendall(msg.encode())
        return req_id

    def subscribe(self):
        """Subscribe to server events."""
        return self.send("subscribe")

    def poll(self):
        """Non-blocking read. Returns list of parsed messages."""
        messages = []
        try:
            while True:
                data = self.sock.recv(65536)
                if not data:
                    raise ConnectionError("Сервер отключился")
                self._buf += data
        except BlockingIOError:
            pass

        while b"\n" in self._buf:
            line, self._buf = self._buf.split(b"\n", 1)
            msg = parse_message(line)
            if msg:
                messages.append(msg)
        return messages

    def call_sync(self, method, params=None, timeout=10):
        """Blocking RPC call. Returns result dict or raises."""
        req_id = self.send(method, params)
        # Switch to blocking with timeout for this call
        self.sock.setblocking(True)
        self.sock.settimeout(timeout)
        try:
            while True:
                # Read from buffer first
                while b"\n" in self._buf:
                    line, self._buf = self._buf.split(b"\n", 1)
                    msg = parse_message(line)
                    if msg and msg.get("id") == req_id:
                        if "error" in msg:
                            raise RuntimeError(msg["error"].get("message", "RPC error"))
                        return msg.get("result")
                    # Ignore events and other responses in sync mode

                data = self.sock.recv(65536)
                if not data:
                    raise ConnectionError("Сервер отключился")
                self._buf += data
        finally:
            self.sock.setblocking(False)

    def fileno(self):
        """For use with select.select()."""
        return self.sock.fileno()

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()
