"""Windfall plant drawings: the redraw of 16 November 2026.

William, 16 November 2026: "I looked at the strawberry leaf drawing and it's
wrong ... Is there a way we can do a stronger pass of all drawings?"

Every plant now has a written description, Design/Plants/descriptions/<kind>.json,
and its drawings were put right against it, group by group. Each group's
changes are in one file in this folder (fruit.py, roots.py and so on), so
that nine groups could be worked on side by side without two people
changing the same lines.

A group's file may hold any of these. Each is optional.

  LEAFX = {kind: dict(...)}     the close-up leaf's settings, replacing the
                                whole entry for that kind (as in leaves_flowers.py)
  BLOOMX = {kind: dict(...)}    the same for the close-up flower; None for no flower
  KIND = {kind: dict(...)}      changes to the kind's settings in plants_all.py,
                                which the life-stage drawings are made from
  STAGE = {kind: {stage: fn}}   a whole drawing of one stage, drawn by hand:
                                fn() returns an Art. Also for the ten in plants.py
  LEAF_DRAW, BLOOM_DRAW         new close-up shapes: {name: fn(a, sp)}
  LF = {name: fn(a, x, y, ang, L, fill)}            new leaf shapes for life stages
  FL = {name: fn(a, x, y, r, col, cen, ang)}        new flower shapes for life stages
  COLOURS = {name: (light, dark)}                   new colours

New names in LEAF_DRAW, BLOOM_DRAW, LF, FL and COLOURS start with the
group's name (fruit_pea, bulbs_cup) so two groups cannot choose the same one.

This file reads every group's file and gathers them into the tables below,
which plants_all.py and leaves_flowers.py read.

While the groups were being worked on, REDRAW_ONLY=<group> made the scripts
read that one group's file and no other, so one group's half-finished work
could not stop another's drawings being made. Left unset, every group is read.
"""
import importlib, os, pkgutil

LEAFX, BLOOMX, KIND, STAGE = {}, {}, {}, {}
LEAF_DRAW, BLOOM_DRAW, LF, FL, COLOURS = {}, {}, {}, {}, {}
GROUPS = []

_here = os.path.dirname(__file__)
_only = os.environ.get("REDRAW_ONLY")
for _m in sorted(pkgutil.iter_modules([_here]), key=lambda m: m.name):
    if _m.name.startswith("_") or (_only and _m.name not in _only.split(",")):
        continue
    mod = importlib.import_module(f"redraw.{_m.name}")
    GROUPS.append(_m.name)
    for name, table in (("LEAFX", LEAFX), ("BLOOMX", BLOOMX), ("KIND", KIND), ("LEAF_DRAW", LEAF_DRAW),
                        ("BLOOM_DRAW", BLOOM_DRAW), ("LF", LF), ("FL", FL), ("COLOURS", COLOURS)):
        for k, v in getattr(mod, name, {}).items():
            if name == "KIND":
                table.setdefault(k, {}).update(v)
                continue
            if k in table and table[k] != v:
                raise SystemExit(f"redraw: {name}[{k!r}] is set by two groups ({mod.__name__} and another)")
            table[k] = v
    for k, v in getattr(mod, "STAGE", {}).items():
        STAGE.setdefault(k, {}).update(v)
