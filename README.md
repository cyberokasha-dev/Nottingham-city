# Bajinka: Nottingham City

## Milestone 3: animated human character

Adapted from the official Godot Truck Town demo, pinned to Godot demo release `4.2-31d1c0c` (commit `31d1c0c1122717b3ad74aeb94255bc38def52747`). Includes a town, three vehicle choices, vehicle physics and camera views. The town is the upstream demonstration map, not a reconstruction of Nottingham yet.

### Play in Chrome (no Linux installation needed)

The browser build is published by `.github/workflows/web.yml` using Godot 4.4.1 and matching export templates. It uses a single-threaded Web export, so GitHub Pages does not need special isolation headers.

One-time repository setup: open **Settings → Pages**, choose **GitHub Actions** under Source, and save if prompted. Open **Actions → Build and publish browser game** to check the build and deployment. If needed, choose **Run workflow** after enabling Pages.

After the deployment succeeds, play at https://cyberokasha-dev.github.io/Nottingham-city/ . This URL is usable only after Pages is enabled and a deployment has succeeded.

Click the game canvas and choose a vehicle. You start on foot beside it. Walk up and press E to enter; use the arrow keys to drive, Space to brake, then E to get out. C changes the camera; U changes speed units; Escape returns to vehicle selection. Chrome needs WebGL 2 support. Chromebook performance is not yet verified.

Each successful build also saves a `Nottingham-City-Web` artifact in its Actions run. The exported files need an HTTP server; double-clicking the downloaded HTML is not supported. The hosted Pages link is the easiest way to play.

### Run in the editor

1. Install Godot 4.2 or a newer compatible Godot 4 editor.
2. Download this repository as ZIP and extract it, or clone it.
3. In Godot Project Manager choose Import and select `project.godot`.
4. Wait for assets to import. Press F6 only for the current scene; press F5 to run the full project.
5. Choose a vehicle in the menu.

The project uses the Compatibility renderer to reduce GPU requirements. Performance on the user's Chromebook is not tested.

### Controls

On foot: WASD walks, Shift runs, Space jumps. Hold the right mouse button and drag to look around. Press E near the selected vehicle to enter. The character is a rounded, skinned Quaternius human with a face, arms, hands, articulated fingers, hair and fitted clothes. Idle, walk, sprint, jump and landing poses blend automatically. Vehicle entry approaches a clear side and blends sitting motion and cameras; exit blends standing motion back to walking.

Driving:

- Up/W: accelerate.
- Down/S: brake and reverse.
- Left/right arrows: steer.
- Space: handbrake.
- E: get out once stopped, when there is clear ground beside the vehicle.
- C: cycle exterior/interior/top-down cameras.
- U: cycle speed units.
- Escape: return to vehicle selection.

See [UPSTREAM_README.md](UPSTREAM_README.md) for gamepad and mobile controls.

### Status and limitations

Source and resource references checked. Godot 4.4.1 imports the project and launches the vehicle-selection scene in a headless smoke check. Browser export is checked separately; interactive driving and Chromebook performance still need device testing. Automated Godot checks cover the imported human rig and motion clips, walking, jumping, entry distance, transition control locking, parked throttle isolation, driving, moving-exit prevention, safe exiting and re-entry with all three vehicle choices. Exiting parks the whole vehicle rig in place; re-entry restores physics. The character uses keyboard and mouse controls; walking on phones, weapons, police, phone controller and multiplayer are not implemented yet. These are subsequent milestones.

### Licensing

Upstream code is MIT: see [LICENSE.md](LICENSE.md). Retain the upstream copyright and licence in redistributions. This import does not include Rockstar code or GTA assets. Original upstream documentation is retained in UPSTREAM_README.md.

Character assets and selected animations are CC0 by Quaternius. See [player/models/SOURCES.md](player/models/SOURCES.md) for provenance, preparation, checksums and character limitations.
