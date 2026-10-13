# Bajinka: Nottingham City

## Milestone 1: driving foundation

Adapted from the official Godot Truck Town demo, pinned to Godot demo release `4.2-31d1c0c` (commit `31d1c0c1122717b3ad74aeb94255bc38def52747`). Includes a town, three vehicle choices, vehicle physics and camera views. The town is the upstream demonstration map, not a reconstruction of Nottingham yet.

### Run

1. Install Godot 4.2 or a newer compatible Godot 4 editor.
2. Download this repository as ZIP and extract it, or clone it.
3. In Godot Project Manager choose Import and select `project.godot`.
4. Wait for assets to import. Press F6 only for the current scene; press F5 to run the full project.
5. Choose a vehicle in the menu.

The project uses the Compatibility renderer to reduce GPU requirements. Performance on the user's Chromebook is not tested.

### Controls

- Up/W: accelerate.
- Down/S: brake and reverse.
- Left/right arrows: steer.
- C: cycle exterior/interior/top-down cameras.
- U: cycle speed units.
- Escape: return to vehicle selection.

See [UPSTREAM_README.md](UPSTREAM_README.md) for gamepad and mobile controls.

### Status and limitations

Imported source and resource references checked. Godot is not installed in the build workspace, so runtime and visual driving checks have not been performed. No walking character, enter/exit mechanic, weapons, police, phone controller or multiplayer is implemented yet. These are subsequent milestones.

### Licensing

Upstream code is MIT: see [LICENSE.md](LICENSE.md). Retain the upstream copyright and licence in redistributions. This import does not include Rockstar code or GTA assets. Original upstream documentation is retained in UPSTREAM_README.md.
