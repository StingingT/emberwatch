#!/usr/bin/env python3
"""Content invariants only. This does NOT parse or execute GDScript."""
from __future__ import annotations
import ast
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
checks = 0


def check(condition: bool, label: str) -> None:
    global checks
    assert condition, label
    checks += 1


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def array(name: str) -> list[int]:
    match = re.search(rf"const {name}: Array\[int\] = (\[[^\n]+\])", source("game/army_data.gd"))
    assert match, name
    return ast.literal_eval(match.group(1))


check('path="res://game/army_game.gd"' in source("game/main.tscn"), "production entry point")
check('extends "res://game/game.gd"' in source("game/army_game.gd"), "preserve parent combat")
check(len(array("COSTS")) == len(array("STAR_GATES")) == 5, "five bounded training ranks")
check(all(cost > 0 for cost in array("COSTS")), "positive costs")
check(array("COSTS") == sorted(array("COSTS")), "increasing costs")
check(array("STAR_GATES") == sorted(array("STAR_GATES")) and max(array("STAR_GATES")) <= 18, "attainable star gates")
check('candidate.size() != 6' in source("game/army_progression.gd"), "six-field ledger schema")
check('record.size() != 8' in source("game/army_progression.gd"), "eight-field receipt schema")
check('normal_supplies) * 0.5' in source("game/army_data.gd"), "50 percent reward formula")
check('game.claim_ad_bonus' not in source("ui/army_menu.gd"), "UI cannot directly award ad bonus")
check('army.claim_ad_bonus(id)' in source("game/army_game.gd"), "reward callback integration")
check('ad_provider: Node = null' in source("game/army_game.gd"), "no pretend ad provider")
check('damage / origins.size()' in source("game/building.gd"), "archers share salvo damage")
check('for index: int in range(rank)' in source("common/army_building_visuals.gd"), "tier crew count")
check('super.validate_run_snapshot(normalized)' in source("game/army_game.gd"), "baseline recovery validation retained")
check('"ranks": _battle_ranks.duplicate(true)' in source("game/army_game.gd"), "freeze training in snapshots")
check('Rules.stars(game.profile.data["results"])' in source("ui/army_menu.gd"), "stars derive from best results")
for path in ["game/army_data.gd", "game/army_progression.gd", "game/army_game.gd", "ui/army_menu.gd", "common/army_building_visuals.gd", "tests/check_army_progression.gd"]:
    text = source(path)
    check(not re.search(r"^ +\S", text, re.MULTILINE), f"tab indentation: {path}")
    check("\x00" not in text and text.endswith("\n"), f"UTF-8 source ending: {path}")
print(f"ARMY_STATIC_OK: {checks} content checks; Godot runtime NOT tested")
