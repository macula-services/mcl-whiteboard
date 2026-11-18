defmodule MclWhiteboardWeb.AllowedHosts do
  @moduledoc """
  Answers 400, before anything else runs, to a request whose host is not one
  the UI is served under (mcl-whiteboard#15, T2).

  The UI has no login, so a name an attacker rebinds to the box's address
  would otherwise be same-origin with it: it could read every page, tokens
  included. The allowed hosts are the local ones plus the hosts named in
  `MCL_HTTP_ORIGINS`, built in `config/runtime.exs` from the same parse as
  the socket's `check_origin`, so the two lists cannot disagree.

  It runs AHEAD OF PHOENIX'S SOCKET DISPATCH. `use Phoenix.Endpoint` puts
  `plug :socket_dispatch` before every plug an endpoint declares, so a plug in
  the endpoint's body would never see a socket upgrade. The endpoint instead
  wraps its whole `call/2` with this module's `__before_compile__/1`,
  registered after `use Phoenix.Endpoint`, so its `call/2` is the outermost.
  """
  import Plug.Conn

  @doc "The request as it was when its host is allowed; halted with 400 when it is not."
  @spec check(Plug.Conn.t(), [String.t()]) :: Plug.Conn.t()
  def check(conn, allowed_hosts) do
    if bare(conn.host) in allowed_hosts do
      conn
    else
      conn |> send_resp(400, "") |> halt()
    end
  end

  defp bare(host), do: host |> String.trim_leading("[") |> String.trim_trailing("]")

  defmacro __before_compile__(_env) do
    quote do
      defoverridable call: 2

      def call(conn, opts) do
        case MclWhiteboardWeb.AllowedHosts.check(conn, config(:allowed_hosts) || []) do
          %Plug.Conn{halted: true} = refused -> refused
          allowed -> super(allowed, opts)
        end
      end
    end
  end
end
