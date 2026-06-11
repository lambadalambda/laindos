# Retune the MI2 save test choreography

`scripts/test_mi2_save.py` drives Monkey Island 2 through launch, copy
protection, intro skip, and a save via blind fixed delays and absolute
mouse coordinates tuned for the pre-HMA kernel. On the current kernel
the game runs (see issues/fix-mi2-save-dialog-crash.md) but the
choreography drifts: the "save dialog" screendump lands mid-intro and
SAVEGAME.002 is never created.

Rework the test to be state-driven: poll QEMU screendumps (PPM via the
monitor) and detect game phases (copy-protection screen, verb interface
present, save dialog up) instead of sleeping fixed durations. Then
verify the full save/reload flow completes as it did at b28cfad, and
consider registering the test in scripts/run_tests.py (it is currently
orphaned; mind the runtime, ~3 minutes).

## Resolution (2026-06-11)

Rewritten as a state-driven test: every phase (copy-protection prompt,
riddle, difficulty selection, F5 menu, save-name dialog, save completion,
in-game quit) is detected from QEMU screendumps by color/border
signatures, and all clicks are closed-loop -- the cursor's real position
is measured from screen diffs and corrected before clicking, because the
SCUMM dialogs draw at scene-dependent positions and mouse-delta scaling
varies by phase. The flow also discovered a previously unhandled
difficulty-selection screen ("CHECK ONE") that the old blind delays
sometimes skated past. The game is quit cleanly back to the shell before
QEMU exits so all handles close. Passes 2/2 including a fresh image
build; SAVEGAME.002 verified on the image (30,374 bytes, auto prefix).
