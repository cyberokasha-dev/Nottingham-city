# Bajinka: Nottingham City

## Milestone 8: Muhammad, four-character wheel and scene dialogue

The game opens directly as **Muhammad**, with a relaxed standing pose. His fitted CC0 body has slimmer proportions, a turquoise short-sleeved shirt, beige trousers and dark trainers based on the supplied full-body references. A generated face albedo projects the supplied facial likeness onto the rigged head. This is a photo-informed stylized 3D likeness; it is not a photogrammetry scan or AAA character sculpt. Press H to fold his arms deliberately; walking or pressing H again relaxes them.

Press C to open a circular four-wedge selector: **Muhammad, Aisha, Musa and Jade**. Click a wedge or press 1–4; Enter confirms the highlighted option, and C/Esc closes the wheel. All four are actual persistent playable bodies, keeping their own position, health and house context. Camera, map and nearby-resident references follow the selected character. Switching from a car first requires a safe stopped exit. B/R3 now changes the driving camera; C is reserved for character selection. Inactive playable characters wait in the world rather than running full autonomous routines.

The game opens into a vehicle courtyard with the animated human standing on foot. The car selection screen is removed. Six vehicles coexist: the gold Aurora concept car, sports sedan, luxury SUV, city van, tow truck and articulated truck. Walk to a vehicle and press E; the nearby vehicle's name appears in the prompt. You can drive, stop, get out and switch to another vehicle. Other vehicles stay parked.

The Aurora is an original Cybercab-inspired game model, with a gold body, dark panoramic canopy, covered wheels and light bars. The other new cars use Kenney's CC0 Car Kit. The trucks retain the functional towing and articulated trailer from the Godot Truck Town demo, with refreshed surface, wheel and light details. The old demonstration hills and terrain are replaced by an original compact city layout: 11 connected streets, 30 level junctions, pavements, crossings, two parks and 68 residential houses. It is a fictional game city, rather than a geographic reconstruction of Nottingham.

Twelve named residents now share the human animation rig. Six use the female base mesh, six the male base mesh; skin tones, clothing, body proportions, eye detail and tied/short hair distinguish them. They walk or jog between the courtyard, park areas, neighbourhood and shops, pause for scripted text conversations, return home and sit or sleep. Green mini-map dots show residents. These are local state-machine routines. The player and nearby residents now use audible synthetic male/female voice clips, accompanied by text bubbles. Neighbours take turns in conversations, and E gives a voiced player greeting followed by a resident reply. Voices use bundled Ogg audio rather than a live service; there is no generative AI chat or microphone listening. The new dialogue pack contains 190 authored scene/event lines plus the original ten phrases, rendered in both voices. Contexts cover streets, parks, vehicles, homes, injuries, hostility and familiar friends. Every playable character has separate openings and responses in those contexts, plus short lines for entering/exiting cars and houses, sitting, sleeping, waking, switching and Muhammad's folded-arms pose.

Press E near a resident, listen to both short opening lines, then choose a reply with buttons or 1–3. Kind replies improve the NPC's relationship; apologies stop a fight, threats provoke defensive behaviour, invitations make the NPC walk nearby for 20 seconds, and directions add a blue park marker. G/Esc ends a conversation. NPCs remember a separate relationship with each protagonist during the current session. Dialogue is bounded and authored for the implemented situations, not unlimited generated conversations. Named destinations and the sidewalk graph are ready for a future bus/taxi system; public transport is not implemented yet.

Punches use a timed contact frame, a short reach and facing cone, and a wall visibility check. Residents show nearby health bars, recoil and briefly flash when hit. The player has a coloured health bar and a short red damage overlay. At zero health, the player and residents play a death fall, remain down at zero health, then animate waking up and restore health (six seconds for the player, seven for residents). Dead actors cannot attack, talk or use furniture, and waking grants two seconds of protection. The player can block a punch from the front. Sleeping restores eight health points per second. There are no weapons or gore.

### Play in Chrome

Play at https://cyberokasha-dev.github.io/Nottingham-city/ after the latest GitHub Actions deployment succeeds. Click the game canvas to focus the keyboard. After an update, use Ctrl+Shift+R to reload the current build. Chrome needs WebGL 2.

The `.github/workflows/web.yml` workflow imports with Godot 4.4.1, checks the complete on-foot/vehicle flow, exports a single-threaded browser game, then publishes it to GitHub Pages. Each successful build also saves the `Nottingham-City-Web` downloadable artifact. Downloaded HTML needs an HTTP server; the hosted game link is the easiest way to play.

### Controls

Use the mini-map at the top right to find roads, houses and the parked fleet; the yellow marker is the player. Walk up to a house entrance and press E to open the door and enter. Interiors contain a living area, kitchen, bed and furniture with collision. Walk back toward the front door and press E to leave. A cutaway roof and elevated camera keep the human visible indoors. Every home has its own address and entrance; homes share the initial floor plan.

- On foot: WASD walks, Shift runs, Space jumps. Hold the right mouse button and drag to look around.
- △ / E: use a nearby door or vehicle, talk to a resident, sit beside a sofa or sleep beside a bed.
- ○ / G: stand up or wake up. E also leaves a resting pose. Furniture slots prevent two people using the same seat or bed.
- □ / F: light punch; R1 / R: heavy punch; L1 / Q: hold to guard.
- ✕ / Space: jump on foot, handbrake while driving.
- L2 / Z: slow focused movement on foot; R2 / V: alternate punch input.
- Gamepad: left stick moves, right stick looks, L3 sprints. When driving, R2 accelerates, L2 reverses and R3 cycles the camera; C opens the character wheel.
- The on-screen PlayStation-style buttons are clickable/touchable. Keyboard movement remains WASD; gamepad support needs physical-device testing.
- Driving: WASD or arrow keys steer, accelerate and reverse. Space applies the brake.
- E while stopped: get out when there is clear ground beside the vehicle.
- B / R3: cycle exterior, interior and overhead driving cameras.
- C / D-pad down: four-character wheel. H: Muhammad folds or relaxes his arms.
- U: cycle speed units.

The Quaternius human has a face, arms, hands, articulated fingers, hair, fitted clothes and shoes. Idle, walking, running, jumping and landing blend automatically. New seated, talking, jab, cross and hit clips animate home and combat actions. Entry approaches a clear side and blends sitting motion and cameras; exit blends standing motion back to walking. Vehicle doors are not animated and the driver is hidden inside the current vehicle interiors.

Voices are enabled by default. Click the game canvas once to allow browser audio, walk close to a resident and press E. Use the **Voices on** toggle to mute speech. Conversations are scripted, not open-ended voice chat; lips are not separately animated.

### Run in Godot

1. Install Godot 4.4.1 or a newer compatible Godot 4 editor.
2. Download or clone the repository, then import `project.godot`.
3. Wait for assets to import and press F5. The character appears in the courtyard without a menu.

The Compatibility renderer reduces GPU requirements. Native rendered city, exterior-house and entered-interior previews are in `screenshots/`. Road markings and ground visuals use batches, distant house meshes are culled and furnished interiors load on first entry. Chromebook performance and phone walking controls still need device work; weapons, police and multiplayer are not implemented.

### Validation

The automated Godot smoke test launches the actual main scene, verifies a visible human standing on the ground, checks all six nearby vehicles, walking and jumping, nearest-vehicle selection, input locking during transitions, active-vehicle acceleration, unoccupied-vehicle isolation, moving-exit prevention and safe exits back to walking. Resident/action checks verify independent movement, paired conversations, timed punch damage, cooldown, facing guard, range limits, shared furniture occupancy, sitting, sleeping and safe waking. City checks verify all 30 junctions are level, all 68 houses register entrances, representative houses open and close correctly, the human can walk indoors, solid walls block passage, and exit restores the outside camera and collisions. The party/dialogue test checks persistent character switching, all four walking/jumping, wheel hit targets, input blocking, deliberate pose action, safe switching out of a car, contextual dialogue selection, fully voiced protagonist response branches, and consequences including apology, threat, following and map directions. A separate life-and-speech test verifies voiced greeting/reply timing, mute, health bars, hit recoil and flash, a fallen body at zero health, action locks, animated waking, recovery protection and gradual sleep healing. Browser export is checked separately. The original Godot Truck Town import is pinned to demo release `4.2-31d1c0c` (commit `31d1c0c1122717b3ad74aeb94255bc38def52747`).

### Asset licenses

- Code and original concept geometry: MIT, see `LICENSE.md`.
- Character and animations: Quaternius CC0, see `player/models/SOURCES.md` and preserved license files.
- New everyday cars: Kenney CC0, see `vehicles/models/SOURCES.md` and `KENNEY-LICENSE.txt`.
- Original trucks: official Godot Truck Town demo, MIT; see `UPSTREAM_README.md`.
- Synthetic dialogue: see `actors/voices/NOTICE.md` and preserved Alba/Joe model cards. Credits are copied beside the browser build.
- New city, houses, road layout, furniture and mini-map: original code and geometry under the repository MIT license.

No Rockstar code, GTA models or restricted Tesla model files are included. Vehicle and character license files are copied alongside the browser export.
