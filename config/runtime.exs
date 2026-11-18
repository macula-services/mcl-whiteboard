import Config

# Evaluated on every boot -- a local `iex -S mix`/`mix run` and a compiled
# release both run this file, so one config shape covers dev and prod. The
# only difference between environments is which env vars are actually set;
# defaults below are dev-safe (writable local paths, the io.macula realm) so
# a laptop boot needs no mesh secrets just to prove CMD/evoq wiring. The
# deployed container sets them for real: see deploy/docker-compose.yml for
# the run contract. Fleet placement lives in macula-io/macula-fleet.
data_dir = System.get_env("MCL_DATA_DIR", "/tmp/mcl-whiteboard-dev")

# THE REALM NAME IS THE ONE INPUT; THE TAG IS DERIVED FROM IT HERE.
# Topics carry the realm NAME as their first segment (macula_topic:app_fact/6)
# while mcl_om pins the pool to the realm TAG, sha256(name). mcl-warden takes
# both as separate variables and refuses to start when they disagree, because
# a sys.config cannot compute a hash. This file can, so the two can never
# disagree: a service publishing under one realm's topics while its pool sits
# in another would be silently unheard.
realm_name = System.get_env("MCL_REALM_NAME", "io.macula")
realm = :crypto.hash(:sha256, realm_name) |> Base.encode16(case: :lower)

# The org is the wire namespace every topic is built under (Org/App/...) and
# the org the realm delegates to this node after admission (D25). One org per
# service, named after the repository.
org = "mcl-whiteboard"

config :mcl_whiteboard,
  realm_name: realm_name

config :mcl_om,
  # Charlists, not Elixir binaries: these are file paths, and the dets/ra
  # layer under reckon-db rejects a binary `file` option with {badarg, ...}.
  # See MclWhiteboard.Service.event_store/0 for the fuller account.
  #
  # The service's own puzzle-hardened pq_hybrid node key. A MISSING file is
  # generated and persisted on first boot; the node id survives a container
  # recreate only because this path sits on a mounted volume.
  identity_key_path:
    String.to_charlist(
      System.get_env("MCL_IDENTITY_KEY_PATH", Path.join([data_dir, "identity", "identity.key"]))
    ),
  # /health on a Unix socket, not a port (mcl_om 0.39): the image's
  # HEALTHCHECK reaches it with curl --unix-socket, and no TCP listener is
  # opened just to be health-checked. /run is root's, so a TEST run takes a
  # socket in its own data dir; a local boot can override either with
  # MCL_HEALTH_SOCKET.
  health_socket:
    System.get_env(
      "MCL_HEALTH_SOCKET",
      if(config_env() == :test,
        do: Path.join(data_dir, "health.sock"),
        else: "/run/mcl/health.sock"
      )
    ),
  capability_topic: "_mesh.cap.",
  org: org,
  # The claim's labels (service name, box) are not set here: mcl_om reads
  # MCL_SERVICE_NAME and MCL_BOX itself, and falls back to this service's own
  # name. A default here would label every unset box "dev" on the realm desk.
  realm: realm,
  # THE TRUST ANCHOR: the realm's public signing key, hex. mcl_om pins it as
  # macula:connect/2's realm_trust and refuses to start a pool without it,
  # because a pool with no realm key resolves nothing org-namespaced while
  # looking healthy. Public material; it does not belong in the secrets
  # volume. Unset in a local dev boot, which then runs with no mesh pool.
  realm_key: System.get_env("MCL_REALM_KEY", "")

# THE PQ CRYPTO PROFILE, WITHOUT WHICH THIS NODE DOES NOT PEER. Without it the
# macula app boots on the classical profile and every PQ station closes the
# handshake as puzzle_invalid, silently. No puzzle_difficulty: macula 12
# refuses one at application start (it is one constant for the fleet).
config :macula,
  crypto_profile: :pq_hybrid

# MANDATORY because this service owns a store: MclWhiteboard.EventStore starts
# the per-store evoq subscription in MclWhiteboard.Application.start/2 before
# mcl_om:boot/1, and that subscription reads the global log through evoq, which
# crashes on {not_configured, event_store_adapter} without this block. evoq
# starts as a release-boot application before any service's start/2 runs, so
# nothing can inject it later. The store id here and
# MclWhiteboard.Service.event_store/0's id must agree; a test compares them.
config :evoq,
  event_store_adapter: :reckon_evoq_adapter,
  subscription_adapter: :reckon_evoq_adapter,
  snapshot_store_adapter: :reckon_evoq_adapter,
  store_id: :board_store

http_port = String.to_integer(System.get_env("MCL_HTTP_PORT", "4000"))

# WHERE THE WEB UI LISTENS, AND WHO MAY USE IT (mcl-whiteboard#15).
#
# The UI has no login: whoever opens its LiveView socket acts as this node,
# and every write goes over that socket. So:
#   - it listens on loopback unless the box says otherwise (MCL_HTTP_IP);
#   - the socket answers only the local origins on its port plus the ones
#     the box names (MCL_HTTP_ORIGINS, comma separated, //host:port);
#   - every request, the socket upgrade included, must name one of those
#     hosts (MclWhiteboardWeb.AllowedHosts), so a name an attacker rebinds to
#     the box's address gets 400 and cannot even read a page.
# Three settings refuse the boot, by name, rather than run a UI that would
# not do what the box meant: an address that does not parse; an address
# beyond loopback with no origins (every LAN socket would be refused, in a
# reconnect loop); and an origin that is not //host:port, a wildcard above
# all, which Phoenix would read as a whole domain.
http_ip_text = System.get_env("MCL_HTTP_IP", "127.0.0.1")

http_ip =
  case :inet.parse_address(String.to_charlist(http_ip_text)) do
    {:ok, ip} ->
      ip

    {:error, _} ->
      raise ArgumentError, "MCL_HTTP_IP=#{inspect(http_ip_text)} is not an IP address"
  end

http_origins =
  System.get_env("MCL_HTTP_ORIGINS", "")
  |> String.split(",", trim: true)
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))

origin_hosts =
  for origin <- http_origins do
    case Regex.run(~r<\A//([A-Za-z0-9.-]+|\[[0-9A-Fa-f:.]+\]):([0-9]{1,5})\z>, origin) do
      [_, host, _port] ->
        host

      nil ->
        raise ArgumentError,
              "MCL_HTTP_ORIGINS entry #{inspect(origin)} is not //host:port " <>
                "(no scheme, no path, no wildcard)"
    end
  end

loopback? =
  case http_ip do
    {127, _, _, _} -> true
    {0, 0, 0, 0, 0, 0, 0, 1} -> true
    _ -> false
  end

if not loopback? and http_origins == [] do
  raise ArgumentError,
        "MCL_HTTP_IP=#{inspect(http_ip_text)} serves beyond loopback, but MCL_HTTP_ORIGINS " <>
          "is empty: every socket from the LAN would be refused. Name the origins the LAN " <>
          "reaches the UI by, as //host:port"
end

local_hosts = ["localhost", "127.0.0.1", "[::1]"]
check_origin = Enum.map(local_hosts, &"//#{&1}:#{http_port}") ++ http_origins
# A request's host is compared in its bare form, without IPv6 brackets
# (MclWhiteboardWeb.AllowedHosts strips them from the request too).
allowed_hosts =
  for host <- local_hosts ++ origin_hosts,
      do: host |> String.trim_leading("[") |> String.trim_trailing("]")

# Signs the LiveView socket. A release REQUIRES it: a prod node that fell
# back to the fixed development value below would sign with a string anyone
# can read in this file. Dev and test get that value, which protects nothing
# and needs only to be 64+ bytes for Phoenix to accept it.
secret_key_base =
  if config_env() == :prod do
    System.fetch_env!("SECRET_KEY_BASE")
  else
    System.get_env(
      "SECRET_KEY_BASE",
      "mwbdev0000000000000000000000000000000000000000000000000000000000000000000000"
    )
  end

config :mcl_whiteboard_web, MclWhiteboardWeb.Endpoint,
  http: [ip: http_ip, port: http_port],
  check_origin: check_origin,
  allowed_hosts: allowed_hosts,
  server: true,
  secret_key_base: secret_key_base
