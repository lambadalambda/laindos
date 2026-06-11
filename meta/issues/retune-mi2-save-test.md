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
