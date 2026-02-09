# Human Review Notes — Phase 2 Changes
**Reviewer:** Human (project owner)
**Date:** 2026-02-08
**Scope:** All P2 and P3 changes from Dev agents

---

## Review Note 1: No redundant Safe_* casts in @type_safe methods
**Files:** `Graph__Repository.py`, `Node__Service.py`
**Action:** Fixed — removed 5 redundant `Safe_Str__*()` casts where `@type_safe` handles coercion
**Principle:** Never have a line of code doing a cast that is not needed. If `@type_safe` is present, it handles the return type coercion automatically.
**Status:** Applied. Added to Dev ROLE.md.

## Review Note 2: No docstrings
**Files:** `Node__Service.py` (label_from_type_and_index, parse_label_to_type)
**Action:** Fixed — removed docstrings from both methods
**Principle:** No docstrings. Use inline comments at the right margin instead. The code should be self-documenting through clear naming.
**Status:** Applied. Added to Dev ROLE.md.

## Review Note 3: No str() casting when @type_safe handles it
**Files:** `Node__Service.py` (label_from_type_and_index)
**Action:** Fixed — removed `str(node_type)` cast, @type_safe handles parameter coercion
**Principle:** Same as Review Note 1 — no redundant casting.
**Status:** Applied.

## Review Note 4: Safe_Str__Node_Label casting should be done via @type_safe
**Files:** `Node__Service.py` (label_from_type_and_index)
**Action:** Fixed — added `@type_safe` decorator to method, removed explicit `Safe_Str__Node_Label()` cast, return plain f-string
**Principle:** Add @type_safe and let it handle the return type cast.
**Status:** Applied.

## Review Note 5: Block comments should be inline
**Files:** `Node__Service.py` (parse_label_to_type sort comment), `MGraph__Issues__Domain.py` (multiple)
**Action:** Fixed in Node__Service.py — moved to inline. MGraph files flagged in Bug-8 for rework.
**Principle:** All comments should be inline (at the right margin), not on separate lines above the code.
**Status:** Applied to Node__Service.py. Rule added to Dev ROLE.md. Pre-existing block comments in Link__Service.py, Comments__Service.py, Node__Service.py (create_node section) need a separate task to convert.
**Needs issue:** Yes — task for Dev to convert all pre-existing block comments to inline across the codebase.

## Review Note 6: String-quoted forward references for non-self classes
**Files:** `Node__Service.py` (get_node_graph -> 'Schema__Graph__Response')
**Action:** Fixed — changed to direct class reference `-> Schema__Graph__Response`
**Principle:** Type_Safe only supports string-quoted class names for the current class itself. For any other class, use the direct class reference.
**Status:** Applied. Filed as Bug-7. Added to Dev ROLE.md.

## Review Note 7: Redundant Safe_Str__Node_Label(str(...)) cast
**Files:** `Node__Service.py` (resolve_link_target)
**Action:** Fixed — simplified to `link.target_label`
**Principle:** Same as Review Note 1.
**Status:** Applied.

## Review Note 8: Schema classes must be in separate files
**Files:** `Schema__Node__Type__Update.py` (had 2 classes), `Schema__Link__Type__Update.py` (had 2 classes), `Schema__MGraph__Issues.py` (has 3 classes)
**Action:** Split Update/Response files into 4 separate files. MGraph schema file flagged in Bug-8.
**Principle:** One class per file. File name matches class name.
**Status:** Applied for Update/Response schemas. MGraph schemas pending (Bug-8).
**Needs issue:** Already in Bug-8.

## Review Note 9: No debug/scratch files
**Files:** `tests/mgraph/_debug_node_id.py`
**Action:** Deleted
**Principle:** Never create throwaway debug files. Write proper tests in the correct test file. No print() in tests.
**Status:** Applied. Added to Dev ROLE.md (rule 8).

## Review Note 10: No print() statements in tests
**Files:** `tests/mgraph/_debug_node_id.py`
**Action:** Deleted (file removed entirely)
**Principle:** Tests use assertions only, never print(). If behaviour is already validated in existing tests, do not re-test it.
**Status:** Applied. Added to Dev ROLE.md (rule 8).

## Review Note 11: No conftest.py
**Files:** `tests/conftest.py`
**Action:** Deleted
**Principle:** Never create conftest.py files. They almost always represent a hack (sys.path manipulation). If you hit an import issue, stop and escalate as a Blocker.
**Status:** Applied. Added to Dev ROLE.md (rule 10).

## Review Note 12: Redundant __init__ in Type_Safe classes
**Files:** `Schema__MGraph__Issues__Data` (Schema__MGraph__Issues.py), `MGraph__Issues__Domain` (MGraph__Issues__Domain.py — already fixed by reviewer)
**Action:** MGraph__Issues__Domain fixed by reviewer. Schema__MGraph__Issues__Data flagged in Bug-8.
**Principle:** Type_Safe handles field initialization automatically. Never write an __init__ that checks for None and assigns defaults.
**Status:** Principle added to Dev ROLE.md. MGraph schema pending (Bug-8).

## Review Note 13: Raw str in Dict types instead of Safe_* types
**Files:** `Schema__MGraph__Issues__Data` (Dict[str, ...]), `MGraph__Issues__Domain` (Dict[str, str], Dict[str, List[str]])
**Action:** Flagged in Bug-8
**Principle:** Never use raw Python types where Safe_* primitives exist. Dict keys should be Node_Id, Edge_Id, Safe_Str__Node_Label etc.
**Status:** Pending (Bug-8).

## Review Note 14: Should use Type_Safe collection subclasses
**Files:** `MGraph__Issues__Domain` indexes
**Action:** Flagged in Bug-8
**Principle:** When a Dict/List/Set type has semantic meaning, define a named Type_Safe__Dict/List/Set subclass (e.g. Dict__Nodes__By_Label). Read: `modules/Issues-FS__Docs/docs/development/llm-briefs/type-safety/v3.63.3__for_llms__type_safe__collections__subclassing_guide.md`
**Status:** Principle added to Dev ROLE.md. Pending (Bug-8).

## Review Note 15: str() casting cascade from raw Dict keys
**Files:** `MGraph__Issues__Domain.py` (add_edge method — str(edge.edge_id), str(edge.source_id), str(edge.target_id))
**Action:** Flagged in Bug-8
**Principle:** When Schema uses raw str as Dict keys, all Domain code must convert typed values to str — creating a cascade of unnecessary casting. Fix the Schema types and the Domain code simplifies automatically.
**Status:** Pending (Bug-8).

## Review Note 16: Additional redundant casts found during full scan
**Files:** `Graph__Repository.py` (nodes_list_all), `Node__Service.py` (type_to_label_prefix)
**Action:** Fixed — removed 5 redundant `Safe_Str__*()` casts in `nodes_list_all()` (Safe_Str__Node_Label, Safe_Str__File__Path x3, Safe_Str__Node_Type); `Schema__Node__Info` is a Type_Safe class so its constructor handles coercion. Removed docstring from `type_to_label_prefix()`.
**Principle:** Same as Review Notes 1, 2, 3. Type_Safe constructors coerce automatically — no explicit casts needed when passing values to Type_Safe field assignments.
**Status:** Applied. Tests: 414 passed.

## Review Note 17: MGraph test failures — Node_Id()/Edge_Id() return empty, Dict→Type_Safe__Dict
**Files:** `test_MGraph__Issues__Domain.py`
**Root Cause 1:** `Node_Id()` and `Edge_Id()` called without a value return empty string `''` — unlike `Obj_Id()` which auto-generates a random hex ID. Every node/edge was stored under the same key `''`, causing overwrites and count mismatches.
**Root Cause 2:** `Dict[str, str]` annotations in Type_Safe classes are converted to `Type_Safe__Dict` at runtime. Tests asserting `type(_.index_by_label) is dict` failed because the actual type is `Type_Safe__Dict`.
**Fix:** Changed `make_node`/`make_edge` helpers to use `Node_Id(Obj_Id())` and `Edge_Id(Obj_Id())` for unique IDs. Changed `test__init__` to assert `Type_Safe__Dict` instead of `dict`.
**Status:** Applied. All 7 failures fixed.

## Review Note 18: Schema and test files split — one class per file
**Files (old, deleted):** `Schema__MGraph__Issues.py` (3 classes), `test_Schema__MGraph__Issues.py` (3 test classes)
**Files (new):**
- `Schema__MGraph__Issue__Node.py`, `Schema__MGraph__Issue__Edge.py`, `Schema__MGraph__Issues__Data.py`
- `test_Schema__MGraph__Issue__Node.py`, `test_Schema__MGraph__Issue__Edge.py`, `test_Schema__MGraph__Issues__Data.py`
**Action:** Split into 1-class-per-file. Updated all import references in `MGraph__Issues__Domain.py`, `test_MGraph__Issues__Domain.py`.
**Status:** Applied. Tests: 457 passed (was 449 passed + 8 failed → now 457 passed + 0 failed).

## Review Note 19: No Raw Primitives Policy — architecture guidance + Rule 13
**Action:** Created `v0.4.0__for_llms__no_raw_primitives_policy.md` (comprehensive policy document with banned types, replacements, anti-patterns, audit checklist). Added Rule 13 to Dev ROLE.md.
**Status:** Applied.

## Review Note 20: Raw Primitives Audit — ~176 violations across 23+ files
**Scope:** Full audit of `issues_fs/` production code
**Findings:**
- ~77 `str` violations (fields, params, returns)
- ~52 `bool` violations (fields — **note: `bool` is permitted per policy**)
- ~19 `int` violations (fields, params, returns)
- ~9 `dict` violations (params, returns)
- ~8 `Dict[str, ...]` violations (fields — raw str keys)
- ~4 `list` violations (params)
- 1 `set` violation, 1 `List[tuple]`, 1 `List[dict]`
**Top priority files:** `Path__Handler__Graph_Node.py` (17), `Git__Status__Service.py` (28), `Root__Selection__Service.py` (14), `MGraph__Issues__Domain.py` (7 — Bug-8), `Node__Service.py` (10)
**Status:** Audit complete. Violations documented. Excluding `bool` (permitted), approximately 124 violations to fix across the codebase. These should be addressed as separate Bug/Task items.

---

## Summary for Librarian

### Principles captured in Dev ROLE.md (already done):
1. No redundant Safe_* casts in @type_safe methods
2. One class per file
3. No docstrings — use inline comments
4. No string-quoted forward references for non-self classes
5. Block comments must be inline
6. No debug/scratch files, no print() in tests
7. No redundant tests for library primitives
8. No conftest.py — escalate import issues
9. Never write redundant __init__ in Type_Safe classes
10. Use Type_Safe collection subclasses for reused/semantic types
11. No `__init__.py` files in tests (breaks PyCharm)
12. No imports in `__init__.py` files (class file is source of truth)
13. No raw primitives in type annotations (str, int, float, list, dict, set, tuple banned — use Safe_* / Type_Safe collections)

### Issues to create:
1. **Task**: Convert all pre-existing block comments to inline across codebase (Link__Service.py, Comments__Service.py, Node__Service.py create_node section)
2. **Bug-8** (already filed): B18 MGraph implementation rework
3. **Task**: Fix ~124 raw primitive violations across 23+ files (see Review Note 20 for full audit)

### Guidance docs:
1. Dev ROLE.md — updated with all 13 rules
2. `v0.4.0__for_llms__no_raw_primitives_policy.md` — new comprehensive policy doc
3. QA ROLE.md — add these patterns to the review checklist (block comments, redundant casts, __init__ anti-pattern, collection subclassing, raw primitives)
