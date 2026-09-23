# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [SemVer](https://semver.org/).

## [Unreleased]

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
