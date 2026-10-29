Phone play is available directly in the browser game. Phones get a left movement/steering stick, right action buttons and pedals, and Phone, Map, People, Camera and Full shortcuts. Drag the clear game screen to look around. The layout follows portrait/landscape rotation, respects phone safe areas and keeps the centre clear. Menus use readable scrolling pages and touch-sized buttons. Desktop keyboard/gamepad and the separate phone controller remain available.

# Bajinka: Nottingham City

### Surface Robotics Plaza

**Robotics Plaza** is a 150 × 110 metre open-air civic space north of the city centre. Find **F** on the map or select Robotics Plaza as a travel destination; the marker leads to its public entrance. Walk in from either of the surrounding roads. Both physical gates slide open automatically, remain open for people in the approach, and reverse safely if somebody arrives while closing. **E / Triangle** beside the entrance directory explains the site.

The first phase includes a demonstration court, landscaped gardens, seating canopies, two reserved robot docks and a marked future vehicle/machinery workshop pad. Robots and repair work belong to later phases. The plaza stays at ordinary ground level, with no underground space. It streams independently of houses, builds one nearby detail group per update and releases scenery when visitors leave. Existing house numbers and positions are preserved.

### Aurora Robovan fleet

Ten six-seat Robovans and eight Aurora cars form the eighteen-vehicle road fleet. Six additional Robovans are spread across all six neighbourhood ranks. Look for the **RV-** fleet number and **ROBOVAN SELF DRIVE** roof sign. The original silver shuttle has smooth curved body panels, inset transparent cabin windows, individual seats and sliding passenger doors. Its wider, longer collision footprint is used for traffic gaps and curb approaches.

- **Book → Call Robovan:** one tap requests pickup here. Choose a destination now or after boarding. Press **E / Triangle** beside the assigned vehicle; the fare or saved city pass is checked once at entry. Road fares match Aurora (£3 plus 3p per game metre).
- **Rents → Vehicles → Robovan:** choose the shown duration/price; the private van drives to a nearby curb. Boarding and trips during its lease carry no extra passenger fare.
- **Jobs → Robovan driver:** start free, receive a work van, then enter its driver seat. Real resident bookings provide pickup and destination routes. Actual fares pay 70% to the worker and 30% to the council; manual and self-drive modes remain available.
- Both the phone controller wheel and Aurora/Robovan cabin wheel turn with steering input. [Download the Android controller APK](https://github.com/cyberokasha-dev/nottingham-city-phone-controller/releases/latest/download/Nottingham-City-Controller.apk), or [use the web controller](https://cyberokasha-dev.github.io/nottingham-city-phone-controller/). The phone wheel recentres on release, cancellation, menus or lost focus; changing camera preserves held driving inputs.


## Council rentals, jobs and city phone

The starting motor courtyard is now the **Council Vehicle Rentals depot**. Its former six free cars are removed; the depot and rental showroom share the same plot. Press **P** for the nine-icon City Phone: **Book, Rents, Jobs, Wallet, Passes, Map, Council, Settings, Account**. Keyboard arrows, gamepad directions, the phone controller and the on-screen cursor select the same game controls. Search results are limited to eight; detailed pages scroll.

- **Door entry:** press **Triangle / E** beside a public bus, train, Aurora or helicopter. The default action is **passenger boarding**, not a form. A valid day/month pass is accepted automatically; otherwise the single fare is checked and collected. Insufficient funds refuse entry. Cabs and flights can choose their destination after boarding.
- **Rents:** private hire only. Choose the vehicle, then press **Rent 1 hour** or **Rent 7 days** with the exact price displayed. **Aurora, private bus and helicopter travel to a safe pickup near you**, with a moving marker and approach route on the map. These rentals never create a public job or pick up public passengers. An Aurora/helicopter renter uses the reserved vehicle without a second passenger charge. Other road vehicles collect at the depot. Existing leases remain valid; no duplicate charge. Choose a home then **Rent this home • £400/month**, or rent directly from its door. Each counter and phone page handles its own purpose.
- **Jobs:** the council supplies public transport work **without a rental fee**. Choose the service, then **Confirm**. Aurora/helicopter work vehicles come to you. For buses, go to **any bus stop** and confirm there; that becomes your starting stop. Wait for the matching service and press **Triangle / E** to take its driver seat. Trains work the same way from a station. Only an explicitly confirmed job changes door entry into driver takeover. A visible **departure countdown** runs at stops, followed by **Time to move**. Toggle **Self-drive** in Jobs while remaining aboard; the same contract continues earning its 70% share of completed paid trips, with 30% supporting the shared city council.
- **Lighter city:** the full 1.48 km city footprint, roads, parks, shops and railway remain. The default has **41 homes instead of 253**. Homes with saved tenants are retained in their original places, even outside this default set. The default loaded starting scene measured about **4,400 nodes** in the headless city check. The fleet remains 24 ambient cars, 12 Auroras, 8 buses, 8 helicopters and 4 ground trains while keeping the lower rendering budget.
- **Road delivery work:** sports cars, SUVs, vans, tow trucks and articulated trucks can all use an existing rental for supermarket delivery work. Collect at the depot, drive to the marked supermarket, stop and press **E**. Each completed £20 delivery pays **£14 to the operator and £6 to the council**, funded by the shop budget. Transport work likewise pays **70% to the operator and 30% to the council** only for completed paid trips. Saved receipt IDs and reset delivery tasks prevent duplicate payouts; own characters cannot pay themselves. Work runs while the city is open, with no offline income.
- **Book:** select Aurora or helicopter with one button. The active character's name is automatic. Pick a destination from the map, search a house/street/place, or choose it after boarding. Existing arrival, boarding, cancellation and refund checks remain in place.
- **Passes:** press E at an arrived train to choose a **£4 single trip**, **£25 / 24 real hours**, or **£120 / 30 real days**. A valid day/month pass covers buses, trains, Aurora and helicopters. Payment is checked before boarding; an active pass cannot be bought twice. Upgrading a day pass to a month costs the displayed full month price. A train that has departed cannot be boarded remotely; a purchased pass stays saved.
- **Workers:** each civic site reuses one existing resident. Rental staff open vehicle rentals; the council handles housing, council work and accounts; supermarket staff offer work at their own shop; racing staff mark the circuit start. Reserved retail plots clearly state that they are not open. Larger labels and buttons work with keyboard, controller and the game-screen cursor. Wallet contains balances and transactions.
- **One private city code:** Account can reveal the sixteen-character credential. Passes use this identity, and a controller can pair with it after Phone controller is enabled; the public QR panel shows only a temporary six-character code. Account-code pairing verifies an HMAC challenge and never puts the private code in a QR URL. Character wallets, tenancies, rentals and jobs belong to this city save. **Cross-browser cloud recovery is prepared but not active until the dedicated account project is connected**; the Account app states this explicitly. See `supabase/README.md`. Purchases and the identity are saved locally, including an immediate browser checkpoint.

The older milestone notes below describe the project's history; these rental, phone and account rules supersede earlier free-car and large-form flows.

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

Use the mini-map at the bottom left to find roads, houses and the parked fleet; the yellow marker is the player. Walk up to a house entrance and press E to open the door and enter. Interiors contain a living area, kitchen, bed and furniture with collision. Walk back toward the front door and press E to leave. A cutaway roof and elevated camera keep the human visible indoors. Every home has its own address and entrance; homes share the initial floor plan.

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

- **Aurora:** twelve driverless cars dispatch from a booking queue. Search the destination by house number, road, park or bus stop. Pickup uses your current location projected to a safe road pickup. The quoted fare is £3 plus 3p per game metre. A private two-digit code unlocks only your booked vehicle beside its door. Three failed attempts lock entry for ten seconds. Butterfly door panels animate before departure. Fare is held when boarding and credited to the council at completion; an unfinished paid ride is refunded on reload. No GPS device or real-money payment is used.
- **Public buses:** no human drivers. Commuters queue, pay £2, move into their bus and alight at an assigned stop. Buses show route/terminal/next-stop text, wait eight seconds normally (maximum 60), close doors before moving and reserve city-terminus departures at least 90 seconds apart. They stage off service when awaiting their departure slot. Traffic can delay service; this is not a guarantee of exact 90-second arrivals at every stop.
- **Housing:** permanent global house numbers are allocated from a saved increasing counter and never recycled. All homes are council-owned; vacant signs display £400/month. First-month rent is required before a tenancy is created; a second person cannot rent an occupied home. Players can enter their rented home. Monthly charges either collect available funds or create arrears. Rent officers visit arrears assignments and record paid/unpaid notices.
- **Work and wealth:** cleaners, rent officers, transport technicians, shop workers and business owners have wages and routines. Apply at the council office and spend 20 seconds at your assignment for one wage per game day. Public wages come from council funds; private wages come from a seeded business fund. Wealthy residents start with larger balances and can continue earning. Interest-free council loans up to £1,000 must be repaid before taking another.
- **Time and saving:** one game day is five real minutes and rent is due every 30 game days. Financial state, tenancies, house IDs and debts save locally. Character positions and live traffic trips are not resumed across reloads. Clearing browser storage removes the local city save.
- **Cars/performance:** street cars can be stopped and entered with E; their physical model is created when claimed. Their AI traffic slot is then removed so no duplicate ghost car keeps driving. Rounded original road-car geometry replaces the previous toy-like imported traffic shells; original imported assets/licenses remain in the repository. Dense traffic-light spheres were reduced, static house panels merged with collisions preserved, distant skeletal animation culled, traffic queries stepped at 20Hz, and shadows made opt-in. The 1280×800 stationary courtyard software-renderer check fell from roughly 354 ms / 6,883 draw calls to 112 ms / 1,639 draw calls before the final door additions. Actual device performance varies.

The council account and service modules are foundations for later authenticated admin controls. There is no human bus driver to remove or autonomous-service driving takeover in this version. Vehicles remain stylised original models rather than exact manufacturer replicas.

## Transport and camera refinements

- **B** or the on-screen **Change camera** button changes walking/riding views (chase, close, wide) and driving views (chase, interior, overhead). Chase views return behind the character or vehicle after manual right-mouse orbit. Existing InputMap actions remain available for a future controller layout; laptop hints show keyboard controls.
- **Aurora:** two cars are reserved for playable-character bookings. Active bookings show their assigned cab, distance and pickup marker. Cancel an unstarted booking, or rebook after a blocked pickup expires without a fare. Stale assignments are reconciled. PINs use two digits, including leading zeroes. After boarding doors close, **J** or **Skip journey** on the phone completes the existing fare once and drops you at the destination; leave it running to watch the ride.
- **Aurora conversation:** phone buttons offer traffic, places, help and quiet mode. Three authored personalities have different British-voiced welcome, answer and arrival scenarios. They use offline synthetic en_GB Alba speech; this is bounded authored dialogue, not an online language model.
- **Buses and streets:** long route segments have additional local stops; every stop centre is at least 18 metres from all grid junction centres, keeping a full bus outside the crossing. Four to six commuters begin at each stop, pay fares, sit with articulated knees at window height and alight. Normal dwell is eight seconds, extending for boarding up to the existing 60-second maximum. Both directions get four seconds of green in a balanced nine-second game cycle, including amber/clearance intervals; the maximum signal-only wait is five seconds. Conflicting greens are never allowed. Swept oriented-vehicle clearance includes crossing, turning and player vehicles. Connected outer distributor roads replace abrupt street ends; pavements, curb edges and road markings join the grid.
- **Housing:** choose a listed house to mark its entrance, walk there or book Aurora from Housing, and confirm the tenancy within three metres of its front door. E at a vacant home's door opens its rent offer. Selecting directions never spends money.
- **Parks and sound:** recreation paths, flower beds, gates, bins and park lighting surround the playable football pitch, swings, slide, benches and timed lap. Original quiet spatial engine/motor, bus, door, punch and football sounds play locally. Speech is British; voice credits and generators are retained.

`tests/refinements.gd` checks stop clearance against every junction, cross-traffic separation, reserved player cabs, stale booking recovery, leading-zero PINs, a single fare across skipping, authored cab replies and the rear-follow camera. The existing seven gameplay suites also run in CI.

## Traffic flow and on-board recitation

Aurora uses directed entry/exit lanes and continuous junction arcs. Dispatch compares legal driving distance rather than straight-line distance; it does not choose a nearby cab facing the wrong direction when a closer legal pickup is available. Pickup and drop-off points remain outside intersections. Pedestrians yield before entering a green traffic lane, cross briskly and move onto the pavement for automatic conversations.

A player or NPC must pay the £2 bus fare before boarding. A missing payment service refuses boarding; it never enables free rides. Each of twelve buses starts on a different complete short surah (103–114) recited by **Sheikh Abdulrahman Al-Sudais**. Only the controlled passenger's bus can be heard. One local audio player prevents overlapping surahs, advances on completion, and stops immediately on exit. The on-board panel has **Quran on/off (U)** and **Next surah**; the on/off preference saves locally. Recordings are packaged with the game, so no streaming connection is needed. Provenance: [`transport/recitations/NOTICE.md`](transport/recitations/NOTICE.md).

`tests/traffic_and_audio.gd` checks every signal-arrival phase, non-reversing road paths, insufficient-funds and exact-fare boarding, no free fallback, twelve bus starting surahs, mute/resume, track replacement and immediate silence outside the bus.

Turning or uncertain vehicle paths keep exclusive junction clearance; known straight-moving queues can share their green across separate lanes. This prevents a right-turning bus and an opposing car trapping each other. Initial traffic and buses spawn outside these junction boxes. Arrived pickup cabs wait at clear curb spaces during PIN entry, so they leave the running lane open. Completed/cancelled cabs also choose clear curb spaces instead of stacking at a shared destination. `tests/live_service_flow.gd` additionally completes a real player pickup, two-digit PIN boarding and full Gedling road journey with the ordinary traffic, buses, pedestrians and NPC cab service active, and verifies the single settled fare. The CI workflow also verifies named pickups, destination-later journeys, districts, rank reservations, same-green traffic queues and populated buses.


### Named Aurora pickups and destination selection

Open **P**, enter a passenger name, then choose a destination or book a pickup first. Each service cab has a permanent **AR-001–AR-012** number above its roof, fixed Aurora Self Drive branding, and a side display showing its reserved passenger. Match the number in your phone and walk into that cab’s green door circle. Enter the two-digit code: the quoted fare is deducted once, the doors open, your visible character walks in and sits, and the doors close before departure. The PIN controls and ground marker disappear after authentication.

A pickup without a destination takes a **£3 boarding payment** and stays parked. Choose a place in the phone or press **N** to open the map and click a registered address, stop, park or map pin. Confirm the destination and remaining fare to depart. Insufficient funds leave the cab parked; leaving before choosing a destination refunds the unused boarding payment. The purple map line follows the actual remaining road route. **J** still completes a confirmed moving journey for its existing fare.

The service Aurora now has an original open cabin, individual seats, transparent glass, separately hinged butterfly doors and smoothed visual steering. City sounds have more audible nearby engines, footsteps and vehicle-impact effects, with a City Sound switch in the phone. Moving vehicles can knock pedestrians down; they play a fall/get-up sequence and regain control. Residents periodically pause for conversations and occasional pavement disagreements. This remains an offline single-player simulation.


### Districts, ranks and the city atlas

The whole compact game city has a shared atlas: **City Centre, Forest Fields, Mapperley, Gedling, Lenton and Carlton**. These are compressed fictional neighbourhoods inspired by Nottingham, not surveyed real-world boundaries. All 68 existing house identities and rental records remain stable. Named streets, corrected front-door addresses and district-specific terraces, Victorian bays, villas, cottages, semi-detached homes and modern/parapet homes make the streets easier to recognise.

**N** opens the city map; scroll or use **+/−** to zoom and right-drag to pan. It shows streets, house footprints/numbers when zoomed in, parks, home, council office, stops and gold **A** rank icons. Click a waypoint and choose walking directions or an Aurora destination. The local radar follows and rotates with the player's camera, while the full atlas remains north-up. Blue is the walking route; purple is the assigned cab's remaining lane route.

Each neighbourhood has a signed two-space Aurora rank. **E** beside an available parked Aurora reserves that exact numbered cab; stand in its green door circle and use your booking PIN. **K**, or **Aurora come to me**, requests a safe nearby road pickup without choosing a destination. Empty service cabs return to their assigned neighbourhood rank and can accept a booking while returning. Occupied cabs retain their passenger's booking.

Twelve buses start in service with 12–18 real fare-paying passengers. NPC seats remain unique after people get off; a separate seat is reserved for the playable character. The £2 fare is still mandatory. The player now visibly walks through the open door, sits, and holds departure until boarding finishes. Passengers use shared-material cabin batches and distance culling to limit rendering cost. Queues replenish from alighting passengers and ordinary commuter wages.


Traffic recovery now also uses oriented vehicle space at street-edge re-entry. Opposite cars cannot permanently block each other merely because adjacent lanes are less than nine metres apart. Regression checks cover a three-car queue clearing the same green, protected turns, clear opposing re-entry lanes, and occupied-lane overlap prevention.


Curb departures now follow a forward merge curve and keep the parked heading while yielding. Nearby pickups use a clear curb space without an unnecessary road loop. `tests/city_service_continuity.gd` exercises six simulated minutes of the populated city and requires every one of the twelve buses to continue serving stops; district tests cover walk-up/hail, address selection, seat ownership and the traffic deadlock regressions.


### Frame-time improvements

The phone (**P**) now offers **Smooth**, **Balanced** and **Sharp** graphics and an optional FPS counter. Smooth is the default: 75% 3D resolution and no multisample antialiasing; text and phone controls keep their native resolution. Balanced restores full resolution with 2× antialiasing; Sharp uses 4×. The choice saves locally.

Traffic shares a 16-metre spatial index instead of rebuilding and scanning the whole fleet for every clearance query. Moving buses and Aurora cars update their cells immediately; lane-following uses lane rosters. The city atlas is painted once into a reusable texture. Physics runs at 60 Hz instead of 120 Hz, distant/off-camera residents stop skeletal animation, and seated commuters and silent speech controllers suspend idle callbacks. Fares, rent and wages still update immediately; multiple save requests are coalesced into one disk write after at most one second of processing, with a flush on desktop close.

Controlled checks against commit `374ac76` used the same seeded city and fixed 60-frame simulation step. Headless median wall frame time fell from **10.733 ms to 4.196–4.499 ms** across two optimized runs (about 58–61%). P95 varied from 22.168 to 26.220 ms against a 25.593 ms baseline, so this does not establish a consistent improvement in the slowest frames. A separate 90-frame software OpenGL rendering check fell from **233.527 ms to 113.217 ms** median, with the new default Smooth settings. This latter comparison includes the quality change; it is not a prediction of browser FPS on a player's laptop. Both runs use the same populated city.

Reproduce CPU measurements with `godot --headless --path . --fixed-fps 60 --script res://tools/benchmark_city.gd`; omit `--headless` for rendering. Close other heavy programs and compare identical camera, resolution and settings. `tests/performance_budget.gd` checks 400 indexed/reference traffic queries for identical results, same-frame index updates, cached atlas reuse, quality presets and on-demand passenger animation. That test is part of the browser-build workflow.


### Character variety, quieter voices and passenger bodies

Muhammad and Musa now use a British male voice; Aisha and Jade use a new British female voice. Resident assignments follow their character identities. Most residents stay quiet unless approached; only eight volunteer ambient dialogue, with a long pause between lines. Ordinary player actions no longer trigger continuous narration. Fighting uses impact effects instead of saying “Blocked”. Voice attribution and licences are in `actors/voices/NOTICE.md`.

Male/female meshes have tailored body contours. Different heights, builds, clothes, trousers, shoes, sleeve styles and selected glasses, facial hair and hairstyles distinguish residents and all four protagonists. Some residents check a held phone, stretch, watch the street, pause at work or rest between journeys, alongside existing jobs, home visits and sleep. Interactions and combat interrupt these activities.

Visible drivers and passengers attach to their vehicle cabin and use a settled seated pose, with fitted seat anchors and bent legs. Aurora occupants follow the same smoothed rendered cabin, preventing relative shake when the car turns or moves. Exiting restores their walking body. Bus commuters walk through open doors, follow the aisle and rear staircase to upper-deck seats, then sit; alighting reverses the cabin path and uses the middle door. Buses hold departure until transfers finish and stop admitting new commuters early enough to finish within the normal one-minute dwell limit. Shared cabin batches and suspended seated callbacks are retained.

`tests/character_quality.gd` checks male/female British banks, distinct protagonist appearances, quieter residents, routines, attached occupants while turning, Aurora foot clearance, restored bodies on exit, visible bus paths and the departure interlock. All fifteen gameplay/regression suites run before publishing.


### Skylink helicopters and simpler travel

The Travel tab (**P**) offers **Helicopter** or **Aurora cab**. Choose a destination from the existing address/stop/park list or map, then **Call to me**. You may also choose the destination after boarding. Passenger names default to the selected character; match the assigned **HL-001–HL-012** or **AR-001–AR-006** number. **K** calls the selected transport. Aurora service cars are reduced from twelve to **six**, one per district rank. Ordinary street traffic and buses are unchanged.

Walk beside the assigned parked vehicle and press **E** to open its form, then **Board and go**. Press E beside an available parked helicopter or Aurora to reserve that exact vehicle first. Neither a PIN nor standing on a particular green ring is required in this flow. An approaching or airborne vehicle cannot be boarded remotely. Active bookings prevent reserving both services together. The simpler screen only shows actions relevant to the current ride.

Twelve original Skylink helicopters have glass cabins, visible seats, skids, animated sliding doors, main/tail rotors, individual numbers and a quiet original rotor loop. The autonomous flight climbs vertically, cruises directly above buildings and road traffic, then descends to reserved clear ground. Aircraft use different cruise heights. Landing selection excludes roads, houses, playgrounds, the vehicle courtyard and other aircraft landing reservations. The map shows helipads, the assigned helicopter, actual flight path and pickup. A house destination means a safe nearby landing followed by a short walk, rather than landing through the building.

Helicopter fares are **£5 plus 4p per horizontal game metre**. Boarding without a destination holds £5 and waits on the ground; confirming a destination adjusts that payment. A completed or skipped journey settles the existing fare once to the council. Leaving before confirming a destination refunds the unused payment; unpaid pickups can be cancelled. Public flights periodically carry visible fare-paying commuter models; two aircraft are reserved from these ambient flights for player bookings. The system is an offline game simulation, not real aviation software.

`tests/air_taxis.gd` covers both booking flows, actual takeoff/cross-city landing, visible cabin attachment, landing exclusions/reservations, fare settlement, destination-later refunds, optional skipping, remote-boarding refusal and simplified road-cab boarding. All sixteen suites run before publishing.


City startup and rendering now use lighter resident geometry and staged house detail. All 68 addresses, rentals, doors and collision walls are available immediately. Distant homes retain their roof shape, colours, windows and door; full facade detail is built near the camera, at most one house per frame, and on demand before entry. Interiors remain loaded on first use. Seated and standing commuters share immutable pose meshes; articulated walking rigs exist only while moving. Road-car wheels share their geometry and headlights reuse materials.

A native Compatibility-renderer comparison on the development machine reduced startup nodes from 17,144 to 8,474 and starting-view draw calls from 1,763 to about 1,320. Startup timings varied between runs (one comparison was 3.19 s before and 1.81 s after). This used software OpenGL and is a workload comparison, not a target-device FPS guarantee; rendered frame time did not show a consistent gain before adaptive resolution was added. `tests/performance_budget.gd` checks scene size, deferred facades, immediate entry/cutaway behavior, shared commuter meshes and rig release alongside the existing traffic-index and map-cache checks.

Smooth graphics also adapts only the 3D render scale between 55% and 75% after a startup warmup, stepping down below 28 FPS and recovering above 48 FPS. UI text and the map retain their normal resolution, and physics, money and transport timing remain unchanged. Balanced and Sharp keep their selected fixed resolution. The FPS display includes the current 3D scale.


### Compact circular city and ground-level City Circle

The city now occupies a **1.48 km diameter circle**, replacing the former 3 km square. Six nearby districts contain **253 streamed homes**, with distinct district architecture. The original six custom driveable vehicles remain at the starting courtyard, widened into the **Council Motor Quarter**. A separate council Aurora and bus showroom is immediately south of it. Two supermarkets and two explicitly reserved gun-shop plots are marked on the map and selectable in the phone. These are retail/showroom sites; weapon trading, supermarket checkout and vehicle purchase ownership are not implemented by this layout change.

The **Council Racing Ground**, west of Lenton, has an open oval driving circuit and eight numbered checkpoints. Drive a vehicle through checkpoint 1, then the other checkpoints in order; completing a lap displays its time and the session best. Ten playable parks (two core parks plus eight streamed parks) fill nearby recreation sites. Reserved civic plots remain clear of housing, procedural frontages and helicopter landings even while unloaded.

Routes **60, 61, 44 and C1** now run compact **1.7–2.5 km bus loops**, with five surveyed stops each, eight buses, visible paying passengers and the existing £2 fare. Stops remain outside junction approaches. Thirteen selected junctions retain the five-second maximum signal-only wait. **Twelve uniquely numbered Auroras**, two per neighbourhood rank, share the same lanes and streamlined booking flow.

**RailLink R1 City Circle** replaces both elevated lines and their bridge supports. Four trains run in opposite directions on separate tracks around one continuous ground-level loop. Six stations—Central, Lenton, Forest Fields, Mapperley, Gedling and Carlton—are about 690 m apart. Acceleration and braking still determine speed over real distance, up to the existing 360 km/h limit; ordinary station dwell is now 30 seconds. Press E at a station entrance to pay £4 or use a valid travel pass, walk aboard and sit. Platforms, road-vehicle bays and short level access paths sit on the ground. The railway stays outside the public road grid, avoiding uncontrolled rail/road crossings. Each station has a separate nearby helicopter pad.

The eight low-flying Skylink helicopters retain booking, selectable flight height and speed controls. All sixteen helipad destinations remain selectable. Homes, station/train models, road tiles and civic sites stream nearby under frame budgets: shrinking the map does not construct the whole city. The starting-area check measured about **6,000 nodes with 61 homes active**, under the 7,200-node budget. This is a scene-workload measurement, not a guarantee of FPS on a particular device.

Existing wallets and travel passes are retained. If an old save rented a retired outer-city home, its tenant moves to an available compact-city home without another charge, preserving agreed rent, due date and arrears. If none is available, the old rent is refunded. Retired house numbers remain recorded and are never reassigned.

These are compressed Nottingham-inspired fictional places and routes, rather than a surveyed city or current NCT timetable. Automated checks cover ground-rail continuity in both directions, all station cab approaches, every district connection, fares, saved tenants, civic landing exclusions, timed circuit laps and streaming budgets before publication.

### Lighter city population and loaded-scene budget

The default city now has **16 named residents**, **24 ambient road cars**, **8 buses** (two on each of the four routes), **8 helicopters** and twelve district Aurora cabs. Buses start with 8–12 paying public passengers, and stop queues start with 3–4. All sixteen helipad destinations and the full address atlas remain available. Existing saved balances, numbered homes and rental records are retained.

Beyond 180 metres, ordinary resident sidewalk journeys use four coarse updates per second and avoid opening unloaded interiors. Coming closer restores normal collision and full movement; combat, injury, active conversations, boarding and indoor activities retain their normal processing. Nearby interactions use local address cells instead of scanning every house. Normal walking, fares, boarding, character switching and phone-controller input retain their existing controls.

The status and health display remain on screen. Press the **Controls** button to expand the full touch buttons, keyboard/gamepad help and voice switch. Normal prompts are shorter and are assigned once after composition, avoiding repeated text layout within each physics tick. Shared coloured house shells use one mesh each; facade sections and level station approaches are combined while retaining doors, cutaways and real collision. Ground-level rail ballast is grouped into tile batches, and the route itself retains its full sampled curve. The traffic update now uses the same lane coordinates as its planning and clearance logic.

Helipad/station-pad data is calculated once per city session instead of hundreds of times during home generation. Road/rail detail keeps a five-by-five region around the player plus travel look-ahead, with two tile builds per frame and a two-millisecond scheduling budget. Individual tile construction is atomic; the time check occurs between builds.

A seeded native Compatibility-renderer comparison, using software OpenGL, the same 1152×648 view and fixed 75% Smooth scale, reduced loaded scene nodes from **10,613 to 6,606** and starting-view drawing calls from **1,079 to 323**. Median rendered frame time changed from **58.743 ms to 49.346 ms**; P95 changed from 68.732 to 55.910 ms. Startup in that pair changed from 4.49 to 1.36 seconds. These are development workload measurements with a deliberately smaller population, not target-device browser FPS. `tools/benchmark_city.gd` now warms the city for 120 frames and holds the graphics scale fixed for repeatable comparisons.

`tests/city_load_budget.gd` checks the scene **after** neighbourhood loading, all actual traffic lane positions, every numbered doorway, reduced fleet sizes, coarse walking progress and restored nearby collision. It supplements the existing startup and gameplay checks; all twenty-two suites run before publication.

### Controller and city HUD

The phone is a gamepad. Phone, Map and Characters open on the game screen, not on the
controller. Use the stick or direction pad, × / Enter to confirm, ○ / Esc to return,
and L1/R1 to switch phone apps or zoom the map. Left/right changes location choices.
A map crosshair selects an actual city address or waypoint, then returns to booking.
Moving the crosshair to the edge pans the map. Names are automatic; call a helicopter
or Aurora directly, with a destination now or after boarding. Existing fare, distance,
boarding and character-switch restrictions still apply.

The minimap and health are bottom left, pounds are top right, and the character
buttons and wheel are bottom right. The pairing button is top left, with FPS below it.
Travel, Housing, Jobs & Money, Council and Settings live in one readable game phone.
Graphics, sound and voice options are in Settings, instead of across the game screen.

Only a small context/mode status packet is sent to the controller at most four times
per second when changed; menu trees, house lists and atlas images stay in the game.
`tests/remote_menu.gd` checks navigation, fast booking, fare checks and HUD placement.
`tools/check_browser_controller.cjs` runs against the actual exported Godot browser
build and exercises the JavaScript bridge, menu commands, helicopter booking and
cancellation, and character switching. Its pairing transport is simulated; physical
phone-to-Chromebook WebRTC still needs a device check.


### Streamed green-space infill, Aurora takeover and 24-hour travel

Unused roadside plots now contain shared, streamed shopping frontages, open market
courtyards, planted gardens and woodland walks. Additional community parks load the
existing playable football, swings, slide, benches and timed park lap nearby. Roads,
junctions, station access, existing houses and helicopter pads remain clear. Infill
uses four shared meshes batched by tile; it adds no background resident or vehicle
population and keeps the existing two-tile streaming budget.

Aurora carries movement through consecutive route points without a dead update at
each point. Acceleration, route-end braking, traffic clearance and corner limits
replace the fixed-speed jumps. The passenger **Travel faster** button raises the
road cruise target from 14 to 21 m/s; traffic and turns still limit actual speed.
During a confirmed journey, **Drive myself** enables W/S acceleration/braking and
A/D steering with static collision, ground following and rail protection. **Switch
to self-drive** rebuilds the route from the current road position. Stop within six
metres of the destination or use Skip journey to finish; the released car resets
to autonomous operation and its normal speed. The steering controls fold away.

Helicopters cruise at 26 m/s normally or 38 m/s with **Travel faster**. Climb and
landing speeds remain lower; flight height is still a separate choice. Both
transport types expose speed controls directly on the game screen and in Travel,
so the paired gamepad can navigate them. The original electric train model now
has bevelled carriage shells, tapered noses, raked cab screens, bogies, livery,
inter-car gangways and sliding doors. Its static meshes are shared when streamed.

**P → Travel → Buy 24-hour pass (£25)** buys one character a six-digit travel code.
The same saved code covers unlimited train, Aurora and helicopter boarding for
24 real hours from purchase, including time outside the game. It is applied
automatically at boarding and shown with its remaining time in the phone. A code
belongs to its character; switching characters does not transfer it. Expiry stops
new free boarding but never adds a charge to an already covered journey. Ordinary
single fares still apply without a valid pass; buses retain their separate £2 fare.

Tickets, purchase debits and expiry save in the existing local city account. The
browser also journals the complete purchase immediately while its ordinary
IndexedDB file sync completes. Reopen the same game in the same browser/profile
or native user-data folder to reuse it. Clearing site data or uninstalling with
save-data removal deletes this local account; there is no cloud ticket service.
`tests/travel_upgrades.gd` verifies a real save reload, all three pass-funded
boarding paths, expiry, manual/automatic switching, actual faster flight speed,
landmark landing exclusions and continuous movement through dense route points.


### Selecting game screens with the controller

The controller now has a **Screen cursor** button. In that mode, the left stick or
centre touchpad moves a visible pointer in the game; Cross or a touchpad tap
selects the real button beneath it. Circle or **Return to play** exits cursor mode.
This also reaches the in-game ride speed and Aurora driving-mode buttons. The
controller sends input only; it does not stream a second copy of the game.

Classic menu navigation is still available: directions move the blue selection,
Cross opens a destination/job/property list, up/down chooses an item, and Cross
confirms. L1/R1 jump ten items in a list, change phone tabs normally, or scroll while
using the screen cursor. Back closes a list before closing its parent menu.
Selecting an editable game field opens a single text box and keyboard on the
controller; only that selected field accepts the submitted text.

Closing a menu releases held controls and waits for a neutral stick/buttons before
resuming movement. Screen mode also blocks keyboard/vehicle input; disconnecting
releases it. The receiver accepts standard connected-gamepad menu buttons as well
as phone-controller input. `tests/screen_controller.gd` exercises actual HUD
buttons, lists, field validation, map selection, moving the character again and
recovery after a lost signal.
