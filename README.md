# Bajinka: Nottingham City

## Milestone 8: Muhammad, four-character wheel and scene dialogue

The game opens directly as **Muhammad**, with a relaxed standing pose. His fitted CC0 body has slimmer proportions, a turquoise short-sleeved shirt, beige trousers and dark trainers based on the supplied full-body references. A generated face albedo projects the supplied facial likeness onto the rigged head. This is a photo-informed stylized 3D likeness; it is not a photogrammetry scan or AAA character sculpt. Press H to fold his arms deliberately; walking or pressing H again relaxes them.

Press C to open a circular four-wedge selector: **Muhammad, Aisha, Musa and Jade**. Click a wedge or press 1–4; Enter confirms the highlighted option, and C/Esc closes the wheel. All four are actual persistent playable bodies, keeping their own position, health and house context. Camera, map and nearby-resident references follow the selected character. Switching from a car first requires a safe stopped exit. B/R3 now changes the driving camera; C is reserved for character selection. Inactive playable characters wait in the world rather than running full autonomous routines.

The game opens into a vehicle courtyard with the animated human standing on foot. The car selection screen is removed. Six vehicles coexist: the gold Aurora concept car, sports sedan, luxury SUV, city van, tow truck and articulated truck. Walk to a vehicle and press E; the nearby vehicle's name appears in the prompt. You can drive, stop, get out and switch to another vehicle. Other vehicles stay parked.

The Aurora is an original Cybercab-inspired game model, with a gold body, dark panoramic canopy, covered wheels and light bars. The other new cars use Kenney's CC0 Car Kit. The trucks retain the functional towing and articulated trailer from the Godot Truck Town demo, with refreshed surface, wheel and light details. The old demonstration hills and terrain are replaced by an original compact city layout: 11 connected streets, 30 level junctions, pavements, crossings, two parks and 68 residential houses. It is a fictional game city, rather than a geographic reconstruction of Nottingham.

Twelve named residents now share the human animation rig. Six use the female base mesh, six the male base mesh; skin tones, clothing, body proportions, eye detail and tied/short hair distinguish them. They walk or jog between the courtyard, park areas, neighbourhood and shops, pause for scripted text conversations, return home and sit or sleep. The navigation map shows important places, the player and their assigned cab without pedestrian dots. These are local state-machine routines. The player and nearby residents now use audible synthetic male/female voice clips, accompanied by text bubbles. Neighbours take turns in conversations, and E gives a voiced player greeting followed by a resident reply. Voices use bundled Ogg audio rather than a live service; there is no generative AI chat or microphone listening. The new dialogue pack contains 190 authored scene/event lines plus the original ten phrases, rendered in both voices. Contexts cover streets, parks, vehicles, homes, injuries, hostility and familiar friends. Every playable character has separate openings and responses in those contexts, plus short lines for entering/exiting cars and houses, sitting, sleeping, waking, switching and Muhammad's folded-arms pose.

Press E near a resident, listen to both short opening lines, then choose a reply with buttons or 1–3. Kind replies improve the NPC's relationship; apologies stop a fight, threats provoke defensive behaviour, invitations make the NPC walk nearby for 20 seconds, and directions add a blue park marker. G/Esc ends a conversation. NPCs remember a separate relationship with each protagonist during the current session. Dialogue is bounded and authored for the implemented situations, not unlimited generated conversations. Named destinations and the sidewalk graph are ready for a future bus/taxi system; public transport and autonomous cabs are implemented below.

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

## Living transport and parks

The traffic fleet now reuses the detailed original car meshes (48 sports sedans, SUVs, vans and Aurora concepts) with varied paint and rolling wheels. Twelve double-deckers run four continuous route loops: 60, 61, 44 and fictional C1 City Link. There are local shelters between every pair of grid crossings, destination displays, waiting passengers, boarding/alighting animations, signal-controlled approaches and door interlocks. Press **M** for the route guide, and **E** to board an open bus or request/alight at a stop. Routes and Nottingham road/place names are compressed onto the game map; this is not a surveyed reproduction of the real network.

There are 32 fully rigged local residents, plus lightweight waiting, boarding and bus-passenger crowds. Both parks have football with goals/scoring, moving swings, a slide, healing benches and a timed lap. Use **E** near an activity and **G** to finish. Transport references, asset licenses, controls and known scope are documented in [`transport/SOURCES.md`](transport/SOURCES.md).

## Autonomous public services and city finances

Press **P** (or the Phone button) to open Aurora bookings, housing, jobs and the public accounts. Each of the four playable characters and every resident has a separate wallet in integer pence. Council income/spending and recent transactions are visible in the phone. This is a local single-player economy, not a shared online administrator or multiplayer server.

- **Aurora:** six driverless cars dispatch from a booking queue. Search the destination by house number, road, park or bus stop. Pickup uses your current location projected to a safe road pickup. The quoted fare is £3 plus 3p per game metre. A private two-digit code unlocks only your booked vehicle beside its door. Three failed attempts lock entry for ten seconds. Butterfly door panels animate before departure. Fare is held when boarding and credited to the council at completion; an unfinished paid ride is refunded on reload. No GPS device or real-money payment is used.
- **Public buses:** no human drivers. Commuters queue, pay £2, move into their bus and alight at an assigned stop. Buses show route/terminal/next-stop text, wait 15 seconds normally (maximum 60), close doors before moving and reserve city-terminus departures at least 90 seconds apart. They stage off service when awaiting their departure slot. Traffic can delay service; this is not a guarantee of exact 90-second arrivals at every stop.
- **Housing:** permanent global house numbers are allocated from a saved increasing counter and never recycled. All homes are council-owned; vacant signs display £400/month. First-month rent is required before a tenancy is created; a second person cannot rent an occupied home. Players can enter their rented home. Monthly charges either collect available funds or create arrears. Rent officers visit arrears assignments and record paid/unpaid notices.
- **Work and wealth:** cleaners, rent officers, transport technicians, shop workers and business owners have wages and routines. Apply at the council office and spend 20 seconds at your assignment for one wage per game day. Public wages come from council funds; private wages come from a seeded business fund. Wealthy residents start with larger balances and can continue earning. Interest-free council loans up to £1,000 must be repaid before taking another.
- **Time and saving:** one game day is five real minutes and rent is due every 30 game days. Financial state, tenancies, house IDs and debts save locally. Character positions and live traffic trips are not resumed across reloads. Clearing browser storage removes the local city save.
- **Cars/performance:** street cars can be stopped and entered with E; their physical model is created when claimed. Their AI traffic slot is then removed so no duplicate ghost car keeps driving. Rounded original road-car geometry replaces the previous toy-like imported traffic shells; original imported assets/licenses remain in the repository. Dense traffic-light spheres were reduced, static house panels merged with collisions preserved, distant skeletal animation culled, traffic queries stepped at 20Hz, and shadows made opt-in. The 1280×800 stationary courtyard software-renderer check fell from roughly 354 ms / 6,883 draw calls to 112 ms / 1,639 draw calls before the final door additions. Actual device performance varies.

The council account and service modules are foundations for later authenticated admin controls. There is no human bus driver to remove or autonomous-service driving takeover in this version. Vehicles remain stylised original models rather than exact manufacturer replicas.

## Transport and camera refinements

- **B** or the on-screen **Change camera** button changes walking/riding views (chase, close, wide) and driving views (chase, interior, overhead). Chase views return behind the character or vehicle after manual right-mouse orbit. Existing InputMap actions remain available for a future controller layout; laptop hints show keyboard controls.
- **Aurora:** two cars are reserved for playable-character bookings. Active bookings show their assigned cab, distance and pickup marker. Cancel an unstarted booking, or rebook after a blocked pickup expires without a fare. Stale assignments are reconciled. PINs use two digits, including leading zeroes. After boarding doors close, **J** or **Skip journey** on the phone completes the existing fare once and drops you at the destination; leave it running to watch the ride.
- **Aurora conversation:** phone buttons offer traffic, places, help and quiet mode. Three authored personalities have different British-voiced welcome, answer and arrival scenarios. They use offline synthetic en_GB Alba speech; this is bounded authored dialogue, not an online language model.
- **Buses and streets:** long route segments have additional local stops; every stop centre is at least 18 metres from all grid junction centres, keeping a full bus outside the crossing. Three commuters begin at each stop, pay fares, sit with articulated knees at window height and alight. Normal dwell is eight seconds, extending for boarding up to the existing 60-second maximum. Both directions get four seconds of green in a balanced nine-second game cycle, including amber/clearance intervals; the maximum signal-only wait is five seconds. Conflicting greens are never allowed. Swept oriented-vehicle clearance includes crossing, turning and player vehicles. Connected outer distributor roads replace abrupt street ends; pavements, curb edges and road markings join the grid.
- **Housing:** choose a listed house to mark its entrance, walk there or book Aurora from Housing, and confirm the tenancy within three metres of its front door. E at a vacant home's door opens its rent offer. Selecting directions never spends money.
- **Parks and sound:** recreation paths, flower beds, gates, bins and park lighting surround the playable football pitch, swings, slide, benches and timed lap. Original quiet spatial engine/motor, bus, door, punch and football sounds play locally. Speech is British; voice credits and generators are retained.

`tests/refinements.gd` checks stop clearance against every junction, cross-traffic separation, reserved player cabs, stale booking recovery, leading-zero PINs, a single fare across skipping, authored cab replies and the rear-follow camera. The existing seven gameplay suites also run in CI.

## Traffic flow and on-board recitation

Aurora uses directed entry/exit lanes and continuous junction arcs. Dispatch compares legal driving distance rather than straight-line distance; it does not choose a nearby cab facing the wrong direction when a closer legal pickup is available. Pickup and drop-off points remain outside intersections. Pedestrians yield before entering a green traffic lane, cross briskly and move onto the pavement for automatic conversations.

A player or NPC must pay the £2 bus fare before boarding. A missing payment service refuses boarding; it never enables free rides. Each of twelve buses starts on a different complete short surah (103–114) recited by **Sheikh Abdulrahman Al-Sudais**. Only the controlled passenger's bus can be heard. One local audio player prevents overlapping surahs, advances on completion, and stops immediately on exit. The on-board panel has **Quran on/off (U)** and **Next surah**; the on/off preference saves locally. Recordings are packaged with the game, so no streaming connection is needed. Provenance: [`transport/recitations/NOTICE.md`](transport/recitations/NOTICE.md).

`tests/traffic_and_audio.gd` checks every signal-arrival phase, non-reversing road paths, insufficient-funds and exact-fare boarding, no free fallback, twelve bus starting surahs, mute/resume, track replacement and immediate silence outside the bus.

A junction admits vehicles from outside its stop line only after the committed vehicle has cleared the crossing. This prevents a right-turning bus and an opposing car trapping each other. Initial traffic and buses spawn outside these junction boxes. Arrived pickup cabs wait at clear curb spaces during PIN entry, so they leave the running lane open. Completed/cancelled cabs also choose clear curb spaces instead of stacking at a shared destination. `tests/live_service_flow.gd` additionally completes a real player pickup, two-digit PIN boarding and full Gedling road journey with the ordinary traffic, buses, pedestrians and NPC cab service active, and verifies the single settled fare. Ten gameplay suites now run in CI.


### Named Aurora pickups and destination selection

Open **P**, enter a passenger name, then choose a destination or book a pickup first. Each service cab has a permanent **AR-001–AR-006** number above its roof, fixed Aurora Self Drive branding, and a side display showing its reserved passenger. Match the number in your phone and walk into that cab’s green door circle. Enter the two-digit code: the quoted fare is deducted once, the doors open, your visible character walks in and sits, and the doors close before departure. The PIN controls and ground marker disappear after authentication.

A pickup without a destination takes a **£3 boarding payment** and stays parked. Choose a place in the phone or press **N** to open the map and click a registered address, stop, park or map pin. Confirm the destination and remaining fare to depart. Insufficient funds leave the cab parked; leaving before choosing a destination refunds the unused boarding payment. The purple map line follows the actual remaining road route. **J** still completes a confirmed moving journey for its existing fare.

The service Aurora now has an original open cabin, individual seats, transparent glass, separately hinged butterfly doors and smoothed visual steering. City sounds have more audible nearby engines, footsteps and vehicle-impact effects, with a City Sound switch in the phone. Moving vehicles can knock pedestrians down; they play a fall/get-up sequence and regain control. Residents periodically pause for conversations and occasional pavement disagreements. This remains an offline single-player simulation.
