"""Generate mcl-whiteboard's two C4 diagrams into assets/.

Run:  python3 architecture/c4_diagrams.py

  c4-context.svg     Level 1: what the service talks to
  c4-components.svg  Level 2: what it is made of

Drawn from the code, never from a template: the six umbrella apps under apps/,
the callbacks and subscriptions in lib/mcl_whiteboard/service.ex, the desks of
each department, the router and LiveViews, the dependencies in the apps'
mix.exs files, the ports and volumes in the Containerfile and
deploy/docker-compose.yml. When one of those changes, the diagram changes in the
same commit.

Colours are plain classes with a prefers-color-scheme: dark block, no CSS custom
properties (rsvg-convert renders those black), so the SVGs render the same on
GitHub, in IDE previews and through rsvg-convert. After a change, render each
(rsvg-convert -w 1400 assets/c4-context.svg -o /tmp/c.png) and look at it; keep
architecture/README.md's tables in step.
"""
import os
from xml.sax.saxutils import escape

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")

SANS = '"Atkinson Hyperlegible", "Segoe UI", system-ui, -apple-system, Helvetica, Arial, sans-serif'
MONO = '"JetBrains Mono", ui-monospace, Menlo, Consolas, monospace'

# Element kinds, each (light fill, light stroke, dark fill, dark stroke).
KINDS = {
    "b-sys": ("#F5E9CC", "#A56F0A", "#3A2E13", "#E3AA3C"),   # in scope
    "b-per": ("#E3EBF2", "#3B5B7A", "#1D2A36", "#8EB4D8"),   # person
    "b-mac": ("#E6E4EE", "#5E5A78", "#26243A", "#A9A4C8"),   # Macula infrastructure
    "b-ext": ("#ECEFED", "#8A9791", "#1C2421", "#7D8B85"),   # external system
    "b-cmp": ("#FFFFFF", "#8A9791", "#171F1C", "#7D8B85"),   # component or container
}

STYLE = f"""<style>
.t-name {{ font-family: {SANS}; font-size: 15px; font-weight: 700; }}
.t-desc {{ font-family: {SANS}; font-size: 12.5px; }}
.t-rel {{ font-family: {SANS}; font-size: 11.5px; paint-order: stroke; stroke-width: 4px; stroke-linejoin: round; }}
.t-code {{ font-family: {MONO}; font-size: 13px; font-weight: 600; }}
.t-type {{ font-family: {MONO}; font-size: 11.5px; }}
.t-bound {{ font-family: {MONO}; font-size: 12px; font-weight: 600; }}
.t-leg {{ font-family: {SANS}; font-size: 12px; }}
.edge {{ fill: none; stroke-width: 1.25; }}
.edge-later {{ fill: none; stroke-width: 1.25; stroke-dasharray: 5 4; }}
.bg {{ fill: #FFFFFF; }}
""" + "".join(f".{k} {{ fill: {v[0]}; stroke: {v[1]}; stroke-width: {2 if k == 'b-sys' else 1.25}; }}\n" for k, v in KINDS.items()) + """\
.b-later { fill: none; stroke: #8A9791; stroke-width: 1.25; stroke-dasharray: 5 4; }
.bound { fill: none; stroke: #B3BDB8; stroke-width: 1; }
.head { fill: #3B5B7A; }
.t-name, .t-code { fill: #16201D; }
.t-type, .t-bound, .t-leg { fill: #66736E; }
.t-desc { fill: #34413C; }
.t-rel { fill: #66736E; stroke: #FFFFFF; }
.edge, .edge-later { stroke: #8A9791; }
.arrowhead { fill: #8A9791; }
@media (prefers-color-scheme: dark) {
.bg { fill: #171F1C; }
""" + "".join(f".{k} {{ fill: {v[2]}; stroke: {v[3]}; }}\n" for k, v in KINDS.items()) + """\
.b-later { stroke: #7D8B85; }
.bound { stroke: #4A5752; }
.head { fill: #8EB4D8; }
.t-name, .t-code { fill: #E6ECE9; }
.t-type, .t-bound, .t-leg { fill: #93A09A; }
.t-desc { fill: #C3CDC8; }
.t-rel { fill: #93A09A; stroke: #171F1C; }
.edge, .edge-later { stroke: #7D8B85; }
.arrowhead { fill: #7D8B85; }
}
</style>"""

DEFS = ('<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
        'orient="auto-start-reverse"><path class="arrowhead" d="M0 0L10 5L0 10z"/></marker></defs>')

LEGEND = [("b-sys", "In scope"), ("b-per", "Person"), ("b-mac", "Macula infrastructure"),
          ("b-ext", "External system"), ("b-cmp", "Container or component")]
BOUNDARY = ("bound", "Boundary")


class Diagram:
    def __init__(self, name, title, w, h):
        self.name, self.title, self.w, self.h, self.parts = name, title, w, h, []

    def text(self, cls, x, y, s, anchor=None, rotate=None):
        a = f' text-anchor="{anchor}"' if anchor else ""
        r = f' transform="rotate({rotate} {x} {y})"' if rotate is not None else ""
        self.parts.append(f'<text class="{cls}" x="{x}" y="{y}"{a}{r}>{escape(s)}</text>')

    def box(self, cls, x, y, w, h, name, kind, desc, person=False, code=False):
        # A box that is too small for its own words renders as text on top of the
        # next box, which no test would catch and a reader would read as the
        # diagram saying something it does not. Fail here instead.
        need = 70 + 16 * max(len(desc) - 1, 0) + 18
        if h < need:
            raise ValueError(f"{self.name}: {name} needs height {need}, has {h}")
        for line in desc:
            if 16 + 6.2 * len(line) > w - 16:
                raise ValueError(f"{self.name}: {name}: '{line}' is wider than {w - 32}px")
        self.parts.append(f'<rect class="{cls}" x="{x}" y="{y}" width="{w}" height="{h}" rx="10"/>')
        tx = x + 16
        if person:
            self.parts.append(f'<circle class="head" cx="{x + 26}" cy="{y + 24}" r="9"/>')
            tx = x + 44
        self.text("t-code" if code else "t-name", tx, y + 28, name)
        self.text("t-type", tx, y + 46, kind)
        for i, line in enumerate(desc):
            self.text("t-desc", x + 16, y + 70 + 16 * i, line)

    def bound(self, x, y, w, h, label):
        self.parts.append(f'<rect class="bound" x="{x}" y="{y}" width="{w}" height="{h}" rx="12"/>')
        self.text("t-bound", x + 16, y + 22, label)

    def edge(self, d, later=False):
        self.parts.append(f'<path class="{"edge-later" if later else "edge"}" d="{d}" marker-end="url(#a)"/>')

    def legend(self, y, boundary=True):
        x = 24
        for cls, label in LEGEND + ([BOUNDARY] if boundary else []):
            self.parts.append(f'<rect class="{cls}" x="{x}" y="{y}" width="22" height="14" rx="3"/>')
            self.text("t-leg", x + 30, y + 12, label)
            x += 34 + 6.6 * len(label)

    def write(self):
        svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" role="img" '
               f'aria-label="{escape(self.title)}">', f"<title>{escape(self.title)}</title>", STYLE, DEFS,
               f'<rect class="bg" x="0" y="0" width="{self.w}" height="{self.h}"/>'] + self.parts + ["</svg>", ""]
        with open(os.path.join(OUT, self.name), "w") as f:
            f.write("\n".join(svg))


def context():
    d = Diagram("c4-context.svg", "mcl-whiteboard system context", 1100, 780)
    d.box("b-per", 40, 30, 300, 136, "Board host", "[Person]",
          ["Runs this service on their own node", "and opens /boards in a browser",
           "on port 4000. Their node is the", "authority for the boards it hosts."], person=True)
    d.box("b-per", 740, 30, 300, 136, "Collaborator", "[Person]",
          ["Finds a board over the mesh, gets", "a snapshot, then live updates, and",
           "draws on it: the writes are relayed", "to the host."], person=True)
    d.box("b-sys", 390, 230, 320, 152, "mcl-whiteboard", "[mcl_om mesh service]",
          ["Hosts boards and serves the canvas", "on 4000, publishes every board and",
           "shape fact, and relays a remote", "peer's writes to the board's host.",
           "One release, six OTP apps."])
    d.box("b-mac", 40, 470, 300, 152, "macula-realm", "[Macula infrastructure]",
          ["Endorses the node's identity key and", "grants a provider authorization for",
           "each org procedure it advertises,", "info and get_limits included."])
    d.box("b-mac", 390, 470, 320, 136, "Macula stations, mesh DHT", "[Macula infrastructure]",
          ["The pinned seeds in", "MACULA_STATION_SEEDS carry every fact,",
           "write relay and query (QUIC); the", "DHT keeps a record per org procedure."])
    d.box("b-ext", 740, 470, 300, 152, "Another host's node", "[External system]",
          ["Another box running this service,", "and the authority for its boards.",
           "The list query is answered by every", "host with boards; the snapshot query",
           "only by that board's host."])

    d.edge("M190 166V200H430V230")
    d.text("t-rel", 198, 180, "opens the canvas on port 4000")
    d.edge("M950 166V200H670V230")
    d.text("t-rel", 940, 192, "joins a board, local or remote", anchor="end")
    d.edge("M470 382V420H190V470")
    d.text("t-rel", 300, 412, "boot claim, scope mcl-whiteboard", anchor="middle")
    d.edge("M550 382V470")
    d.text("t-rel", 558, 404, "board and shape facts,")
    d.text("t-rel", 558, 420, "write relays and queries")
    d.edge("M710 300H890V470")
    d.text("t-rel", 718, 292, "queries reach every host")
    d.text("t-desc", 40, 640, "Nothing outside the mesh is called: the board list and the snapshots come from other hosts over pubsub.")
    d.text("t-desc", 40, 658, "The service serves no procedure of its own, and capabilities/0 is empty. mcl_om adds the open")
    d.text("t-desc", 40, 676, "pair every service carries: mcl-whiteboard/info and mcl-whiteboard/get_limits.")
    d.legend(716, boundary=False)
    d.write()


def components():
    d = Diagram("c4-components.svg", "mcl-whiteboard components", 1160, 1382)
    d.bound(16, 40, 1128, 886, "mcl-whiteboard [Container: one OTP release, six apps]")

    d.box("b-cmp", 32, 70, 540, 120, "MclWhiteboard.Application", "[OTP application]",
          ["Opens the board store from MclWhiteboard.Service.event_store/0, then calls",
           ":mcl_om.boot/1. The four other apps are runtime deps, so their projections",
           "and event handlers are registered before the store subscription delivers."], code=True)
    d.box("b-sys", 32, 238, 540, 136, "MclWhiteboard.Service", "[mcl_om_service behaviour]",
          ["The six callbacks plus subscriptions/0, the whole desired set of standing",
           "mesh subscriptions, which mcl_om re-checks on a timer. capabilities/0 is",
           "empty: everything a peer does with a board goes over pubsub, not RPC. Its",
           "scope is mcl-whiteboard, and health/0 is green while the tree is up."], code=True)
    d.box("b-cmp", 32, 422, 540, 104, "MclWhiteboard.Supervisor", "[supervisor, one_for_one]",
          ["No children, and that is the honest shape: the departments are sibling OTP",
           "apps with their own trees, and evoq starts board aggregates on demand."], code=True)
    d.box("b-cmp", 32, 590, 540, 152, "MclWhiteboardWeb", "[Phoenix LiveView, phoenix ~> 1.8, bandit ~> 1.12]",
          ["The Endpoint on MCL_HTTP_PORT (4000) and the Router: / is the default board,",
           "/board/:board_id is any board, local or remote, and /boards is the picker.",
           "BoardLive runs the HTML5 Canvas with no npm dependencies; BoardsLive lists",
           "this node's boards. They read through the query desks, call the CMD desks'",
           "Maybe modules and TrackPresence.Roster, and follow Phoenix.PubSub for updates."], code=True)

    d.box("b-cmp", 588, 70, 540, 136, "MclWhiteboard.EventStore", "[reckon-db store, single node]",
          ["Opened by MclWhiteboard.Application before :mcl_om.boot/1. Id board_store is",
           "also named as store_id in the evoq block of config/runtime.exs, and a test",
           "compares them. The directory is a charlist, because the dets/ra layer below",
           "reckon_db rejects a binary. Mode single, no indexes, integrity disabled."], code=True)
    d.box("b-cmp", 588, 238, 540, 152, "GuideBoardLifecycle", "[CMD app, event sourced]",
          ["board_aggregate and one desk per command: initiate_board, host_board,",
           "rename_board, archive_board, unarchive_board, draw_stroke, draw_geometry,",
           "place_sticky, place_text, move_shape, remove_shape and leave_board. The mesh",
           "emitters (BoardLifecycleV1ToMesh, ShapeLifecycleV1ToMesh, PeerDepartedV1ToMesh)",
           "and the write-relay answerers, with WhiteboardTopic naming every topic."], code=True)
    d.box("b-cmp", 588, 422, 540, 136, "ProjectBoards", "[PRJ app]",
          ["ProjectBoards.Store holds two ETS read models, boards and board_shapes.",
           "BoardLifecycleToBoards and ShapeLifecycleToBoardShapes rebuild them from the",
           "store, and the mesh subscribers absorb other hosts' facts. It also starts",
           "MclWhiteboardWeb.PubSub, so the registry exists before any event arrives."], code=True)
    d.box("b-cmp", 588, 590, 540, 152, "QueryBoards", "[QRY app]",
          ["get_board_snapshot_by_id, list_hosted_boards and list_archived_boards read",
           "the ETS models. get_board_snapshot_by_id_over_mesh and list_boards_over_mesh",
           "ask the mesh and take the host's answer, echoed by request_id; the answerers",
           "are the queries' other half. The snapshot carries as_of_version, so a shape",
           "that raced it over the live subscription is not applied twice."], code=True)
    d.box("b-cmp", 588, 774, 540, 120, "TrackPresence", "[no department, deliberately not event sourced]",
          ["Roster keeps the live cursors in ETS, Sweep ages them out, and",
           "CursorMeshSubscriber and PeerDepartedMeshSubscriber take other hosts' facts.",
           "Ephemeral by design: a cursor is never stored."], code=True)

    d.edge("M200 190V238"); d.text("t-rel", 208, 230, "boots with")
    d.edge("M200 374V422"); d.text("t-rel", 208, 414, "start/1 starts")
    d.edge("M572 132H588"); d.text("t-rel", 570, 124, "opens first", anchor="end")
    d.edge("M572 300H588"); d.text("t-rel", 570, 292, "declares its subscribers", anchor="end")
    d.edge("M572 652H588"); d.text("t-rel", 570, 644, "reads through them", anchor="end")
    d.edge("M740 238V206"); d.text("t-rel", 748, 230, "appends its events")
    d.edge("M740 390V422"); d.text("t-rel", 748, 414, "its events are projected")
    d.edge("M740 558V590"); d.text("t-rel", 748, 582, "every QRY desk reads through it")

    d.box("b-mac", 32, 958, 352, 136, "mcl_om", "[library, ~> 1.4]",
          ["boot/1: joins the realm, dials the",
           "pinned stations, serves /health on",
           "MCL_HEALTH_PORT, and keeps this",
           "service's standing subscriptions."], code=True)
    d.box("b-mac", 404, 958, 352, 136, "macula", "[library, ~> 16.0, wire 1.0]",
          ["QUIC transport, the pubsub the",
           "emitters and the queries use, and",
           "the signed records the mesh DHT",
           "holds."], code=True)
    d.box("b-cmp", 776, 958, 352, 136, "evoq / reckon_evoq / reckon_db", "[libraries, ~> 1.24 / ~> 2.8 / ~> 5.11]",
          ["The board aggregate's event sourcing,",
           "its store subscription, and the store",
           "the projections replay from: one",
           "reckon-db instance, no indexes."], code=True)
    d.box("b-ext", 40, 1126, 1080, 136, "The host environment", "[set on the host; read by config/runtime.exs, mcl_om and the release's env.sh]",
          ["config/runtime.exs reads MCL_DATA_DIR, MCL_IDENTITY_KEY_PATH, MCL_HEALTH_PORT (8491), MCL_HTTP_PORT (4000), MCL_REALM_NAME, MCL_REALM_KEY",
           "and SECRET_KEY_BASE. mcl_om reads MACULA_STATION_SEEDS, MACULA_STATION_NODE_IDS, MCL_SERVICE_NAME and MCL_BOX at boot; the release's env.sh",
           "requires RELEASE_COOKIE. Two volumes: /var/lib/mcl-whiteboard holds the board store, /etc/mcl/secrets holds identity.key, which the realm's",
           "delegation is bound to."], code=True)
    d.edge("M1128 160H1140V926H950V958"); d.text("t-rel", 1120, 222, "events in and out, through evoq", anchor="end")
    d.text("t-desc", 40, 1288, "The departments start before mcl_whiteboard, whose start/2 opens the store and only then runs :mcl_om.boot/1, which declares every")
    d.text("t-desc", 40, 1306, "standing mesh subscription. A start-up ordering test holds that order, and a test fails any event handler that declares no replay policy.")
    d.legend(1342)
    d.write()


if __name__ == "__main__":
    for make in (context, components):
        make()
