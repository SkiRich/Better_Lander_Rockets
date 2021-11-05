# Better Lander Rockets
## [v1.4.3] 11/05/21 5:29:22 AM
#### Changed
- function OnMsg.RocketLaunchFromEarth(rocket)
- function LanderRocketBase:CancelFlight() 
- function LanderRocketBase:UnloadDrones(drones) 

#### Added
- self.landed = true to GameInit()

#### Removed
- function OnMsg.ConstructionComplete(rocket) -  moved to GameInit()

#### Fixed Issues
- function OnMsg.ConstructionComplete(rocket) was not hitting on LanderRocketBase anymore
- fixed auto mode - they changed the variable
- fixed lander stalled on Mars due to missing landed variable.
- fixed nil check in UnloadDrones

--------------------------------------------------------
## [v1.4.2] 11/05/21 1:05:11 AM
#### Changed
- LanderRocketBase:SetDefaultPayload(payload) 
- LanderRocketBase:DeleteOnboardDrones() 

#### Fixed Issues
- beta code removed  CargoTransporter.FixCargoToPayloadObject(self, payload) 
- throwing errors due to double doneobject deletes in DeleteOnboardDrones()

--------------------------------------------------------
## [v1.4.1] 10/31/21 5:08:37 AM
#### Changed
- function CargoTransporter:Find(manifest, quick_load)

#### Fixed Issues
- Legacy versions under 1009232 still use Find in Expedition rockets.  Needed to exclude them

--------------------------------------------------------
## [v1.4] 10/29/21 4:02:41 AM
#### Changed
- CargoTransporter:BLRexpeditionFindDrones
- CargoTransporter:Load
- CargoTransporter:Find(manifest, quick_load) 
- LanderRocketBase:UIEditPayloadRequest()

#### Added
- PickDroneFrom(controller, picked, filter) 
- CargoTransporter:BLRExpeditionLoadCrew(crew) 
- CargoTransporter:BLRExpeditionGatherPrefabs(num_prefabs, prefab) 
- function LanderRocketBase:DeleteOnboardDrones()  - new function
- function LanderRocketBase:Unload() 

#### Fixed Issues
- New beta code removed several functions.  Needed make them.
- Dual game version code in LanderRocketBase:UIEditPayloadRequest()
- DoneObjects in Unload does not get rid of command_threads and destructor threads of onboard rockets


--------------------------------------------------------
## [v1.3.2] 10/20/21 10:41:30 PM
#### Changed
- LanderRocketBase:SpawnDrone()  

#### Fixed Issues
- preventing crash or spurious drone behaviour on leadout

--------------------------------------------------------
## [v1.3.1] 10/19/21 1:05:11 AM
#### Added
- new deadhand

#### Changed
- LanderRocketBase:SpawnDrone()
- LanderRocketBase:UseDronePrefab(bulk) 

#### Fixed Issues
- elevator door not opening on spawndrone
- allowed to go negative on drone prefabs

#### Todo
- Manual Unload
- Filter picks unemployed first

--------------------------------------------------------
## [v1.3] 10/13/21 11:09:21 PM
#### New
- Pack Unpack Drones on the rocket

#### Changed
- CargoTransporter:BLRExpeditionLoadRover(rover) using rover:SetCommand(false) instead of Idle
- local roverfilter = function(unit)  added check for holder during quickload
- function CargoTransporter:Load(manifest, quick_load)  added short circuit ini case we cancel flight.
- DroneApproachingRocket(drone) nil check
- function CargoTransporter:BLRExpeditionLoadRover(rover) - drone exit fix

#### Added
- function LanderRocketBase:Getsurface_drone_prefabs() 
- function LanderRocketBase:SpawnDrone() 
- function LanderRocketBase:ConvertDroneToPrefab(bulk) 
- function LanderRocketBase:UseDronePrefab(bulk) 
- added button and xtemplate for prefabs
- function LanderRocketBase:GetEntrancePoints(entrance_type, spot_name) 
- function LanderRocketBase:GetEntrance(target, entrance_type, spot_name) 
- LanderRocketBase:BLRgetCargoRequested() new
- LanderRocketBase:BLRfixCargoAnomolies() new
- function LanderRocketBase:UnloadDrones(drones)
- function LanderRocketBase:SpawnDronesFromEarth()

#### Removed
- removed local BLRonAction function - not used but placed into the unused code lua file in dir
- function LanderRocketBase:BuildWaypointChains() not needed
- function LanderRocketBase:BLRgetDroneExitPoint()  not needed
- function LanderRocketBase:BuildWaypointChains() not needed
- removed - check for waypoint_chains and fix if needed

#### Fixed Issues
- possible runaway or invalid condition when cancelling flight
- possible cargo duplication when cancelling flight
- No exit points defined for drone spawns
- Drones not properly spawn with GoHome and no longer stack at the foot of the ramp.
- Errors with taskrequests when packinig drones -- [LUA ERROR] HGE::Request_Fulfill: tr->m_nActualAmount - tr->m_nTargetAmount >= nAmount
- Fixed negative cargo anomolies

#### Todo
- Manual Unload
- Filter picks unemployed first
- Fix UseDronePrefabs to have self.drones = self.drones or empty_table instead of 0

--------------------------------------------------------
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

