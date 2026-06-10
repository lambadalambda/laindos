# Unify 8.3 name truncation between lookup and create

## Summary

`resolve_path` and `parse_83name` disagree on undotted long components. `resolve_path` copies up to 11 bytes (`src/kernel/path_dir.inc:1064-1068`), letting the 9th-11th chars of an undotted name spill into the extension field, while `parse_83name` caps the base at 8 (path_dir.inc:1737-1739). A file or directory created as `DIRNAMEXX` gets entry `DIRNAMEX` but is looked up as `DIRNAMEXX  ` packed differently — it can never be opened or CD'd into by its own name. 12+-char undotted components error in `resolve_path` (`.rp_name_overflow`) but are silently truncated by `parse_83name`.

## Requirements

- Use one shared component-to-11-byte-name conversion for both lookup and create/mkdir/rename/delete, with identical truncation rules (8-char base, 3-char extension).

## Acceptance Criteria

- Test: create `DIRNAMEXX` (file and directory), then open/CD into it by the same name; create a 12+-char name and confirm lookup and create agree on the outcome; `PASS:` markers.
- Existing path/find tests pass.
