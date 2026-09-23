import Config

# Evaluated on every boot -- a local `iex -S mix`/`mix run` and a compiled
# release both run this file, so one config shape covers dev and prod. The
# only difference between environments is which env vars are actually set;
# defaults below are dev-safe (writable local paths, the io.macula realm) so
# a laptop boot needs no mesh secrets just to prove CMD/evoq wiring. The
# deployed container sets them for real: see deploy/docker-compose.yml for
# the run contract. Fleet placement lives in macula-io/macula-fleet.
data_dir = System.get_env("MCL_DATA_DIR", "/tmp/mcl-whiteboard-dev")
health_port = String.to_integer(System.get_env("MCL_HEALTH_PORT", "8491"))

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
  # See MclWhiteboard.Service.data_dir/0 for the fuller account.
  #
  # The service's own puzzle-hardened pq_hybrid node key. A MISSING file is
  # generated and persisted on first boot; the node id survives a container
  # recreate only because this path sits on a mounted volume.
  identity_key_path:
    String.to_charlist(
      System.get_env("MCL_IDENTITY_KEY_PATH", Path.join([data_dir, "identity", "identity.key"]))
    ),
  health_port: health_port,
  capability_topic: "_mesh.cap.",
  org: org,
  # Informational labels the realm operator sees on this service's
  # provider-authorization row (never trusted).
  service_name: System.get_env("MCL_SERVICE_NAME", "mcl-whiteboard"),
  box: System.get_env("MCL_BOX", "dev"),
  realm: realm,
  # THE TRUST ANCHOR: the realm's public signing key, hex. mcl_om pins it as
  # macula:connect/2's realm_trust and refuses to start a pool without it,
  # because a pool with no realm key resolves nothing org-namespaced while
  # looking healthy. Public material; it does not belong in the secrets
  # volume. Unset in a local dev boot, which then runs with no mesh pool.
  realm_key: System.get_env("MCL_REALM_KEY", "")

# barrel_docdb (mcl_om's read-model store) otherwise writes under a path
# relative to the working directory: outside the data volume in a container,
# so its databases would not survive a recreate, and into the checkout in dev.
config :barrel_docdb,
  data_dir: String.to_charlist(Path.join(data_dir, "barrel_docdb"))

# THE PQ CRYPTO PROFILE, WITHOUT WHICH THIS NODE DOES NOT PEER. Without it the
# macula app boots on the classical profile and every PQ station closes the
# handshake as puzzle_invalid, silently. No puzzle_difficulty: macula 12
# refuses one at application start (it is one constant for the fleet).
config :macula,
  crypto_profile: :pq_hybrid

# MANDATORY because MclWhiteboard.Service exports store_id/0.
# mcl_om:boot/1 starts the store AND a per-store evoq subscription,
# which crashes on {not_configured, event_store_adapter} if this block is
# absent -- see mcl_om_store's own module header.
config :evoq,
  event_store_adapter: :reckon_evoq_adapter,
  subscription_adapter: :reckon_evoq_adapter,
  snapshot_store_adapter: :reckon_evoq_adapter,
  store_id: :board_store

http_port = String.to_integer(System.get_env("MCL_HTTP_PORT", "4000"))

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
  http: [ip: {0, 0, 0, 0}, port: http_port],
  server: true,
  secret_key_base: secret_key_base
