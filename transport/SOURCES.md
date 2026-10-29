# Nottingham traffic, transport and recreation

## Vehicle assets and geometry

Cars reuse the original detailed sports sedan, SUV and van meshes from the CC0 Kenney Car Kit already included in this repository. Aurora uses the existing original Cybercab-inspired procedural model. See `vehicles/models/SOURCES.md` and its retained licenses. Ambient models contain the actual fleet mesh and separate rolling wheels, without duplicating its physical vehicle/audio/camera controllers.

All bus, shelter, crowd and playground geometry in this change is original code under this repository's MIT license. Buses use tapered front/rear profiles, rounded roof shoulders, separate decks, glass, seats, stair treads, mirrors, wheel hubs, a destination display and independently animated passenger door leaves. They are stylized game vehicles, not manufacturer CAD models, official branded assets or dimensionally exact replicas.

## Research checked 14 October 2026

- NCT 60: https://www.nctx.co.uk/services/NCT/60 — City/Queen Street, Woodborough Road, Mapperley, Westdale Lane and Gedling. Sky-blue service inspiration.
- NCT 61: https://www.nctx.co.uk/services/NCT/61 — Nottingham/Parliament Street, Mapperley, Mapperley Plains, Gedling Country Park, Lambley, Woodborough and Calverton. The game selects principal destination names; it does not reproduce every intermediate stop.
- NCT 44: https://www.nctx.co.uk/services/NCT/44 — City to Gedling via Colwick and Netherfield. Red service inspiration.
- NCT fleet: https://www.nctx.co.uk/fleet-list — double-decker fleet proportions and local colour/route identity references.
- Heatherwick Studio, New Routemaster: https://heatherwick.com/project/new-routemaster/ — rounded body corners, stacked windows, multiple entrances and staircase design reference for the red London-inspired City Link vehicle. The game model is a simplified original interpretation with three doorways and a rear staircase, not an exact New Routemaster replica.
- Transport for London: https://tfl.gov.uk/info-for/media/press-releases/2012/february/first-passengers-jump-aboard-the-new-bus-for-london — New Routemaster entrance and passenger circulation context.
- Nottingham City Council, Forest Recreation Ground: https://www.nottinghamcity.gov.uk/ForestRec — sports pitches, recreation and running inspiration.
- Nottingham City Council, Arboretum: https://www.nottinghamcity.gov.uk/leisure-and-culture/parks-and-open-spaces/find-your-local-park/nottingham-arboretum/ — park naming and tree/garden inspiration.

No source photographs, website copy, logos or proprietary models were copied into the game.

## Map and service scope

The current 3 km-square game layout is a compressed Nottingham-inspired fictional city, not an accurate survey, real journey planner or current timetable. Game routes 60, 61, 44 and fictional C1 run four long continuous loops with twenty original shelter placements. Place names and service numbers are inspiration, not a claim to reproduce those real services. RailLink R1 and R2, their five stations, elevated alignments, four trains and fares are original game rules. The four playable parks have fictional activity layouts.

Train and station meshes in `train_model.gd`, `rail.gd` and `region_stream.gd` are original procedural geometry under this repository's MIT licence. The 300 km/h limit is a game design choice; train performance does not model a real Chinese railway or specific rolling stock. No railway manufacturer's assets were used.

## Playing

- M: show/hide route guide. Bus icons, route lines, stop dots and parks appear on the mini-map.
- E by an open bus front door: board. E during travel: request a stop. E while doors are open at a stop: alight onto the pavement.
- Doors only open during a stationary stop. Buses stay still while closing them. Signals include red, red-and-amber, green, amber and clearance intervals. Vehicles queue with gaps and yield to pedestrians directly ahead.
- At either park, E near the ball kicks it. Goals score and reset the ball. E at a swing, slide or bench uses it; G/E releases the activity. Benches restore health slowly. E at the park lap start begins a timed run through four gold rings.

The game currently supports one player rider per bus; lightweight NPCs visually board/alight and passengers appear upstairs. This is a bus-riding system, not a bus-driving job or a full public transport economy.

## Autonomous services update

Bus drivers have been removed. Passenger queues now use paying commuters that reparent into the bus and alight at assigned stops. Departures reserve 90-second slots at the city terminus with off-service staging; stop dwell is normally 15 seconds and at most 60. Terminal and next-stop text change through the loop. The latest fares (£2 bus; £3 + 3p/game metre Aurora), monthly £400 rent and wages are original game rules, not real NCT fares or Nottingham council policies.

Aurora now uses rounded original body/cabin lofts and service-specific butterfly door panels. The everyday road cars are original rounded lofts with separate wheels, lamps, mirrors, window pillars and door seams, replacing the earlier imported kit appearance in live and claimed cars. All remain original MIT geometry. Simulation and local-save limitations are documented in the README.


Skylink helicopter geometry and helipad markings are original procedural meshes in `vehicles/helicopter_model.gd` and `simulation/helicopters.gd`, under this repository’s MIT licence. The short rotor loop `simulation/audio/helicopter.wav` is original procedural audio. No manufacturer or flight-simulator assets are copied.

## Robovan shuttle

`vehicles/robovan_model.gd` is original procedural geometry under this repository’s MIT licence. It is a stylized six-seat electric shuttle with a tapered silver shell, open cabin, sliding doors, seats and lights. No manufacturer model, logo or proprietary mesh is included.

## Refined bodywork (16 October 2026)

The silver Robovan streamliner and gold Aurora fastback are original procedural geometry. Tesla's official Q3 2024 update photos (Cybercab and interior, slides 14–15; Robovan, slide 16) informed proportions, enclosed wheels, continuous crowns, inset doors and light ribbons: https://ir.tesla.com/_flysystem/s3/sec/000162828024043432/tsla-20241023-gen.pdf . Reference photos are not shipped as game assets. Game cabins, dimensions, fleet jobs and manual controls remain original game designs rather than manufacturer specifications.

`vehicles/coachwork.gd` shares immutable merged meshes and materials across the eighteen road-service vehicles; moving doors and wheel pivots remain independent. Near-vehicle geometry stays under 16,000 triangles per model and is culled at distance.
