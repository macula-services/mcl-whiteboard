"""Generate mcl-whiteboard's three C4 diagrams into assets/.

Run:  python3 architecture/c4_diagrams.py

  c4-context.svg     Level 1: who uses the service, and what it talks to
  c4-container.svg   Level 2: what it runs as
  c4-components.svg  Level 3: what the release is made of

Boxes of the kind b-plan, drawn dashed, are planned by the storming plan
(macula-services/mcl-whiteboard#13) and not built yet. Each names its package.
architecture/README.md lists them, and architecture/test_c4_planned_boxes.py
fails when one of them is drawn as anything else.

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
    "b-plan": ("#F7F8F7", "#8A9791", "#1A221F", "#7D8B85"),  # planned, not built yet
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
.b-plan { stroke-dasharray: 6 4; }
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
          ("b-ext", "External system"), ("b-cmp", "Container or component"),
          ("b-plan", "Planned (the package that builds it)")]
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
        # Each box is a group named for the box, so a test can read a box's kind
        # back from the SVG by its name (architecture/test_c4_planned_boxes.py).
        self.parts.append(f'<g data-box="{escape(name)}">')
        self.parts.append(f'<rect class="{cls}" x="{x}" y="{y}" width="{w}" height="{h}" rx="10"/>')
        tx = x + 16
        if person:
            self.parts.append(f'<circle class="head" cx="{x + 26}" cy="{y + 24}" r="9"/>')
            tx = x + 44
        self.text("t-code" if code else "t-name", tx, y + 28, name)
        self.text("t-type", tx, y + 46, kind)
        for i, line in enumerate(desc):
            self.text("t-desc", x + 16, y + 70 + 16 * i, line)
        self.parts.append("</g>")

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
    d = Diagram("c4-context.svg", "mcl-whiteboard system context", 1400, 1010)
    d.box("b-per", 40, 30, 300, 136, "Facilitator", "[Person]",
          ["Hosts the board: runs this service on", "their own node, opens /boards on port",
           "4000, and runs the phases and the", "timer. Their node is the authority."], person=True)
    d.box("b-per", 380, 30, 300, 136, "Participants", "[Person]",
          ["The business people at the wall. Each", "finds the board over the mesh, gets a",
           "snapshot, then live updates, and", "draws; writes are relayed to the host."],
          person=True)
    d.box("b-per", 720, 30, 300, 136, "Builder", "[Person]",
          ["Turns on the builder view to read", "the wall for the code it asks for:",
           "the Divisions, their lanes and the", "folder each note belongs in."], person=True)
    d.box("b-plan", 1060, 30, 300, 136, "Expert agent", "[Planned: package 5]",
          ["A participant in a row of its own,", "named for what it is. Its notes count",
           "apart, also with business people in", "the room."], person=True)
    d.box("b-sys", 540, 240, 320, 152, "mcl-whiteboard", "[mcl_om mesh service]",
          ["Hosts boards and serves the canvas", "on 4000, publishes every board and",
           "shape fact, and relays a remote", "peer's writes to the board's host.",
           "One release, six OTP apps."])
    d.box("b-mac", 40, 480, 300, 152, "macula-realm", "[Macula infrastructure]",
          ["Endorses the node's identity key and", "grants a provider authorization for",
           "each org procedure it advertises,", "info and get_limits included."])
    d.box("b-mac", 540, 480, 320, 136, "Macula stations, mesh DHT", "[Macula infrastructure]",
          ["The pinned seeds in", "MACULA_STATION_SEEDS carry every fact,",
           "write relay and query (QUIC); the", "DHT keeps a record per org procedure."])
    d.box("b-ext", 1060, 480, 300, 152, "Another host's node", "[External system]",
          ["Another box running this service,", "and the authority for its boards.",
           "The list query is answered by every", "host with boards; the snapshot query",
           "only by that board's host."])
    d.box("b-plan", 40, 720, 300, 136, "The Division's repository", "[Planned: package 4]",
          ["Receives the agreed wall as", "wall.json. Its pipeline runs the",
           "wall-tree check (built in #14), which", "holds the code tree to the wall."])
    d.box("b-plan", 540, 720, 320, 136, "GitHub issues", "[Planned: packages 3 and 6]",
          ["Package 3 files each big-picture hot", "spot as an issue and each opportunity",
           "as a proposal issue. Package 6 files", "a note with no folder as an issue."])
    d.box("b-plan", 1060, 720, 300, 136, "mcl-kanban", "[Planned: package 6]",
          ["Takes a card for each note that has", "no folder yet, with no change to",
           "mcl-kanban. The note links to its", "issue and card until its folder exists."])

    d.edge("M190 166V210H580V240")
    d.text("t-rel", 198, 194, "hosts the board, runs the phases")
    d.edge("M530 166V200H640V240")
    d.text("t-rel", 538, 186, "joins and draws")
    d.edge("M870 166V200H760V240")
    d.text("t-rel", 862, 186, "reads the wall", anchor="end")
    d.edge("M1210 166V210H820V240", later=True)
    d.text("t-rel", 1202, 194, "joins its own row", anchor="end")
    d.edge("M580 392V440H190V480")
    d.text("t-rel", 198, 432, "boot claim, scope mcl-whiteboard")
    d.edge("M700 392V480")
    d.text("t-rel", 708, 414, "board and shape facts,")
    d.text("t-rel", 708, 430, "write relays and queries")
    d.edge("M860 310H1210V480")
    d.text("t-rel", 868, 302, "queries reach every host")
    d.edge("M540 340H420V680H190V720", later=True)
    d.text("t-rel", 300, 672, "writes the agreed wall.json", anchor="middle")
    d.edge("M540 372H460V690H640V720", later=True)
    d.text("t-rel", 648, 712, "files issues")
    d.edge("M860 372H960V680H1210V720", later=True)
    d.text("t-rel", 1085, 672, "hands notes over as cards", anchor="middle")
    d.text("t-desc", 40, 882, "Nothing outside the mesh is called today: the board list and the snapshots come from other hosts over pubsub. The service serves")
    d.text("t-desc", 40, 900, "no procedure of its own, and capabilities/0 is empty. mcl_om adds the open pair every service carries: mcl-whiteboard/info and")
    d.text("t-desc", 40, 918, "mcl-whiteboard/get_limits. Dashed boxes and arrows are planned (macula-services/mcl-whiteboard#13), each named for its package.")
    d.legend(956, boundary=False)
    d.write()


def container():
    d = Diagram("c4-container.svg", "mcl-whiteboard containers", 1400, 1150)
    d.box("b-per", 40, 30, 300, 136, "People at the board", "[Person]",
          ["The facilitator, the participants", "and the builder, each in a browser",
           "on a node that runs this service or", "reaches one over the mesh."], person=True)
    d.bound(380, 20, 1000, 592, "mcl-whiteboard [Software system]")
    d.box("b-cmp", 400, 60, 440, 136, "Browser", "[Container: HTML5 Canvas and the LiveView client]",
          ["Draws the board on a canvas with no npm dependencies, and",
           "talks to the release over the LiveView socket: the board's",
           "shapes and cursors in, each stroke and move out. It keeps",
           "nothing: a reload asks the release for the board again."])
    d.box("b-sys", 400, 260, 440, 152, "mcl-whiteboard release", "[Container: one OTP release, six apps]",
          ["Runs as app on host networking. The web UI is on",
           "MCL_HTTP_PORT (4000), on loopback unless MCL_HTTP_IP says",
           "otherwise; /health is the Unix socket /run/mcl/health.sock.",
           "Event sources each board, projects the read models into",
           "ETS, and reaches the mesh through mcl_om and macula."])
    d.box("b-cmp", 900, 260, 440, 136, "Board store", "[Container: reckon-db, volume /var/lib/mcl-whiteboard]",
          ["Every board's events, one single-node store, no indexes.",
           "The read models are not kept here: the projections",
           "rebuild them into ETS from this store at start.",
           "The volume outlives the container."])
    d.box("b-cmp", 900, 440, 440, 136, "Identity key", "[Container: file, volume /etc/mcl/secrets]",
          ["identity.key, the node's key. The realm's delegation",
           "is bound to it, so a new key needs a new delegation.",
           "The release reads it at boot from",
           "MCL_IDENTITY_KEY_PATH."])

    d.box("b-mac", 40, 660, 300, 152, "macula-realm", "[Macula infrastructure]",
          ["Endorses the node's identity key and", "grants a provider authorization for",
           "each org procedure it advertises,", "info and get_limits included."])
    d.box("b-mac", 540, 660, 320, 136, "Macula stations, mesh DHT", "[Macula infrastructure]",
          ["The pinned seeds in", "MACULA_STATION_SEEDS carry every fact,",
           "write relay and query (QUIC); the", "DHT keeps a record per org procedure."])
    d.box("b-ext", 1060, 660, 300, 136, "Another host's node", "[External system]",
          ["Another box running this service,", "and the authority for its boards.",
           "Reached only through the stations:", "nothing calls it directly."])

    d.box("b-plan", 40, 880, 300, 136, "The Division's repository", "[Planned: package 4]",
          ["Receives the agreed wall as", "wall.json, in #14's schema, with",
           "the layout kept apart. The wall-tree", "check runs in its pipeline."])
    d.box("b-ext", 380, 880, 300, 136, "wall-tree check", "[External system, built in #14]",
          ["The reusable check from", "macula-io/macula-ci-images. It fails",
           "by name when the code tree and", "wall.json disagree."])
    d.box("b-plan", 720, 880, 300, 136, "GitHub issues", "[Planned: packages 3 and 6]",
          ["Package 3 files each big-picture hot", "spot as an issue and each opportunity",
           "as a proposal issue. Package 6 files", "a note with no folder as an issue."])
    d.box("b-plan", 1060, 880, 300, 136, "mcl-kanban", "[Planned: package 6]",
          ["Takes a card for each note that has", "no folder yet, with no change to",
           "mcl-kanban. The note links to its", "issue and card until its folder exists."])

    d.edge("M340 98H400")
    d.text("t-rel", 348, 90, "draw on")
    d.edge("M620 196V260")
    d.text("t-rel", 628, 232, "LiveView socket, port 4000")
    d.edge("M840 328H900")
    d.text("t-rel", 848, 320, "appends")
    d.edge("M820 412V508H900")
    d.text("t-rel", 828, 500, "reads at boot")
    d.edge("M400 392H190V660")
    d.text("t-rel", 198, 384, "boot claim, scope mcl-whiteboard")
    d.edge("M620 412V660")
    d.text("t-rel", 628, 634, "facts, write relays, queries")
    d.edge("M860 728H1060")
    d.text("t-rel", 868, 720, "carry them to every host")
    d.edge("M420 412V840H190V880", later=True)
    d.text("t-rel", 198, 832, "writes the agreed wall.json")
    d.edge("M460 412V850H870V880", later=True)
    d.text("t-rel", 878, 872, "files issues")
    d.edge("M780 412V600H1036V850H1210V880", later=True)
    d.text("t-rel", 1218, 872, "hands notes over as cards")
    d.edge("M380 948H340")
    d.text("t-rel", 360, 940, "reads", anchor="middle")
    d.text("t-desc", 40, 1060, "One container image runs the release; the board store and the identity key are its two volumes. Dashed boxes and arrows are")
    d.text("t-desc", 40, 1078, "planned (macula-services/mcl-whiteboard#13), each named for the package that builds it.")
    d.legend(1110)
    d.write()


# The components the storming plan adds, each with the package that builds it
# (macula-services/mcl-whiteboard#13). Each is drawn dashed until its package
# lands; then it moves into the diagram above as a built box, in that package's
# commit. architecture/README.md lists the same boxes, and the test reads them there.
PLANNED_COMPONENTS = [
    (32, 950, "Authorship and grants", "[Planned: package 2]",
     ["Every write names its author;", "the host grants writing per", "board and per Division."]),
    (312, 950, "Wall model", "[Planned: package 3]",
     ["Note kinds, free marks, lines", "and wires, and the pivotal", "events on the big picture."]),
    (592, 950, "The opening", "[Planned: package 3]",
     ["Phases, timer, rows, stacks,", "One Wording and the weight,", "as the host's acts."]),
    (872, 950, "Division frames, lane form", "[Planned: package 4]",
     ["Frames that open a Division,", "its lanes and its wiring, and", "the loose-note marks."]),
    (32, 1086, "Wall-file writer", "[Planned: package 4]",
     ["Writes the agreed wall as", "wall.json into the Division's", "repository, layout apart."]),
    (312, 1086, "Agents' rows", "[Planned: package 5]",
     ["An expert agent's row, named", "for what it is; its notes", "count apart."]),
    (592, 1086, "Kanban hand-off", "[Planned: package 6]",
     ["A note with no folder becomes", "an issue and a card on", "mcl-kanban."]),
]


def components():
    d = Diagram("c4-components.svg", "mcl-whiteboard components", 1160, 1726)
    d.bound(16, 40, 1128, 1230, "mcl-whiteboard [Container: one OTP release, six apps]")

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

    d.text("t-bound", 32, 934, "Planned by the storming plan (macula-services/mcl-whiteboard#13), not built yet")
    for x, y, name, pkg, desc in PLANNED_COMPONENTS:
        d.box("b-plan", x, y, 260, 120, name, pkg, desc)

    d.edge("M200 190V238"); d.text("t-rel", 208, 230, "boots with")
    d.edge("M200 374V422"); d.text("t-rel", 208, 414, "start/1 starts")
    d.edge("M572 132H588"); d.text("t-rel", 570, 124, "opens first", anchor="end")
    d.edge("M572 300H588"); d.text("t-rel", 570, 292, "declares its subscribers", anchor="end")
    d.edge("M572 652H588"); d.text("t-rel", 570, 644, "reads through them", anchor="end")
    d.edge("M740 238V206"); d.text("t-rel", 748, 230, "appends its events")
    d.edge("M740 390V422"); d.text("t-rel", 748, 414, "its events are projected")
    d.edge("M740 558V590"); d.text("t-rel", 748, 582, "every QRY desk reads through it")

    d.box("b-mac", 32, 1302, 352, 136, "mcl_om", "[library, ~> 1.6]",
          ["boot/1: joins the realm, dials the",
           "pinned stations, serves /health on",
           "MCL_HEALTH_SOCKET, and keeps this",
           "service's standing subscriptions."], code=True)
    d.box("b-mac", 404, 1302, 352, 136, "macula", "[library, ~> 18.0]",
          ["QUIC transport, the pubsub the",
           "emitters and the queries use, and",
           "the signed records the mesh DHT",
           "holds."], code=True)
    d.box("b-cmp", 776, 1302, 352, 136, "evoq / reckon_evoq / reckon_db", "[libraries, ~> 1.24 / ~> 2.8 / ~> 5.11]",
          ["The board aggregate's event sourcing,",
           "its store subscription, and the store",
           "the projections replay from: one",
           "reckon-db instance, no indexes."], code=True)
    d.box("b-ext", 40, 1470, 1080, 136, "The host environment", "[set on the host; read by config/runtime.exs, mcl_om and the release's env.sh]",
          ["config/runtime.exs reads MCL_DATA_DIR, MCL_IDENTITY_KEY_PATH, MCL_HEALTH_SOCKET, MCL_HTTP_PORT (4000), MCL_HTTP_IP, MCL_HTTP_ORIGINS,",
           "MCL_REALM_NAME, MCL_REALM_KEY and SECRET_KEY_BASE. mcl_om reads MACULA_STATION_SEEDS, MACULA_STATION_NODE_IDS, MCL_SERVICE_NAME and",
           "MCL_BOX at boot; the release's env.sh requires RELEASE_COOKIE. Two volumes: /var/lib/mcl-whiteboard holds the board store,",
           "/etc/mcl/secrets holds identity.key, which the realm's delegation is bound to."], code=True)
    d.edge("M1128 160H1140V1270H950V1302"); d.text("t-rel", 1120, 222, "events in and out, through evoq", anchor="end")
    d.text("t-desc", 40, 1632, "The departments start before mcl_whiteboard, whose start/2 opens the store and only then runs :mcl_om.boot/1, which declares every")
    d.text("t-desc", 40, 1650, "standing mesh subscription. A start-up ordering test holds that order, and a test fails any event handler that declares no replay policy.")
    d.legend(1686)
    d.write()


if __name__ == "__main__":
    for make in (context, container, components):
        make()
