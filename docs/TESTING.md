# Validation record

Validated with **Godot 4.6.3 stable** in a Linux environment. This record separates source/runtime tests from target-native testing.

## Automated rules tests

`tests/smoke_test.gd`: 16 passing checks covering scene load, menu, roster/boxes, circuit shape, countdown lock, throttle, screen-right steering, all three item types, drift release turbo, off-road detection, rescue, skipped-checkpoint rejection, pause/resume and course/driver reset.

`tests/race_simulation.gd`: deterministic steering controller completes all three laps using the same kart movement and race rules as gameplay, with seven active AI and usable items:

- Clover Coast: lap 4 / finished, 60.58 seconds, rank 1, 3,635 simulation frames.
- Copper Canyon: lap 4 / finished, 70.55 seconds, rank 2, 4,233 simulation frames.

Simulation uses fixed 1/60-second steps and does not teleport the kart or directly increment laps. The separate UI-result check positions the kart at the final checkpoint only to exercise the result screen.

## Graphical runtime tests

`tests/visual_test.gd` ran using real Godot OpenGL rendering, Mesa llvmpipe and an Xorg dummy display. Captured and visually inspected the menu, countdown, both circuits, pause, controls and results. Input is dispatched through `Input.parse_input_event`; pause was verified to freeze the race clock. Course/driver selection and restart were checked. This is rendered Linux testing, not a claim of native macOS or Windows gameplay testing.

The local display environment disallowed Unix-domain sockets, so the virtual X server used loopback TCP. This is a test-host detail, not a game requirement.

## Exports

The release script runs import, smoke tests, full-race simulations, boot check and Windows/macOS exports, then verifies archive structure, executable headers/architectures, macOS ad-hoc signature presence and SHA-256 checksums. See RELEASING.md.

## Still requiring native hardware checks

- Windows/macOS gameplay, audio-device behavior and window management.
- Physical controller mappings on different operating systems.
- Apple Gatekeeper/notarization workflow (builds are unsigned / not notarized).
- Long-duration performance on older GPUs and high-DPI displays.

## Scope and known limitations

Single-player arcade prototype with two courses and three-lap races. Driver selection is cosmetic. AI uses a waypoint controller, not a full navigation mesh. There is no reverse gear; use Backspace to rescue with a three-second penalty. Display text is English, with Chinese controls documented in README. Best records save to Godot's per-user data directory.
