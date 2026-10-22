# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [SemVer](https://semver.org/).

## Unreleased

- **The base library is macula 16** (macula-codebase-checks#4): the floors move
  `~> 15.6` to `~> 16.0` and `mcl_om` to `~> 1.4`, the release whose own base
  is macula 16 (`~> 1.0` also admits 1.3.0, which requires macula `~> 15.6`:
  macula-codebase-checks#14). 16.0 keeps wire 1.0, so this service still
  speaks to every wire 1.0 box; what it adds is the revocation bound
  (macula#118). This service gates no overlay and issues no endorsement.


## [Unreleased]

### Changed

- **Wire 1.0: `mcl_om` 1.2 and macula 15.6, the line the fleet runs since
  the flag day (2026-10-19).** A wire 1.0 node neither reads a 14 node's
  frames nor completes a handshake with it, so this is taken on purpose: the
  `~> 0.x` floor could not float here on its own (mcl-om#27). No call site
  changed.
- **The service opens its own reckon-db store before it boots.** `mcl_om`
  opens no store since 0.35.0 (mcl-om#10): a service module exporting
  `store_id/0` and `data_dir/0` no longer gets one, and only a warning at
  boot names the callbacks. `MclWhiteboard.Application.start/2` now opens the
  store first (`MclWhiteboard.EventStore`), waits until reckon-db lists it,
  and starts the per-store evoq subscription; the store's id, directory,
  indexes, mode and integrity live in `MclWhiteboard.Service.event_store/0`,
  the old callback pair is gone, and the app declares `reckon_db`, `evoq` and
  `reckon_evoq` itself. Without this the bump compiles clean, boots green and
  has no store at all, losing every board at its first touch.

## [0.1.0] - 2026-10-05

The first release: a board hosted on one node, joined and drawn on from another
across the mesh.

### Changed

- On mcl_om 0.28 and macula 12.2, which mcl_om 0.28 requires. The service now
  advertises `mcl-whiteboard/info` (mcl_om's, on every service); a test asks the
  booted service and carries the answer through macula's frame codec.
- No rocksdb anywhere: mcl_om 0.27 dropped barrel_docdb, and this service never
  used it itself. The barrel data_dir setting, the compression libraries in the
  builder and CI, and libsnappy in the runtime are gone.
- The claim's labels come from `MCL_SERVICE_NAME` / `MCL_BOX`, read by mcl_om
  itself; the old `box` default of "dev" would have labelled every unset box
  that way on the realm's desk.

### Added

- The whiteboard on macula 12, post-quantum only, over `mcl_om` 0.26. It replaces
  the archived `hecate-whiteboard`, whose repository keeps the earlier history.
- Mesh topics in macula's canonical five-segment form,
  `{realm}/mcl-whiteboard/whiteboard/{domain}/{name}_v1`, built in one place
  (`WhiteboardTopic`) and owned by the module that produces each fact.
- Board list and snapshot queries answer on one fixed reply topic each, matched by
  a `request_id` in the payload, instead of a topic minted per request.
- Every standing mesh subscription is declared once
  (`MclWhiteboard.Service.subscriptions/0`) and kept running by mcl_om, which also
  restarts them after a full pool replacement.
- `replay_policy/0` on every evoq event handler: the mesh emitters skip replay,
  the ETS projections rebuild from it. A test fails a handler with no policy.
- A refused rename keeps the old title and shows why, and a refused shape write
  is logged instead of discarded.
- Gates: format, compile with warnings as errors, credo, tests and dialyzer in the
  pinned `macula-ci-pq` image. The image is pushed only after its release is
  checked against the dependency versions the tests resolved.
- Erlang distribution on loopback only, with a cookie the box supplies; a release
  refuses to start without `RELEASE_COOKIE` or `SECRET_KEY_BASE`.
- Every pushed image digest is signed keyless with cosign, with its SBOM (SPDX) and
  SLSA provenance attested. `:latest` moves only on a `v*` tag, to the signed
  digest.
