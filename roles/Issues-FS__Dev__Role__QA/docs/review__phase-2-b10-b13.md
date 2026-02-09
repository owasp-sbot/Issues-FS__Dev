# QA Review: Phase 2 B10-B13

**Reviewer:** QA Agent
**Date:** 2026-02-08
**Branch:** dev
**Tests:** 371 pass (reported by Dev)
**Scope:** Tasks 1-4 (B10, B11, B12, B13) in the Issues-FS module

---

## Summary

The Dev completed four tasks implementing Phase 2 graph infrastructure changes:
- **B10:** Recursive node discovery (`nodes_list_all`)
- **B11:** Path-based node loading (`node_load_by_path`, `node_find_path_by_label`, `node_load_by_label`)
- **B12:** Legacy `node.json` cleanup on save (`delete_legacy_node_json`)
- **B13:** Removal of `node.json` fallback across all services

Two new schema files were created. Four source files and three test files were modified. Three new test files were created for B10, B11, and B12. One new test file was created for B13.

Overall the work is **solid and well-structured**, with good test coverage and proper use of `@type_safe` decorators on new methods. However, there are **3 defects** found (including the known Bug-1), plus several items flagged as MINOR or NOTE.

---

## Per-Task Review

### Task 1 (B10): Recursive Node Discovery

**Files changed:** `Graph__Repository.py`, `Node__Service.py`
**New file:** `Schema__Node__Info.py`
**Tests:** `test_Graph__Repository__B10__Recursive_Discovery.py` (14 tests)

**Implementation:**
- `nodes_list_all()` scans all `issue.json` files recursively, returning `List[Schema__Node__Info]`
- `SKIP_LABELS` class constant filters system folders (`config`, `data`, `issues`, `indexes`, `.issues`)
- `is_path_under_root()` supports root-path scoping with proper boundary handling
- `extract_node_type_from_file()` reads `node_type` from JSON with error handling
- `nodes_list_labels()` refactored to delegate to `nodes_list_all()`
- `Node__Service.list_nodes_for_type()` updated to use `nodes_list_all` with root filtering

**Assessment:** PASS with findings.
- `Schema__Node__Info` correctly inherits from `Type_Safe` and uses all `Safe_*` primitives.
- `SKIP_LABELS` is a raw Python `set` as a class attribute. See Finding MINOR-1.
- `extract_node_type_from_file` returns raw `str`. See Finding MAJOR-1.
- Test coverage is comprehensive: top-level, nested, system folder filtering, root_path filtering, empty storage, return type verification.

### Task 2 (B11): Path-Based Node Loading

**Files changed:** `Graph__Repository.py`, `Node__Service.py`
**New file:** `Schema__Node__Response.py`
**Tests:** `test_Graph__Repository__B11__Path_Based_Loading.py` (10 tests)

**Implementation:**
- `node_load_by_path()` loads from explicit folder path (issue.json only)
- `node_find_path_by_label()` searches all paths for a label, returns `Safe_Str__File__Path`
- `node_load_by_label()` combines find + load
- `Node__Service.get_node_by_path()` wraps repository call in `Schema__Node__Response`

**Assessment:** PASS.
- `Schema__Node__Response` correctly inherits from `Type_Safe` and uses `Safe_Str__Text` for message.
- All new methods use `@type_safe` decorator and `Safe_*` parameter types.
- Test coverage includes: direct load, nested path load, missing path, node.json-only path, find by label (top-level and nested), missing label, and service-level tests for both success and failure.

### Task 3 (B12): Legacy node.json Cleanup on Save

**Files changed:** `Graph__Repository.py`
**Tests:** `test_Graph__Repository__B12__Delete_Legacy_On_Save.py` (5 tests), updated Phase 1 test

**Implementation:**
- `node_save()` now calls `delete_legacy_node_json()` after successful save
- `delete_legacy_node_json()` checks for and removes legacy `node.json`
- Uses `is True` check on result before triggering cleanup

**Assessment:** PASS.
- Clean separation of concerns with dedicated helper method.
- Uses `@type_safe` decorator and `Safe_*` parameter types.
- Test coverage includes: delete existing, returns false when missing, save triggers cleanup, save works without legacy, round-trip after cleanup.
- Phase 1 test `test__node_save__preserves_existing_node_json` correctly updated to `test__node_save__deletes_existing_node_json`.

### Task 4 (B13): Remove node.json Fallback

**Files changed:** `Graph__Repository.py`, `Issue__Children__Service.py`, `Root__Selection__Service.py`
**Tests:** `test_B13__Remove_Node_Json_Fallback.py` (18 tests), updated Phase 1 tests

**Implementation:**
- `get_issue_file_path()` no longer falls back to `node.json`; uses `is True` explicit check
- `Root__Selection__Service.is_valid_root()` simplified to check `issue.json` only
- `Root__Selection__Service.scan_for_issue_folders()` only matches `issue.json`
- `Root__Selection__Service.count_top_level_issues()` only counts `issue.json`
- `Root__Selection__Service.count_children_in_folder()` only counts `issue.json`
- `Root__Selection__Service.load_issue_summary()` no longer falls back to `node.json`
- `Issue__Children__Service.parent_exists()` simplified to check `issue.json` only
- `Issue__Children__Service.scan_child_folders()` only matches `issue.json`
- `Issue__Children__Service.load_child_summary()` no longer falls back to `node.json`
- `FILE_NAME__NODE_JSON` import removed from `Root__Selection__Service`

**Assessment:** PASS with findings.
- B13 changes are thorough and consistent across all three services.
- Test coverage is extensive with dedicated B13 test file covering all affected methods.
- Phase 1 tests correctly updated (6 tests renamed and assertions adjusted).
- `scan_child_folders()` return type changed from `List[Safe_Str__File__Path]` to `List[str]`. This is Bug-1 (already filed). See also Finding CRITICAL-1.
- The file header comment box opener (`# ===...`) was removed from `Issue__Children__Service.py` line 1. See Finding MINOR-2.

---

## Findings

### CRITICAL-1 (Bug-1, already filed): `scan_child_folders` type regression

**File:** `issues_fs/issues/phase_1/Issue__Children__Service.py` line 216
**Change:** `List[Safe_Str__File__Path]` downgraded to `List[str]`
**Status:** Already filed as Bug-1 (P1, confirmed)
**Impact:** Violates core Type_Safe convention. Callers lose type safety guarantees.

### MAJOR-1 (New, Bug-2): `extract_node_type_from_file` returns raw `str`

**File:** `issues_fs/issues/graph_services/Graph__Repository.py` line 192
**Method signature:** `def extract_node_type_from_file(...) -> str:`
**Issue:** This newly introduced method returns raw `str` instead of `Safe_Str__Node_Type`. The method reads the `node_type` field from a JSON file and returns it as a bare `str`. Since `Safe_Str__Node_Type` is already imported and used throughout this file, the return type should be `Safe_Str__Node_Type` (with appropriate wrapping of the returned value).
**Impact:** Introduces a raw type into a method chain that feeds into `Schema__Node__Info` construction. While the caller at line 168 wraps the return in `Safe_Str__Node_Type()`, the method itself does not enforce type safety at its boundary.

### MAJOR-2 (New, Bug-3): `get_issue_file_path` returns raw `str`

**File:** `issues_fs/issues/graph_services/Graph__Repository.py` line 131
**Method signature:** `def get_issue_file_path(...) -> str:`
**Issue:** This method's return type annotation is `-> str` when it should be `-> Safe_Str__File__Path`. This was pre-existing (Phase 1 also returned `str`), but the Dev had the opportunity to fix it during B13 refactoring and chose not to. Since this method is the central path-resolution function called by `node_load`, `node_exists`, and other critical paths, the raw `str` return type is a type safety gap.
**Note:** This is borderline between pre-existing and newly-introduced -- the Dev modified this method's body and comments but kept the raw return type. Flagged as MAJOR because the method was touched in this changeset.

### MINOR-1: `SKIP_LABELS` is a raw Python `set`

**File:** `issues_fs/issues/graph_services/Graph__Repository.py` line 39
**Code:** `SKIP_LABELS = {'config', 'data', 'issues', 'indexes', '.issues'}`
**Issue:** This class-level constant is a raw `set` literal rather than a Type_Safe-compatible construct. While class constants are somewhat different from instance attributes, the project convention strongly favors avoiding raw Python types. This could be a frozenset at minimum, or ideally a Type_Safe-wrapped collection.
**Impact:** Low. It is a constant used only for membership testing.

### MINOR-2: File header comment asymmetry in `Issue__Children__Service.py`

**File:** `issues_fs/issues/phase_1/Issue__Children__Service.py` line 1
**Issue:** The Dev removed the opening `# ===...` separator line from the file header while leaving the closing separator intact at line 9. All other files in the codebase use symmetric `# ===...` delimiters for their header blocks. This is a cosmetic inconsistency.

### MINOR-3: Import alignment not fixed in `Issue__Children__Service.py` and `Root__Selection__Service.py`

**Files:** Both Phase 1 service files
**Issue:** The `issues_fs.*` imports at lines 20-24 of `Issue__Children__Service.py` and lines 13-15 of `Root__Selection__Service.py` have `import` keyword at column ~59-65 instead of column 70-80. The Dev fixed alignment in `Graph__Repository.py` and `Node__Service.py` but did not fix these two files. Since the Dev touched these files (modifying multiple methods), import alignment should have been fixed as well.
**Impact:** Cosmetic, violates project import alignment convention at column 70-80.

### NOTE-1: `root_selection_service` typed as `object`

**File:** `issues_fs/issues/graph_services/Node__Service.py` line 41
**Code:** `root_selection_service : object = None`
**Issue:** The attribute is typed as `object` rather than `Root__Selection__Service`. This was likely done to avoid a circular import. The comment says "Phase 2 (B14/B17)" indicating this is forward-looking. Acceptable as a temporary measure, but should be resolved before Phase 2 is complete (e.g., via Protocol typing or lazy import).

### NOTE-2: Truthy checks remain in some methods

Several methods use truthy/falsy checks (`if not content`, `if content`, `if node_type`) rather than explicit `is True` / `is False` / `is not None` checks. Examples:
- `Graph__Repository.py` lines 88, 195, 216, 279, 307, 332, 360
- `Node__Service.py` line 67 (`if node_type:`)

Most of these are pre-existing, but the convention requires explicit checks. The Dev did correctly use `is True` / `is False` in newly written code (lines 134, 137, 151, 212), which is good.

### NOTE-3: Underscore-prefix methods renamed

The Dev renamed `_traverse_graph`, `_resolve_link_target`, `_find_incoming_links` to `traverse_graph`, `resolve_link_target`, `find_incoming_links` in `Node__Service.py`. This correctly follows the project convention of no underscore prefixes. Good fix.

---

## Type Safety Audit

### New raw types introduced by Dev

| File | Line | Type | Severity |
|------|------|------|----------|
| `Issue__Children__Service.py` | 216 | `List[str]` (was `List[Safe_Str__File__Path]`) | CRITICAL (Bug-1) |
| `Graph__Repository.py` | 192 | `-> str` return on `extract_node_type_from_file` | MAJOR (Bug-2) |

### Raw types touched but not fixed by Dev

| File | Line | Type | Severity |
|------|------|------|----------|
| `Graph__Repository.py` | 131 | `-> str` return on `get_issue_file_path` | MAJOR (Bug-3) |

### Pre-existing raw types (not introduced by Dev, not in scope)

Multiple methods across `Issue__Children__Service.py` and `Root__Selection__Service.py` use raw `str`, `dict`, `int`, `list` as parameter types and return types. These are pre-existing and outside the scope of this review, but are noted for future cleanup.

### New schemas - Type Safety compliance

| File | Compliant |
|------|-----------|
| `Schema__Node__Info.py` | YES - inherits `Type_Safe`, uses `Safe_Str__Node_Label`, `Safe_Str__File__Path`, `Safe_Str__Node_Type` |
| `Schema__Node__Response.py` | YES - inherits `Type_Safe`, uses `Safe_Str__Text`, `Schema__Node`, `bool` |

### New methods - @type_safe decorator usage

All newly created public methods in `Graph__Repository.py` and `Node__Service.py` correctly use the `@type_safe` decorator:
- `delete_legacy_node_json` - YES
- `nodes_list_all` - YES
- `is_path_under_root` - YES
- `extract_node_type_from_file` - YES
- `node_load_by_path` - YES
- `node_find_path_by_label` - YES
- `node_load_by_label` - YES
- `get_node_by_path` (Node__Service) - YES

---

## Test Coverage Assessment

### New test files created

| Test File | Tests | Coverage |
|-----------|-------|----------|
| `test_Graph__Repository__B10__Recursive_Discovery.py` | 14 | Excellent - covers `nodes_list_all`, `is_path_under_root`, `extract_node_type_from_file`, updated `nodes_list_labels` |
| `test_Graph__Repository__B11__Path_Based_Loading.py` | 10 | Excellent - covers `node_load_by_path`, `node_find_path_by_label`, `node_load_by_label`, `Node__Service.get_node_by_path` |
| `test_Graph__Repository__B12__Delete_Legacy_On_Save.py` | 5 | Good - covers `delete_legacy_node_json` and save-triggers-cleanup |
| `test_B13__Remove_Node_Json_Fallback.py` | 18 | Excellent - covers all three services (Graph__Repository, Root__Selection, Issue__Children) plus Migration script |

### Updated test files

| Test File | Changes |
|-----------|---------|
| `test_Graph__Repository__Phase_1.py` | 6 tests updated to reflect B12/B13 behavior (renamed, assertions changed) |
| `test_Root__Selection__Service.py` | 1 test updated for B13 |

### Coverage gaps

1. **`Node__Service.get_current_root_path()`** - No dedicated test. Only tested indirectly through `list_nodes` integration.
2. **`Node__Service.list_nodes_for_type()` with root_path** - Tested only through `list_nodes` integration, no isolated test.
3. **`Graph__Repository.nodes_list_all()` performance** - No test for large datasets (many hundreds of files). This is a full scan of all paths on every call. Should be noted for future optimization.

### Test naming convention

All new tests follow the `test__method_name` pattern correctly.

---

## Recommendation

**APPROVE WITH CONDITIONS**

The implementation is well-structured, the Phase 2 changes are internally consistent, and test coverage is strong. However, three conditions must be met before merge:

1. **Bug-1 (CRITICAL):** Revert `List[str]` back to `List[Safe_Str__File__Path]` in `scan_child_folders()` at `Issue__Children__Service.py` line 216. Already filed.

2. **Bug-2 (MAJOR):** Change `extract_node_type_from_file()` return type from `-> str` to `-> Safe_Str__Node_Type` (or at minimum, ensure the return value is wrapped). File: `Graph__Repository.py` line 192.

3. **Bug-3 (MAJOR):** Change `get_issue_file_path()` return type from `-> str` to `-> Safe_Str__File__Path`. File: `Graph__Repository.py` line 131. This method was modified in B13 and should have been fixed.

Once these three items are addressed, the changeset is ready for merge.
