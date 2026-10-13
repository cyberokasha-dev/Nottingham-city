# Bajinka: Nottingham City

## Milestone 1: driving foundation

Adapted from the official Godot Truck Town demo, pinned to Godot demo release `4.2-31d1c0c` (commit `31d1c0c1122717b3ad74aeb94255bc38def52747`). Includes a town, three vehicle choices, vehicle physics and camera views. The town is the upstream demonstration map, not a reconstruction of Nottingham yet.

### Play in Chrome (no Linux installation needed)

The browser build is published by `.github/workflows/web.yml` using Godot 4.4.1 and matching export templates. It uses a single-threaded Web export, so GitHub Pages does not need special isolation headers.

One-time repository setup: open **Settings → Pages**, choose **GitHub Actions** under Source, and save if prompted. Open **Actions → Build and publish browser game** to check the build and deployment. If needed, choose **Run workflow** after enabling Pages.

After the deployment succeeds, play at https://cyberokasha-dev.github.io/Nottingham-city/ . This URL is usable only after Pages is enabled and a deployment has succeeded.

Click the game canvas, choose a vehicle, then use the arrow keys to drive. C changes the camera; U changes speed units; Escape returns to vehicle selection. Chrome needs WebGL 2 support. Chromebook performance is not yet verified.

Each successful build also saves a `Nottingham-City-Web` artifact in its Actions run. The exported files need an HTTP server; double-clicking the downloaded HTML is not supported. The hosted Pages link is the easiest way to play.

### Run in the editor

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

Source and resource references checked. Godot 4.4.1 imports the project and launches the vehicle-selection scene in a headless smoke check. Browser export is checked separately; interactive driving and Chromebook performance still need device testing. No walking character, enter/exit mechanic, weapons, police, phone controller or multiplayer is implemented yet. These are subsequent milestones.

### Licensing

Upstream code is MIT: see [LICENSE.md](LICENSE.md). Retain the upstream copyright and licence in redistributions. This import does not include Rockstar code or GTA assets. Original upstream documentation is retained in UPSTREAM_README.md.
