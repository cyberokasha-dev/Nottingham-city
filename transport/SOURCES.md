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

The existing 340-metre game grid is a compressed Nottingham-inspired layout, not an accurate survey, real journey planner or current timetable. The game uses real road/place names and real service numbers 60, 61 and 44, then builds playable continuous loops on this grid. The 24 in-game shelters and their positions are original game placements. “Victoria Centre connection” identifies an in-game connector, not a claim that each real service serves that exact stop. C1 City Link is fictional and uses London-inspired red double-deckers. The two parks contain fictional compact activity layouts rather than copies of actual park facilities.

## Playing

- M: show/hide route guide. Bus icons, route lines, stop dots and parks appear on the mini-map.
- E by an open bus front door: board. E during travel: request a stop. E while doors are open at a stop: alight onto the pavement.
- Doors only open during a stationary stop. Buses stay still while closing them. Signals include red, red-and-amber, green, amber and clearance intervals. Vehicles queue with gaps and yield to pedestrians directly ahead.
- At either park, E near the ball kicks it. Goals score and reset the ball. E at a swing, slide or bench uses it; G/E releases the activity. Benches restore health slowly. E at the park lap start begins a timed run through four gold rings.

The game currently supports one player rider per bus; lightweight NPCs visually board/alight and passengers appear upstairs. This is a bus-riding system, not a bus-driving job or a full public transport economy.

## Autonomous services update

Bus drivers have been removed. Passenger queues now use paying commuters that reparent into the bus and alight at assigned stops. Departures reserve 90-second slots at the city terminus with off-service staging; stop dwell is normally 15 seconds and at most 60. Terminal and next-stop text change through the loop. The latest fares (£2 bus; £3 + 3p/game metre Aurora), monthly £400 rent and wages are original game rules, not real NCT fares or Nottingham council policies.

Aurora now uses rounded original body/cabin lofts and service-specific butterfly door panels. The everyday road cars are original rounded lofts with separate wheels, lamps, mirrors, window pillars and door seams, replacing the earlier imported kit appearance in live and claimed cars. All remain original MIT geometry. Simulation and local-save limitations are documented in the README.
