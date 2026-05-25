# Fix FindFirst Attribute Filtering

## Summary

`FindFirst` and `FindNext` currently special-case volume labels but do not fully apply DOS search attribute rules for hidden, system, and directory entries.

## Requirements

- Implement DOS-compatible filtering for normal, hidden, system, directory, and volume-label entries.
- Ensure `CX=0` returns only normal matching files.
- Ensure entries with hidden/system/directory attributes are returned only when requested by the search mask.

## Acceptance Criteria

- A regression creates or images normal, hidden/system, and directory entries, then verifies `FindFirst`/`FindNext` filtering for relevant masks.
- Existing shell directory listings retain expected behavior.

## Notes

- Reviewers flagged `find_in_dir` root and subdirectory matchability checks around `ATTR_VOLUME`.
- Current mkimage support may need an attribute-enabled test fixture, or a small DOS test can create entries via attribute APIs once supported.
