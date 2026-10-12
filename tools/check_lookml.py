#!/usr/bin/env python3
"""Static checker for this LookML project.

Parses every .lkml file with the `lkml` package and checks:
  1. every ${view.field} / ${field} reference resolves to a real field
  2. every explore, and every join inside it, points to a real view
  3. field names are unique within a single view block
  4. every view (after merging any +view refinements) has a primary key

Exits non-zero with readable errors if anything fails.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import lkml

PROJECT_ROOT = Path(__file__).resolve().parent.parent
FIELD_REF_RE = re.compile(r"\$\{([A-Za-z0-9_.]+)\}")
TIMEFRAMES_DEFAULT = ["raw", "date", "week", "month", "quarter", "year"]
FIELD_KEYS = ("dimensions", "measures", "filters", "parameters")


class CheckError(Exception):
    pass


def load_lkml_files(root: Path, patterns):
    files = []
    for pattern in patterns:
        files.extend(sorted(root.glob(pattern)))
    parsed = {}
    errors = []
    for path in files:
        try:
            with open(path, "r", encoding="utf-8") as f:
                parsed[path] = lkml.load(f)
        except Exception as exc:  # noqa: BLE001 - want a readable message, not a traceback
            errors.append(f"{rel(path, root)}: failed to parse ({exc})")
    return parsed, errors


def rel(path: Path, root: Path) -> str:
    return str(path.relative_to(root)).replace("\\", "/")


def field_names_for_view(view: dict) -> set[str]:
    """All field names a view block directly declares, including the
    sub-fields a dimension_group expands into (e.g. created -> created_date,
    created_month, ...)."""
    names: set[str] = set()
    for key in FIELD_KEYS:
        for field in view.get(key, []) or []:
            if "name" in field:
                names.add(field["name"])
    for dg in view.get("dimension_groups", []) or []:
        base = dg.get("name")
        if not base:
            continue
        if dg.get("type") == "duration":
            # Per Looker's own reference example (param-field-dimension-group):
            # a group named "since_event" with intervals: [day, hour] generates
            # fields named days_since_event, hours_since_event -- the pluralized
            # interval is PREFIXED onto the group name, not suffixed.
            for interval in dg.get("intervals", []) or []:
                names.add(f"{interval}s_{base}")
        else:
            timeframes = dg.get("timeframes") or TIMEFRAMES_DEFAULT
            for tf in timeframes:
                names.add(f"{base}_{tf}")
    return names


def check_duplicate_field_names(view: dict, source: str, errors: list[str]) -> None:
    seen: dict[str, str] = {}
    for key in FIELD_KEYS + ("dimension_groups",):
        for field in view.get(key, []) or []:
            name = field.get("name")
            if not name:
                continue
            if name in seen:
                errors.append(
                    f"{source}: view '{view.get('name')}' declares field "
                    f"'{name}' more than once ({seen[name]} and {key})"
                )
            else:
                seen[name] = key


def build_view_index(parsed, root: Path) -> tuple[dict[str, set[str]], dict[str, bool], list[str]]:
    """Merge base views with any +view refinements.

    Returns (field_names_by_view, has_primary_key_by_view, errors).
    """
    field_names: dict[str, set[str]] = {}
    has_pk: dict[str, bool] = {}
    errors: list[str] = []

    for path, doc in parsed.items():
        if doc is None:
            continue
        for view in doc.get("views", []) or []:
            raw_name = view.get("name", "")
            is_refinement = raw_name.startswith("+")
            base_name = raw_name[1:] if is_refinement else raw_name

            check_duplicate_field_names(view, rel(path, root), errors)

            field_names.setdefault(base_name, set())
            field_names[base_name] |= field_names_for_view(view)

            has_pk.setdefault(base_name, False)
            for dim in view.get("dimensions", []) or []:
                if str(dim.get("primary_key", "")).lower() == "yes":
                    has_pk[base_name] = True

    return field_names, has_pk, errors


def check_field_refs(parsed, field_names: dict[str, set[str]], root: Path) -> list[str]:
    errors: list[str] = []
    known_views = set(field_names.keys())

    def check_sql_blob(blob: str, current_view: str | None, source: str) -> None:
        for match in FIELD_REF_RE.finditer(blob):
            ref = match.group(1)
            if ref in ("TABLE", "SQL_TABLE_NAME"):
                continue
            if "." in ref:
                view_part, field_part = ref.split(".", 1)
                if field_part == "SQL_TABLE_NAME":
                    if view_part not in known_views:
                        errors.append(
                            f"{source}: references unknown view "
                            f"'{view_part}' via ${{{ref}}}"
                        )
                    continue
                if view_part not in known_views:
                    errors.append(
                        f"{source}: references unknown view '{view_part}' "
                        f"via ${{{ref}}}"
                    )
                elif field_part not in field_names[view_part]:
                    errors.append(
                        f"{source}: references unknown field '{field_part}' "
                        f"on view '{view_part}' via ${{{ref}}}"
                    )
            else:
                if current_view is None:
                    # Reference with no view context (e.g. inside a join's
                    # sql_on, which should always be dotted) — skip; the
                    # dotted-reference branch above covers join validation.
                    continue
                if ref not in field_names.get(current_view, set()):
                    errors.append(
                        f"{source}: references unknown field '{ref}' on "
                        f"its own view '{current_view}' via ${{{ref}}}"
                    )

    def walk_strings(node, current_view, source):
        if isinstance(node, str):
            check_sql_blob(node, current_view, source)
        elif isinstance(node, dict):
            for v in node.values():
                walk_strings(v, current_view, source)
        elif isinstance(node, list):
            for item in node:
                walk_strings(item, current_view, source)

    for path, doc in parsed.items():
        if doc is None:
            continue
        source = rel(path, root)
        for view in doc.get("views", []) or []:
            raw_name = view.get("name", "")
            base_name = raw_name[1:] if raw_name.startswith("+") else raw_name
            walk_strings(view, base_name, f"{source} (view '{raw_name}')")
        for explore in doc.get("explores", []) or []:
            explore_name = explore.get("name", "<unnamed>")
            # No single "current view" inside an explore/join block — every
            # ${...} reference here is expected to be dotted (view.field).
            walk_strings(explore, None, f"{source} (explore '{explore_name}')")

    return errors


def check_explores_and_joins(parsed, known_views: set[str], root: Path) -> list[str]:
    errors: list[str] = []
    for path, doc in parsed.items():
        if doc is None:
            continue
        source = rel(path, root)
        for explore in doc.get("explores", []) or []:
            explore_name = explore.get("name", "<unnamed>")
            base_view = explore.get("from") or explore.get("view_name") or explore_name
            if base_view not in known_views:
                errors.append(
                    f"{source}: explore '{explore_name}' has no matching "
                    f"view '{base_view}'"
                )
            for join in explore.get("joins", []) or []:
                join_view = join.get("from") or join.get("view_name") or join.get("name")
                if join_view not in known_views:
                    errors.append(
                        f"{source}: explore '{explore_name}' joins unknown "
                        f"view '{join_view}'"
                    )
    return errors


def main() -> int:
    arg_parser = argparse.ArgumentParser(description=__doc__)
    arg_parser.add_argument(
        "--root",
        type=Path,
        default=PROJECT_ROOT,
        help="Project root to check (default: this script's parent project)",
    )
    args = arg_parser.parse_args()
    root = args.root.resolve()

    parsed, parse_errors = load_lkml_files(
        root, ["models/*.model.lkml", "views/*.view.lkml"]
    )
    errors = list(parse_errors)

    field_names, has_pk, merge_errors = build_view_index(parsed, root)
    errors.extend(merge_errors)

    errors.extend(check_field_refs(parsed, field_names, root))
    errors.extend(check_explores_and_joins(parsed, set(field_names.keys()), root))

    for view_name, found in sorted(has_pk.items()):
        if not found:
            errors.append(f"view '{view_name}': no dimension with primary_key: yes")

    if errors:
        print(f"check_lookml.py: {len(errors)} error(s) found:\n", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    view_count = len(field_names)
    explore_count = sum(
        len(doc.get("explores", []) or []) for doc in parsed.values() if doc
    )
    print(
        f"check_lookml.py: OK — {view_count} view(s), {explore_count} explore(s), "
        f"no errors."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
