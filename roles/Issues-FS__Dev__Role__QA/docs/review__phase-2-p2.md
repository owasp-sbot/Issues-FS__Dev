# QA Review: Phase 2 P2 (B15, B16, B17, B22, Bug-1/2/3 fixes)

**Reviewer:** QA Agent
**Date:** 2026-02-08
**Branch:** dev
**Tests:** 414 pass, 0 fail
**Scope:** Bug-1/2/3 fixes, Task-6 (B15), Task-7 (B16), Task-8 (B17), Task-13 (B22)

---

## Verdict

**REJECT -- 3 new bugs filed (Bug-4, Bug-5, Bug-6), 2 CRITICAL, 1 MAJOR.**

The bug fixes (Bug-1/2/3) are correctly applied. The B15/B16 update methods and B17 root scoping are structurally sound. However, the B22 hyphenated label implementation introduces a **label format inconsistency** across three different code paths, and the `type_to_label_prefix` method violates the project's type safety conventions. Additionally, `parse_label_to_type` has a false-positive matching vulnerability that can silently resolve labels to the wrong type when a shorter type name is a prefix of a longer one.

---

## Summary

### What was done

| Area | Status | Assessment |
|------|--------|------------|
| Bug-1 fix (`scan_child_folders` type regression) | Reverted to `List[Safe_Str__File__Path]` | PASS |
| Bug-2 fix (`extract_node_type_from_file` return type) | Changed to `Safe_Str__Node_Type` | PASS |
| Bug-3 fix (`get_issue_file_path` return type) | Changed to `Safe_Str__File__Path` | PASS |
| B15: `update_node_type()` on `Type__Service` | Implemented with `Schema__Node__Type__Update` | PASS with findings |
| B16: `update_link_type()` on `Type__Service` | Implemented with `Schema__Link__Type__Update` | PASS with findings |
| B17: Root scoping in `list_nodes` / `list_nodes_for_type` | Implemented via `root_selection_service` | PASS with findings |
| B22: Hyphenated label support | Implemented `label_from_type_and_index`, `type_to_label_prefix`, `parse_label_to_type` | **FAIL -- 3 bugs** |

### What was missed

1. **CRITICAL (Bug-4):** `type_to_label_prefix` uses raw `str` parameter and return type -- no `@type_safe`, no `Safe_*` types
2. **CRITICAL (Bug-5):** Three divergent label generation algorithms exist in the codebase; B22 only updated `Node__Service` but left `Issue__Children__Service.generate_child_label` and `Path__Handler__Graph_Node.label_from_type_and_index` producing incompatible label formats for the same type
3. **MAJOR (Bug-6):** `parse_label_to_type` false-positive: when type `user` is known but `user-story` is not, label `User-Story-5` silently resolves to type `user` instead of returning the fallback result

---

## Per-Task Review

### Bug-1/2/3 Fixes

**Files changed:** `Graph__Repository.py`, `Issue__Children__Service.py`
**Assessment:** PASS.

All three bug fixes are correctly applied:
- Bug-1: `scan_child_folders` return type restored to `List[Safe_Str__File__Path]`
- Bug-2: `extract_node_type_from_file` now returns `Safe_Str__Node_Type` with proper wrapping
- Bug-3: `get_issue_file_path` now returns `Safe_Str__File__Path` with proper wrapping

The Bug-1/2/3 issue status is changed to `resolved`. No regressions found.

### Task-6 (B15): `update_node_type()`

**Files changed:** `Type__Service.py`
**New files:** `Schema__Node__Type__Update.py`, `test_Type__Service__B15__Update_Node_Type.py`
**Tests:** 7 new tests

**Implementation:**
- `Schema__Node__Type__Update` is a pure data container with all `Safe_*` types and `None` defaults
- `Schema__Node__Type__Update__Response` carries success, node_type, message
- `update_node_type()` does find-by-name, applies non-None/non-empty updates, persists
- Uses `@type_safe` decorator, `Safe_Str__Node_Type` for `name` parameter

**Assessment:** PASS with findings.
- Partial update logic correctly preserves un-updated fields (tested in `test__update_node_type__partial_update`)
- Response pattern follows project conventions
- See Finding MAJOR-3 (`Schema__Node__Type__Update__Response.node_type` typed as `object`)
- See Finding MINOR-1 (cannot clear a field to empty string)

### Task-7 (B16): `update_link_type()`

**Files changed:** `Type__Service.py`
**New files:** `Schema__Link__Type__Update.py`, `test_Type__Service__B16__Update_Link_Type.py`
**Tests:** 7 new tests

**Implementation:** Follows identical pattern to B15, adapted for link types.

**Assessment:** PASS with findings.
- See Finding MAJOR-3 (`Schema__Link__Type__Update__Response.link_type` typed as `object`)

### Task-8 (B17): Root Scoping

**Files changed:** `Node__Service.py`
**New files:** `test_Node__Service__B17__Root_Scoping.py`
**Tests:** 13 new tests

**Implementation:**
- `get_current_root_path()` extracts root from `root_selection_service`
- `list_nodes()` passes current root to `list_nodes_for_type()`
- `list_nodes_for_type()` accepts `root_path` parameter, delegates to `nodes_list_all(root_path=...)`
- `Mock__Root__Selection__Service` in tests correctly simulates root selection

**Assessment:** PASS with findings.
- Root scoping logic is correct and well-tested (no-root, empty-root, with-root, type+root, deep nesting)
- See Finding MINOR-3 (bare truthy checks in new B17 code)
- See Finding NOTE-1 (`root_selection_service` typed as `object`)

### Task-13 (B22): Hyphenated Label Support

**Files changed:** `Node__Service.py`, `Safe_Str__Graph_Types.py`
**New files:** `test_Node__Service__B22__Hyphenated_Labels.py`
**Tests:** 16 new tests

**Implementation:**
- `label_from_type_and_index()` rewritten to use `type_to_label_prefix()` for hyphen-aware formatting
- `type_to_label_prefix()` converts `user-story` to `User-Story`
- `parse_label_to_type()` matches labels against known types (longest first), with fallback
- `resolve_link_target()` rewritten to use `parse_label_to_type()` instead of `split('-')`
- `Safe_Str__Node_Label` regex updated to `^[A-Z][a-zA-Z]*(-[A-Z][a-zA-Z]*)*-\d{1,5}$`

**Assessment:** FAIL -- 3 bugs found.

**Bug-4 (CRITICAL):** `type_to_label_prefix` at `Node__Service.py` line 305 has signature `def type_to_label_prefix(self, node_type: str) -> str:`. Both parameter and return type are raw `str`. The method has no `@type_safe` decorator. This is a new method introduced in P2 that violates the project's core type safety convention. The parameter should be `Safe_Str__Node_Type` and the return should be a `Safe_Str` variant (or at minimum the method should be private helper with `@type_safe`).

**Bug-5 (CRITICAL):** Label format divergence. B22 updated `Node__Service.label_from_type_and_index` to produce `Git-Repo-1` for type `git-repo`, but:
- `Issue__Children__Service.generate_child_label` (line 255) produces `GitRepo-1` (joins without hyphens)
- `Issue__Children__Service.get_existing_indices` (line 271) searches for `GitRepo-` prefix (joins without hyphens)
- `Path__Handler__Graph_Node.label_from_type_and_index` (line 184) produces `Git-repo-1` (only capitalizes first word)

Three different label formats for the same type `git-repo`:
| Code path | Output for `git-repo` type, index 1 |
|-----------|--------------------------------------|
| `Node__Service.label_from_type_and_index` (B22) | `Git-Repo-1` |
| `Issue__Children__Service.generate_child_label` | `GitRepo-1` |
| `Path__Handler__Graph_Node.label_from_type_and_index` | `Git-repo-1` |

This means child issues created through `Issue__Children__Service` will have labels that are unparseable by `parse_label_to_type` for hyphenated types (which expects the `Git-Repo-` prefix, not `GitRepo-`). The `Path__Handler__Graph_Node` version also produces a different format. This is a data consistency bug that will cause lookup failures.

**Bug-6 (MAJOR):** `parse_label_to_type` false-positive matching. The method iterates known types longest-first and checks `label_str.startswith(f"{prefix}-")`. If type `user` is registered but `user-story` is NOT, then label `User-Story-5`:
- `type_to_label_prefix('user')` = `User`
- `"User-Story-5".startswith("User-")` = True
- Returns `Safe_Str__Node_Type('user')` -- **WRONG**, the label is for a `user-story` type

The longest-first sort only protects against false positives when ALL relevant types are registered. There is no validation that the remaining label text after the prefix is purely numeric. The fix should verify that the text between the prefix and the trailing digit is empty (or that the next character after the prefix-dash is a digit).

---

## Findings by Severity

### CRITICAL

**CRITICAL-1 (Bug-4):** `type_to_label_prefix` uses raw `str` types, no `@type_safe`
- **File:** `issues_fs/issues/graph_services/Node__Service.py` line 305
- **Signature:** `def type_to_label_prefix(self, node_type: str) -> str:`
- **Convention violation:** New method introduced in P2 with raw Python types. NEVER use raw `str` where `Safe_*` types exist.

**CRITICAL-2 (Bug-5):** Three divergent label generation algorithms
- **Files:** `Node__Service.py` line 302, `Issue__Children__Service.py` line 255, `Path__Handler__Graph_Node.py` line 184
- **Impact:** Labels generated through different code paths will be incompatible. `parse_label_to_type` cannot parse labels generated by `Issue__Children__Service` for multi-word types.

### MAJOR

**MAJOR-1 (Bug-6):** `parse_label_to_type` false-positive for prefix-overlapping types
- **File:** `issues_fs/issues/graph_services/Node__Service.py` lines 326-331
- **Impact:** Silent wrong-type resolution when a shorter type name is a prefix match. Affects `resolve_link_target` and any caller relying on `parse_label_to_type`.

**MAJOR-2:** Missing `@type_safe` on `label_from_type_and_index` in `Node__Service`
- **File:** `issues_fs/issues/graph_services/Node__Service.py` line 290
- **Issue:** The rewritten `label_from_type_and_index` does not have `@type_safe` decorator, unlike its callers and sibling methods. The `node_index` parameter is `int` instead of `Safe_UInt`.

**MAJOR-3:** `Schema__*__Update__Response` uses `object` type for result field
- **Files:** `Schema__Node__Type__Update.py` line 24, `Schema__Link__Type__Update.py` line 21
- **Issue:** `node_type : object = None` and `link_type : object = None` bypass type safety. These should be typed as `Schema__Node__Type` and `Schema__Link__Type` respectively, or use a forward reference string.

### MINOR

**MINOR-1:** Update methods cannot clear fields to empty string
- **File:** `Type__Service.py` lines 103-114, 184-191
- **Issue:** The `is not None and str(...) != ''` guard means there is no way to intentionally clear a field (e.g., set description to empty). An explicit sentinel value or a separate "fields to clear" list would be needed.

**MINOR-2:** Import alignment not fixed in `Node__Service.py` for `Safe_Str__Graph_Types`
- **File:** `issues_fs/issues/graph_services/Node__Service.py` line 19
- **Issue:** The import `from issues_fs.schemas.graph.Safe_Str__Graph_Types` has `import` at correct column, but `Issue__Children__Service.py` lines 20-24 still have misaligned imports (not fixed in this changeset despite the file being modified for Bug-1).

**MINOR-3:** Bare truthy checks in new B17/B22 code
- **File:** `Node__Service.py`
- **Lines:** 67 (`if node_type:`), 91 (`if node:`), 105 (`if root_str:`), 415 (`if node.links:`), 420 (`if target_node:`), 438 (`if not link.target_label:`)
- **Convention:** Should use `is not None` or `is True` / `is False` per project standards.

### NOTE

**NOTE-1:** `root_selection_service : object = None` in `Node__Service` (pre-existing from B14 review, still unresolved)

**NOTE-2:** `Safe_Str__Node_Label` regex permits `GitRepo-1` format
- The updated regex `^[A-Z][a-zA-Z]*(-[A-Z][a-zA-Z]*)*-\d{1,5}$` allows BOTH `Git-Repo-1` AND `GitRepo-1`. This means the regex does not enforce a single canonical label format. Labels from `Issue__Children__Service` (PascalCase) and `Node__Service` (hyphenated) both pass validation, masking the format divergence (Bug-5).

**NOTE-3:** No test coverage for `parse_label_to_type` false-positive scenario
- No test exists for the case where label `User-Story-5` is parsed when `user` is registered but `user-story` is not. This is the Bug-6 scenario.

**NOTE-4:** B22 task description says "Rename `_traverse_graph` to `traverse_graph`" but dev_notes say "already renamed in prior B10-B13 work." This is consistent with the prior review but should have been noted as N/A in the task, not marked "done" as if it was performed in this changeset.

---

## Type Safety Audit

### New raw types introduced in P2

| File | Line | Issue | Severity |
|------|------|-------|----------|
| `Node__Service.py` | 305 | `type_to_label_prefix(self, node_type: str) -> str` | CRITICAL (Bug-4) |
| `Node__Service.py` | 292 | `node_index : int` (should be `Safe_UInt`) | MAJOR |

### Raw types fixed in P2 (Bug-1/2/3 fixes)

| File | Line | Before | After | Status |
|------|------|--------|-------|--------|
| `Issue__Children__Service.py` | 216 | `List[str]` | `List[Safe_Str__File__Path]` | FIXED |
| `Graph__Repository.py` | 192 | `-> str` | `-> Safe_Str__Node_Type` | FIXED |
| `Graph__Repository.py` | 131 | `-> str` | `-> Safe_Str__File__Path` | FIXED |

### New schemas -- Type Safety compliance

| File | Compliant | Issue |
|------|-----------|-------|
| `Schema__Node__Type__Update.py` (data class) | YES | All fields use `Safe_*` types |
| `Schema__Node__Type__Update__Response.py` | PARTIAL | `node_type : object` should be `Schema__Node__Type` |
| `Schema__Link__Type__Update.py` (data class) | YES | All fields use `Safe_*` types |
| `Schema__Link__Type__Update__Response.py` | PARTIAL | `link_type : object` should be `Schema__Link__Type` |

### New methods -- `@type_safe` decorator usage

| Method | Has `@type_safe` | Compliant |
|--------|-------------------|-----------|
| `Type__Service.update_node_type` | YES | YES |
| `Type__Service.update_link_type` | YES | YES |
| `Node__Service.parse_label_to_type` | YES | YES |
| `Node__Service.label_from_type_and_index` | NO | **NO** -- missing decorator |
| `Node__Service.type_to_label_prefix` | NO | **NO** -- missing decorator, raw types |
| `Node__Service.get_current_root_path` | NO | Borderline -- returns Safe type but no decorator |
| `Node__Service.list_nodes_for_type` | NO | Pre-existing, not introduced in P2 |

---

## Test Coverage Assessment

### New test files

| Test File | Tests | Coverage |
|-----------|-------|----------|
| `test_Node__Service__B22__Hyphenated_Labels.py` | 16 | Good for happy path; missing false-positive edge case |
| `test_Type__Service__B15__Update_Node_Type.py` | 7 | Good -- covers update, partial, not-found, response |
| `test_Type__Service__B16__Update_Link_Type.py` | 7 | Good -- covers update, partial, not-found, response |
| `test_Node__Service__B17__Root_Scoping.py` | 13 | Excellent -- covers no-root, empty-root, with-root, type+root, deep nesting, total count |

### Coverage gaps

1. **`parse_label_to_type` prefix overlap false-positive** -- No test for label like `User-Story-5` when `user` is known but `user-story` is not. This is Bug-6.
2. **`type_to_label_prefix` with multi-segment types** -- No test for 3+ segment types (e.g., `my-long-type`).
3. **`update_node_type` / `update_link_type` with empty update** -- No test for calling update with a completely empty `Schema__*__Update` (all fields `None`). Should verify no-op behavior.
4. **`update_node_type` concurrent modification** -- No test for what happens if another caller modifies types between load and save.
5. **`resolve_link_target` with `Issue__Children__Service`-generated labels** -- No integration test verifying that labels generated by `Issue__Children__Service.generate_child_label` for hyphenated types can be resolved by `Node__Service.resolve_link_target`. This would immediately expose Bug-5.

---

## Recommendations

1. **Bug-4:** Add `@type_safe` to `type_to_label_prefix`, change parameter to `Safe_Str__Node_Type`, return `Safe_Str__Node_Type_Display` or a new `Safe_Str` variant.

2. **Bug-5:** Consolidate all label generation to a single implementation. Either:
   - Make `Node__Service.type_to_label_prefix` the canonical implementation and have `Issue__Children__Service` and `Path__Handler__Graph_Node` delegate to it, OR
   - Extract a shared `Label__Utils` class with the hyphenated logic, referenced by all three callers.
   - `Issue__Children__Service.generate_child_label` MUST produce `Git-Repo-1` format (not `GitRepo-1`) for consistency with B22.
   - `Path__Handler__Graph_Node.label_from_type_and_index` MUST produce `Git-Repo-1` format (not `Git-repo-1`).

3. **Bug-6:** After prefix matching, verify the remaining text between prefix and trailing digits is empty. Replace:
   ```
   if label_str.startswith(f"{prefix}-"):
   ```
   with a check that strips the prefix and verifies the remainder starts with a digit:
   ```
   remainder = label_str[len(prefix)+1:]
   if remainder and remainder[0].isdigit():
   ```
   Or alternatively, use a regex match: `re.match(f"^{re.escape(prefix)}-\\d+$", label_str)`.

4. **MAJOR-2:** Add `@type_safe` decorator to `label_from_type_and_index` and change `node_index` to `Safe_UInt`.

5. **MAJOR-3:** Change `node_type : object` to `node_type : Schema__Node__Type` in `Schema__Node__Type__Update__Response`, and `link_type : object` to `link_type : Schema__Link__Type` in `Schema__Link__Type__Update__Response`. Use string forward reference if circular import is a concern.

6. **MINOR-3:** Replace bare truthy checks with explicit `is not None` in the new B17/B22 code.

7. Add test for `parse_label_to_type` prefix-overlap scenario (Bug-6 regression test).

8. Add integration test: create a child issue via `Issue__Children__Service` for a hyphenated type, then resolve it via `resolve_link_target`. This would serve as a cross-service consistency test.
