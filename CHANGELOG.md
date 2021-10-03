# Better Lander Rockets
## [v0.2] 10/01/21 6:34:24 PM
#### Changed
- consolidated the filter functions and renamed them
- CargoTransporter:BLRexpeditionFindDrones - added a do not steal drones routine
- changed CargoTransporter:Find added all the other functions and cutoffs
- moved roverfilter back into called function since secondary vars are called

#### Added
- do not steal drone routine to BLRexpeditionFindDrones()
- rewrite function CargoTransporter:ExpeditionLoadDrones(found_drones, quick_load)
- local function adultfilter(_ , c) - filter for the crew
- rewrite of function DroneBase:CanBeControlled() - devs screwed up and put two in game
- rewrite of function CargoTransporter:ExpeditionLoadRover(rover) 
- new function CargoTransporter:BLRexpeditionFindRovers(class, quick_load, amount) 
- rewrite function LanderRocketBase:SetDefaultPayload() to localize the default payloads
- added rocketOptions var to global options var
- function LanderRocketBase:BLRresetDefaultPayload() to set and save the default loadout on Mars launch.
- function OnMsg.RocketLaunched(rocket) to calll set default loadout.  Easiest this way and no re-write functions.
- MCR options for rocketOptions

#### Todo
- panels
- status section
- default loadout choice in panels

--------------------------------------------------------
## [v0.1] 10/01/21 3:40:52 PM
#### Initial Development
- Fix for inventory rounding errors preventing rocket launches and auto launches on asteroids
- Picks already assigned or closest drones to the rocket when packing drones into cargo

--------------------------------------------------------

