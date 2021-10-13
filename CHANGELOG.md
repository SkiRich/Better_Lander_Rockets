# Better Lander Rockets
## [v1.2] 10/13/21 3:35:59 AM
#### Changed
- StringIdBase numbers, added 100
- function BLRsetRollOverText(rocket) - added code to display the issues we collect
- added issues collction logic to panels via setrollover
- function BLRfindResourceIssues(rocket)  - added issues collection logic
- BLRfindCargoIssues(rocket) - added issues collection logic
- BLRfindCrewIssues(rocket) - added issues collection logic
- better fonts in rolloverhint

#### Added
- rocket:StopDepartureThread() on fixup rockets
- function LanderRocketBase:CancelFlight() to properly cancel a rocket launch
- function OnMsg.RocketLaunchFromEarth(rocket) - change auto load when purchasing a rocket

#### Fixed Issues
- rockets not cancelling properly
- running out of StringIdNumbers
- Tourists still sneaking onto rockets

--------------------------------------------------------
## [v1.1.1] 10/12/21 5:08:38 PM
#### Changed
- CargoTransporter:BLRExpeditionLoadDrones(found_drones, quick_load) 

#### Fixed Issues
- after drones despawned cannot call createdrone, city is nil
using rocket self as the controller from now on.

#### Todo
- resource loadout when rockets on asteroid
- manual unload rocket

--------------------------------------------------------
## [v1.1.0] 10/12/21 4:28:14 AM
#### Changed
- BLRfixLanderRockets() added pin add routine to rocket fixups

#### Added
- Asteroid Hopping mechanics new function
- function BLRchangePinHint(rocket, change)  new function
- function BLRconvertDateTime(currentTime)  new function
- function LanderRocketBase:BLRaddPinChangeThread()  new function
- function LanderRocketBase:OnPinClicked(gamepad) - rewrite to incept pin mechanics


--------------------------------------------------------
## [v1.0.1] 10/11/21 7:18:25 PM
#### Changed
- CargoTransporter:BLRExpeditionLoadDrones(found_drones, quick_load)  - added DroneApproachingRocket function

#### Added
-- local function DroneApproachingRocket(drone) 

#### Fixed Issues
- Stepping on expedition rocket code, so now completely excluded
- crash when loading drones that are on entrance ramp of another rocket.

#### Todo
- prefab buttons
- send rocket home function

--------------------------------------------------------
## [v1.0] 10/04/21 12:55:47 AM

Initial Release

#### ToDo


--------------------------------------------------------
## [v0.3] 10/04/21 5:04:20 PM
#### Changed
- renamed BLR_2ModConfig.lua to 3
- changes items and metadata
- changed StringIdBase - needed more numbers

#### Added
- BLR_2Panels.lua and panel code
- local LanderRocketCargoPreset as a copy of the preset incase the devs remove it or localize it
- added loadout logic


--------------------------------------------------------
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

