# Deduplicate CD-ROM driver paths

## Summary

Three verbatim duplications in `src/kernel/cdrom.inc`: (a) `cd_scan_current_dir` (841-892) and `cd_find_from` (1045-1104) duplicate the size-to-sector-count conversion and sector-scan loop; (b) `mount_bios_cdrom_d` (352-396) and `mount_atapi_cdrom_d` (427-468) duplicate the "CD001" PVD validation and root-extent extraction byte-for-byte; (c) `atapi_select_current`/`atapi_select_scan` (64-100) are identical except for which variable triplet they read. Also in exec.inc: `exec_read_first_sector`/`exec_read_first_sector_cd` are verbatim duplicates of `overlay_read_first_sector`/`overlay_read_first_sector_cd` differing only in the variable pair read (`src/kernel/exec.inc:228-302` vs 987-1063, ~70 removable lines).

## Requirements

- Extract one scan loop, one PVD-validate helper, one parameterized ATAPI select, and one parameterized first-sector reader.

## Acceptance Criteria

- Pure refactor: all CD tests (cd_file, cd_find, cd_subdir, cd_bios, sammax targets) pass; each duplicated block has a single definition.

## Resolution (2026-06-11)

- `atapi_select_via` takes SI -> {base, ctrl, devsel} (the two variable
  triplets are contiguous), with atapi_select_current/_scan as thin
  wrappers.
- `cd_validate_pvd` (CD001 signature + root extent extraction) and
  `cd_register_drive` (the D: drive-table registration and CWD reset)
  replace the byte-for-byte duplication between mount_bios_cdrom_d and
  mount_atapi_cdrom_d.
- `cd_scan_extent` walks a directory extent sector by sector invoking
  the callback at [cs:cd_scan_handler]; cd_scan_current_dir and
  cd_find_from collapse onto it.
- `read_first_cluster_sector` (AX = cluster) and `read_first_sector_cd`
  (AX/DX = LBA) replace the four exec/overlay first-sector readers;
  exec_read_first_sector[_cd] are thin loaders and the overlay pair is
  a dispatching wrapper.
- Suite passes 139/139; kernel shrank 37993 -> 37728 bytes.
