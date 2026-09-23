# mcl-whiteboard

A real-time, multi-user whiteboard over the [macula](https://github.com/macula-io/macula)
mesh. It works like Miro, except that there is no central server. A host runs this
service on their own node (a laptop, a home box, a lab machine), and collaborators
on other nodes find that host's boards over the mesh and draw on them live. If the
host goes offline, its boards go with it. That is the deliberate trade for not
needing anyone else's server.

It runs on macula 12, post-quantum only, and stands on
[`mcl_om`](https://github.com/macula-services/mcl-om), the substrate shared by every
`macula-services/mcl-*` service. It replaces the archived
[`hecate-whiteboard`](https://github.com/hecate-services/hecate-whiteboard), whose
repository keeps the design notes and build history.

## What you can do

- Host boards on your node, and initiate, rename, archive and unarchive them
  (`/boards`).
- Draw freehand strokes, place sticky notes and text, draw rectangles, ellipses,
  triangles and arrows, and move and remove shapes (`/board/:board_id`).
- See every board hosted anywhere on the mesh, updated live as hosts initiate,
  host, rename and archive them.
- Join a board hosted on another node. You get a snapshot of it, then live updates,
  and you can draw on it: your writes are relayed to its host, which stays the one
  authority for that board.
- See the live cursors of everyone viewing the same board.

## Architecture

An Elixir/Phoenix umbrella of six OTP applications, sliced vertically:

| App | Department | Owns |
|---|---|---|
| `guide_board_lifecycle` | CMD | The `board` aggregate and one desk per command: `initiate_board`, `host_board`, `rename_board`, `archive_board`, `unarchive_board`, `draw_stroke`, `draw_geometry`, `place_sticky`, `place_text`, `move_shape`, `remove_shape`, `leave_board`. The mesh emitters, the write-relay answerers, and `WhiteboardTopic`. |
| `project_boards` | PRJ | ETS read models (`boards`, `board_shapes`) built from the event store, plus the mesh subscribers that absorb other hosts' facts |
| `query_boards` | QRY | `get_board_snapshot_by_id`, `list_hosted_boards`, `list_archived_boards`, and the mesh queries `get_board_snapshot_by_id_over_mesh` and `list_boards_over_mesh` with their answerers |
| `track_presence` | none | Live cursors: an ETS roster with a sweep. Deliberately not event-sourced (see below) |
| `mcl_whiteboard` | service | The `mcl_om_service` implementation: identity, realm, health, the board store and every standing mesh subscription |
| `mcl_whiteboard_web` | UI | Phoenix LiveView: the board picker and the canvas (HTML5 Canvas, no npm dependencies) |

The departments start before `mcl_whiteboard`, which runs `:mcl_om.boot/1`. That
call opens the board store (reckon-db through evoq) and declares the service's
mesh subscriptions (`MclWhiteboard.Service.subscriptions/0`). mcl_om then keeps
those subscriptions running, and re-checks them every 30 seconds.

### Design decisions

**One authority per board, not a CRDT.** The hosting node is the one sequencer
for its board: an evoq aggregate with a single writer. A peer that joined a board
relays its writes to the host (`*_request` topics). The aggregate's own
`not_hosted` guard makes every other node ignore them, and the host's accepted
events come back to everyone through the normal fact path.

**Presence is not event-sourced.** Who is viewing and where their cursor rests is
ephemeral session state. It lives in `track_presence`'s ETS roster, is aged out by
a sweep, and crosses the mesh as `cursor_settled` facts that are never stored. The
one exception is a graceful exit: `leave_board` records `peer_departed_v1`,
because someone choosing to leave a session is a business fact, and a silent
timeout is not.

**Late join is a snapshot, not a replay.** A joining node asks the mesh for a
board's snapshot, and only the host answers. The reply carries `as_of_version`,
the host aggregate's stream version, and shapes are keyed by `shape_id`, so a
shape that raced the snapshot over the live subscription is not applied twice.

**Event shape on the wire.** An evoq event handler receives the stored record
(`event_type`, `stream_id`, `version`, `data`, ...), with the event's own fields
nested under `data`, and keys may be atoms or binaries after the store round trip.
Every projection and emitter here unwraps `data` and reads both key shapes.

**Replay.** evoq 1.24 hands every event handler the store's whole history again
on boot. The mesh emitters declare `replay_policy/0` as `:skip`, so a restart
republishes nothing. The ETS projections declare `:deliver`, because replay is how
they are rebuilt. A test fails any handler that declares no policy.

### Mesh contract

Every topic is built by `GuideBoardLifecycle.WhiteboardTopic` through
`macula_topic:app_fact/6`:
`{realm}/mcl-whiteboard/whiteboard/{domain}/{name}_v1`. IDs travel in the payload,
never in the topic. The producer of a fact owns its topic, and consumers call the
producer's `topic/0` or `topics/0`.

| Domain | Topic names | Kind |
|---|---|---|
| `board` | `board_initiated`, `board_hosted`, `board_archived`, `board_unarchived`, `board_renamed` | facts from the host |
| `shape` | `shape_initiated`, `shape_amended`, `shape_removed` | facts from the host |
| `shape` | `draw_stroke_request`, `shape_mutation_request` | write relays to the host |
| `presence` | `cursor_settled`, `peer_departed` | facts |
| `presence` | `leave_board_request` | write relay to the host |
| `query` | `board_list_query`, `board_list_reply`, `board_snapshot_query`, `board_snapshot_reply` | queries and their replies |

Each query has one fixed reply topic. The asker mints a `request_id`, and every
answer echoes it, so the asker keeps only the replies to its own request.

The service announces no RPC capability. Everything a peer does with a board
travels over pubsub, because the board list and snapshot queries must reach every
host, not one provider.

## Running locally

Requires Elixir 1.18 on OTP 28.4.3 with an OpenSSL that serves ML-DSA (see
`.tool-versions`), a Rust toolchain for macula's NIFs, and the snappy, zstd and
lz4 development libraries for rocksdb. The simplest route is the pinned CI image,
`ghcr.io/macula-io/macula-ci-pq:ex118-20260923-1444`.

```bash
mix deps.get
mix test
MCL_DATA_DIR=/tmp/mcl-whiteboard-dev mix run scripts/smoke_test.exs
```

The smoke test boots the service against a real local reckon-db store, dispatches
`initiate_board` and then `archive_board`, and checks that a second archive is
refused. It needs no mesh: with `MCL_REALM_KEY` unset the node runs without a
pool.

To see the canvas:

```bash
mix esbuild.install --if-missing
mix esbuild mcl_whiteboard_web
mix esbuild mcl_whiteboard_web_css
MCL_DATA_DIR=/tmp/mcl-whiteboard-dev mix phx.server
# open http://localhost:4000
```

### Configuration

| Variable | Default | Meaning |
|---|---|---|
| `MCL_REALM_NAME` | `io.macula` | The realm. Its tag, sha256 of the name, is derived from it |
| `MCL_REALM_KEY` | none | The realm's public signing key, hex. Required for a mesh pool |
| `MACULA_STATION_SEEDS` / `MACULA_STATION_NODE_IDS` | none | Station hosts and their pinned node ids, comma-separated, paired by position |
| `MCL_DATA_DIR` | `/tmp/mcl-whiteboard-dev` | Board store and read models |
| `MCL_IDENTITY_KEY_PATH` | `$MCL_DATA_DIR/identity/identity.key` | The node identity key, generated on first boot |
| `MCL_HEALTH_PORT` / `MCL_HTTP_PORT` | `8491` / `4000` | Health endpoint and web UI |
| `MCL_SERVICE_NAME` / `MCL_BOX` | `mcl-whiteboard` / `dev` | Labels the realm operator sees |
| `SECRET_KEY_BASE` | dev value | Signs the LiveView socket. Required in a release |
| `RELEASE_COOKIE` | none | The box's own Erlang cookie. Required in a release; distribution is loopback-only |

## Gates

CI (`.github/workflows/ci.yml`) runs in the pinned `macula-ci-pq` image: format,
`compile --warnings-as-errors`, credo, tests, dialyzer. Only then does it build the
image, check that the release carries exactly the dependency versions the tests
resolved (`scripts/assert_release_matches_lock.sh`), and push.

## Image and deployment

`ghcr.io/macula-services/mcl-whiteboard`: `:main` and `:<sha>` from `main`, and
`:<X.Y.Z>` from a `vX.Y.Z` tag. There is no `:latest`. The `Containerfile` builds
on the same pinned image the gates ran in, and runs on `macula-pq-runtime` from
the same build.

`deploy/docker-compose.yml` is the service's run contract: its image, ports,
volumes and environment. Placement (which box, which station, which realm key)
belongs in `macula-io/macula-fleet`. The service is not deployed anywhere yet.

## License

Apache-2.0. See [LICENSE](LICENSE).
