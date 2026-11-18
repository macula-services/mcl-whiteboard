defmodule MclWhiteboardWeb.AllowedHostsTest do
  # mcl-whiteboard#15, R1: a request whose host is not one the UI is served
  # under gets 400 before anything else runs, a socket upgrade included. The
  # upgrade case talks to the running server over TCP and sends an ALLOWED
  # origin with a foreign host: a 400 there can only come from the host check
  # running ahead of Phoenix's socket dispatch, because the origin check would
  # have let the upgrade through.
  use ExUnit.Case, async: false

  import Plug.Test

  alias MclWhiteboardWeb.AllowedHosts
  alias MclWhiteboardWeb.Endpoint

  defp port, do: Endpoint.config(:http)[:port]

  defp raw_request(lines) do
    {:ok, socket} = :gen_tcp.connect(~c"127.0.0.1", port(), [:binary, active: false])
    :ok = :gen_tcp.send(socket, Enum.join(lines, "\r\n") <> "\r\n\r\n")
    {:ok, reply} = :gen_tcp.recv(socket, 0, 5_000)
    :gen_tcp.close(socket)
    reply |> String.split("\r\n") |> hd()
  end

  defp upgrade(host, origin) do
    raw_request([
      "GET /live/websocket?vsn=2.0.0 HTTP/1.1",
      "Host: #{host}",
      "Origin: #{origin}",
      "Upgrade: websocket",
      "Connection: Upgrade",
      "Sec-WebSocket-Version: 13",
      "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ=="
    ])
  end

  test "a page asked for under a foreign host is refused with 400" do
    conn = Endpoint.call(conn(:get, "http://attacker.example/boards"), [])
    assert conn.halted
    assert conn.status == 400
  end

  test "a socket upgrade with an allowed origin but a foreign host is refused with 400" do
    assert upgrade("attacker.example:#{port()}", "http://localhost:#{port()}") ==
             "HTTP/1.1 400 Bad Request"
  end

  test "the same upgrade under a local host is not refused by the host check" do
    assert upgrade("localhost:#{port()}", "http://localhost:#{port()}") ==
             "HTTP/1.1 101 Switching Protocols"
  end

  test "an IPv6 loopback host is allowed, with or without its brackets" do
    allowed = Endpoint.config(:allowed_hosts)

    for host <- ["[::1]", "::1", "localhost", "127.0.0.1"] do
      refute AllowedHosts.check(%Plug.Conn{host: host}, allowed).halted, host
    end
  end

  test "the server answers a page under [::1] with its port" do
    refute raw_request(["GET /boards HTTP/1.1", "Host: [::1]:#{port()}"]) ==
             "HTTP/1.1 400 Bad Request"
  end
end
