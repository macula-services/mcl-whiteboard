defmodule MclWhiteboardWeb.SocketOriginTest do
  # mcl-whiteboard#15, Done when: a socket from a foreign origin is refused
  # with 403 and a local one is accepted. The UI has no login, so whoever opens
  # the LiveView socket acts as this node: only the local origins on the UI's
  # port (plus the ones MCL_HTTP_ORIGINS names) may. This asks Phoenix's own
  # origin check with the endpoint's running config, so `check_origin: false`
  # put back fails here. The last test pins the image's loopback default.
  use ExUnit.Case, async: true

  import Plug.Test

  alias MclWhiteboardWeb.Endpoint
  alias Phoenix.Socket.Transport

  defp port, do: Endpoint.config(:http)[:port]

  defp from(origin) do
    :get
    |> conn("/live/websocket")
    |> Plug.Conn.put_req_header("origin", origin)
    |> Transport.check_origin(Phoenix.LiveView.Socket, Endpoint, [], & &1)
  end

  test "a local origin on the UI's port opens the socket" do
    for host <- ["localhost", "127.0.0.1", "[::1]"] do
      refute from("http://#{host}:#{port()}").halted, host
    end
  end

  test "any other origin is refused with 403, null and a rebound name included" do
    for origin <- ["http://attacker.example:#{port()}", "http://box.example:#{port()}", "null"] do
      conn = from(origin)
      assert conn.halted, origin
      assert conn.status == 403, origin
    end
  end

  test "the image listens on loopback unless the box says otherwise" do
    containerfile = File.read!(Path.expand("../../../Containerfile", __DIR__))
    assert containerfile =~ ~r/^ENV MCL_HTTP_IP=127\.0\.0\.1$/m
    refute containerfile =~ "MCL_HTTP_IP=0.0.0.0"
  end
end
