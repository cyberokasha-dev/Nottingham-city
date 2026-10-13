# Bajinka: Nottingham City

## Milestone 4: walk up to any vehicle

The game opens directly into a vehicle courtyard with the animated human standing on foot. The car selection screen is removed. Six vehicles coexist: the gold Aurora concept car, sports sedan, luxury SUV, city van, tow truck and articulated truck. Walk to a vehicle and press E; the nearby vehicle's name appears in the prompt. You can drive, stop, get out and switch to another vehicle. Other vehicles stay parked.

The Aurora is an original Cybercab-inspired game model, with a gold body, dark panoramic canopy, covered wheels and light bars. The other new cars use Kenney's CC0 Car Kit. The trucks retain the functional towing and articulated trailer from the Godot Truck Town demo, with refreshed surface, wheel and light details. The town remains the upstream demonstration map, not a reconstruction of Nottingham.

### Play in Chrome

Play at https://cyberokasha-dev.github.io/Nottingham-city/ after the latest GitHub Actions deployment succeeds. Click the game canvas to focus the keyboard. After an update, use Ctrl+Shift+R to reload the current build. Chrome needs WebGL 2.

The `.github/workflows/web.yml` workflow imports with Godot 4.4.1, checks the complete on-foot/vehicle flow, exports a single-threaded browser game, then publishes it to GitHub Pages. Each successful build also saves the `Nottingham-City-Web` downloadable artifact. Downloaded HTML needs an HTTP server; the hosted game link is the easiest way to play.

### Controls

- On foot: WASD walks, Shift runs, Space jumps. Hold the right mouse button and drag to look around.
- E: enter the nearest vehicle within reach. A wall between you and the vehicle blocks entry.
- Driving: WASD or arrow keys steer, accelerate and reverse. Space applies the brake.
- E while stopped: get out when there is clear ground beside the vehicle.
- C: cycle exterior, interior and overhead driving cameras.
- U: cycle speed units.

The Quaternius human has a face, arms, hands, articulated fingers, hair, fitted clothes and shoes. Idle, walking, running, jumping and landing blend automatically. Entry approaches a clear side and blends sitting motion and cameras; exit blends standing motion back to walking. Doors are not animated and the driver is hidden inside the current vehicle interiors.

### Run in Godot

1. Install Godot 4.4.1 or a newer compatible Godot 4 editor.
2. Download or clone the repository, then import `project.godot`.
3. Wait for assets to import and press F5. The character appears in the courtyard without a menu.

The Compatibility renderer reduces GPU requirements. Native rendered previews are in `screenshots/`. Chromebook performance and phone walking controls still need device work; weapons, police and multiplayer are not implemented.

### Validation

The automated Godot smoke test launches the actual main scene, verifies a visible human standing on the ground, checks all six nearby vehicles, walking and jumping, nearest-vehicle selection, input locking during transitions, active-vehicle acceleration, unoccupied-vehicle isolation, moving-exit prevention and safe exits back to walking. Browser export is checked separately. The original Godot Truck Town import is pinned to demo release `4.2-31d1c0c` (commit `31d1c0c1122717b3ad74aeb94255bc38def52747`).

### Asset licenses

- Code and original concept geometry: MIT, see `LICENSE.md`.
- Character and animations: Quaternius CC0, see `player/models/SOURCES.md` and preserved license files.
- New everyday cars: Kenney CC0, see `vehicles/models/SOURCES.md` and `KENNEY-LICENSE.txt`.
- Original trucks and town: official Godot Truck Town demo, MIT; see `UPSTREAM_README.md`.

No Rockstar code, GTA models or restricted Tesla model files are included. Vehicle and character license files are copied alongside the browser export.
