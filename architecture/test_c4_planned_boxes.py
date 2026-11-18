"""Every planned box is drawn as planned, and every planned box is listed.

Run:  python3 architecture/test_c4_planned_boxes.py

The list comes from architecture/README.md's "Planned boxes" table, never from
the generator: a list taken from the generator would move with the very change
this test is meant to catch. For each listed box it reads the box's kind back
from the committed SVG (the <g data-box="..."> group the generator writes) and
fails, naming the box, when the kind is not b-plan. It also fails, naming the
box, when an SVG holds a b-plan box the table does not list.

Exit 0 when all of it holds, 1 naming each box that does not.
"""
import os
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
README = os.path.join(ROOT, "architecture", "README.md")
ASSETS = os.path.join(ROOT, "assets")
HEADING = "## Planned boxes"
PLAN_KIND = "b-plan"
SVG = "{http://www.w3.org/2000/svg}"


def listed_boxes():
    """The (box, diagram) rows of the README's planned-boxes table."""
    with open(README) as f:
        lines = f.read().splitlines()
    if HEADING not in lines:
        sys.exit(f"test_c4_planned_boxes: {README} has no '{HEADING}' section")
    rows = []
    for line in lines[lines.index(HEADING) + 1:]:
        if line.startswith("## "):
            break
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if not line.startswith("|") or len(cells) != 3 or cells[0] in ("Box", "") or set(cells[0]) <= {"-"}:
            continue
        rows.append((cells[0], cells[1]))
    if not rows:
        sys.exit(f"test_c4_planned_boxes: the '{HEADING}' table in {README} lists no box")
    return rows


def kinds(diagram):
    """{box name: kind} for every box the diagram draws."""
    tree = ET.parse(os.path.join(ASSETS, diagram))
    out = {}
    for g in tree.iter(f"{SVG}g"):
        name = g.get("data-box")
        rect = g.find(f"{SVG}rect")
        if name is not None and rect is not None:
            out[name] = rect.get("class")
    return out


def main():
    rows = listed_boxes()
    failures = []
    by_diagram = {}
    for box, diagram in rows:
        by_diagram.setdefault(diagram, set()).add(box)
    for diagram in sorted(by_diagram):
        drawn = kinds(diagram)
        for box in sorted(by_diagram[diagram]):
            if box not in drawn:
                failures.append(f"{diagram}: '{box}' is listed as planned but not drawn")
            elif drawn[box] != PLAN_KIND:
                failures.append(f"{diagram}: '{box}' is planned but drawn as {drawn[box]}, not {PLAN_KIND}")
    for diagram in sorted(f for f in os.listdir(ASSETS) if f.startswith("c4-") and f.endswith(".svg")):
        for box, kind in sorted(kinds(diagram).items()):
            if kind == PLAN_KIND and box not in by_diagram.get(diagram, set()):
                failures.append(f"{diagram}: '{box}' is drawn as planned but not listed in {HEADING}")
    for line in failures:
        print(f"test_c4_planned_boxes: FAIL {line}")
    if failures:
        return 1
    print(f"test_c4_planned_boxes: every one of the {len(rows)} planned boxes is drawn as {PLAN_KIND}, and every {PLAN_KIND} box is listed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
