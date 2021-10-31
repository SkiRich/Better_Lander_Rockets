-- Code developed for Better Lander Rockets
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- Created Sept 20th, 2021
-- Updated Oct 30th, 2021


local lf_print        = false  -- Setup debug printing in local file -- use Msg("ToggleLFPrint", "BLR", "printdebug") to toggle
local lf_printc       = false  -- print for classes that are chatty
local lf_printd       = false  -- print dialog redirect debugs
local lf_printDebug   = false

local mod_name = "Better Lander Rockets"
local table = table
local IsValidPos  = CObject.IsValidPos

local StringIdBase  = 17764706000 -- Better Lander Rockets    :  706000 - 706199  This File Start 50-99, Next: 51
local enforceFilter = false -- enforce filtering in GetAvailableColonistsForCategory 

-- options for Better Lander Rockets Mod
g_BLR_Options = {
  modEnabled         = true,
  rocketOptions      = true,
  asteroidExtendTime = 2
}

g_BLR_PayloadRequest_Thread = false -- thread holder for dialog render


-- copy of local function from ResourceOverview.lua
-- changed the math so we drop remainders instead of rounding up.
-- rounding up here causes inventory to be wrong when loading rockets
-- so we drop remainders
local function RoundDownResourceAmount(r)
  r = r or 0
  r = r / const.ResourceScale
  r = (r - (r % 1)) * const.ResourceScale
  return r
end -- function RoundDownResourceAmount(r)

-- needed for CargoTransporter:BLRexpeditionFindDrones and ExpeditionGatherCrew
local sort_obj
local function SortByDist(a, b)
	return a:GetVisualDist2D(sort_obj) < b:GetVisualDist2D(sort_obj)
end -- SortByDist

-- used in BLRExpeditionLoadDrones and BLRExpeditionFindDrones
local dronefilter = function(drone)
  return drone:CanBeControlled() and (not drone.holder) and IsValid(drone) and IsValidPos(drone) -- dont take drones inside a rocket
end -- dronefilter

-- used in ExpeditionGatherCrew
local function adultfilter(_, c)
  local workingSeniors = IsTechResearched("ForeverYoung") and true  -- IsTechResearched returns digit 1 if true so replace it here
	return not (c.traits.Child or c.traits.Tourist or (c.traits.Senior and not workingSeniors)) -- use not workingSeniors here to negate the original not and allow the senior
end -- adultfilter



-- extend asteroid linger time
local function BLRextendAsteroidTime(rocket)
  if IsKindOf(rocket, "LanderRocketBase") and ObjectIsInEnvironment(rocket, "Asteroid") then 
    local map_id = rocket.city.map_id or ""
    local asteroids = UIColony.asteroids or empty_table
    for i = 1, #asteroids do
      local asteroid = asteroids[i]
      if (asteroid.map == map_id) and (not asteroid.BLR_extendedTime) then
        local sols = g_BLR_Options.asteroidExtendTime * const.Scale.sols
        asteroid.end_time = asteroid.end_time + sols
        if map_id == ActiveMapID then
          local asteroid_timer_params = {
            start_time = asteroid.start_time,
            end_time = asteroid.end_time,
            expiration = asteroid.end_time - asteroid.start_time,
            rollover_title = asteroid.title,
            rollover_text = asteroid.description,
            title = asteroid.title
          }
          AddOnScreenNotification("AsteroidTimer", nil, asteroid_timer_params, nil)
        end -- if map_id
        asteroid.BLR_extendedTime = true
      end -- if asteroids
    end -- for i
  end -- if IsKindOf
end -- BLRextendAsteroidTime(rocket)


-- fixup broken landed rockets
local function BLRfixLanderRockets()
  if not g_BLR_Options.modEnabled then return end -- shortcircuit
  local rockets = UIColony.city_labels.labels.LanderRocketBase or empty_table
  
  
  for _, rocket in ipairs(rockets) do
    -- fix for stuck cargo crew
    if rocket:IsRocketLanded() and rocket.crew and (#rocket.crew == 0) then
      local manifest = CreateManifest(rocket.cargo or empty_table)
      local crew     = manifest.passengers or empty_table
      for _, payload in pairs(rocket.cargo or empty_table) do
        if crew[payload.class] and payload.amount > 0 and payload.requested == 0 then payload.amount = 0 end -- zero out passenger cargo
      end -- for _,      
    end -- if rocket:IsRocketLanded()
    
    -- add pin hint thread to waiting rockets
    if rocket.command == "WaitInOrbit" then rocket:BLRaddPinChangeThread() end
    
    -- stop any departure threads
    rocket:StopDepartureThread() -- no tourists or earthsick sneak on
        
    -- fix cargo
    rocket:BLRfixCargoAnomolies()
    
  end -- for _, rocket
  
  -- extend time for asteroids with rockets on them that didnt get the extension
  for _, rocket in ipairs(rockets) do
    if rocket:IsLandedOnAsteroid() then BLRextendAsteroidTime(rocket) end
  end -- for _,
  
end -- function BLRfixLanderRockets()


-- empty any resources from the stockpile on the rover
local function BLRemptyStockpile(rover)
  local stock = rover.stockpiled_amount or empty_table
  for res, amount in pairs(stock) do
    if amount > 0 then rover:AddResource(-amount, res) end
  end -- for res
end -- BLRemptyStockpile(rover)


-- cheat a new asteroid
function BLRcheatSpawnAsteroid()
  local asteroid = table.rand(Presets.DiscoveryAsteroidPreset.Default)
  UIColony:SpawnAsteroid(asteroid)
end -- BLRcheatSpawnAsteroid()


-- copy from CargoTransporter.lua
local function DroneApproachingRocket(drone)
  if drone and drone.s_request then
    local target_building = drone.s_request:GetBuilding()
    if IsKindOf(target_building, "RocketBase") and table.find(target_building.drones_entering, drone) then
      return true
    end -- if IsKindOf
  end -- if drone.s_request
  return false
end -- function DroneApproachingRocket(drone)


-- function to put custom hint text or return to vanilla
local function BLRchangePinHint(rocket, change)
  local newPinHint = T{StringIdBase + 50, "<center><left_click> Place Rocket<newline>Ctrl+<left_click> Travel to another location"}
  if change then 
    rocket.pin_rollover_hint = newPinHint
  else
    rocket.pin_rollover_hint = g_Classes.LanderRocketBase.pin_rollover_hint
  end
end -- BLRchangePinHint(rocket)


-- calculate and convert the time
local function BLRconvertDateTime(currentTime)
  local deltaTime = currentTime 
  local sol    = (deltaTime / const.DayDuration)
  local hour   = ((deltaTime % const.DayDuration) / const.HourDuration)
  local minute = ((deltaTime % const.DayDuration) % const.HourDuration) / const.MinuteDuration
  return string.format("%s Sols %02d Hours  %02d Minutes", sol, hour, minute)
end -- BLRconvertDateTime()


-- copy of old ExpeditionPickDroneFrom from Picard-HF4
-- no longer exists, fuck it its mine now.
-- filter is in the function calling it
local function PickDroneFrom(controller, picked, filter)
	local drone = nil
	for _, d in ipairs(controller.drones or empty_table) do
		if d:CanBeControlled() and not table.find(picked, d) then
			if (not filter or filter(d)) then
				if not drone or drone.command ~= "Idle" and d.command == "Idle" then -- prefer idling drones
					drone = d
				end -- if not drone
			end -- if not filter
		end -- if d:CanBeControlled
	end -- for _, d
	return drone
end -- function PickDroneFrom



--------------------------------------------------------------------------------------------------

-- just in case they load this mod and dont have the B&B DLC
if not g_AvailableDlc.picard then
  DefineClass.Asteroids = {}
  DefineClass.LanderRocketBase = {}
  DefineClass.MicroGHabitat = {}
end -- if not picard


------------------------------------------- OnMsgs --------------------------------------------------
function OnMsg.ClassesBuilt()

  
  -- need to add qualifiers to this function
  local Old_TraitsObject_GetAvailableColonistsForCategory = TraitsObject.GetAvailableColonistsForCategory
  function TraitsObject:GetAvailableColonistsForCategory(city, category)
    if not g_BLR_Options.modEnabled then return Old_TraitsObject_GetAvailableColonistsForCategory(self, city, category) end -- short circuit
    city = city or UICity 
    category = category or "Colonist"
    local filterToUse = (not enforceFilter and true) or adultfilter
    local filteredColonists = city.labels[category] and table.ifilter(city.labels[category], filterToUse) or empty_table
    -- Chatty if lf_print then print(string.format("---- Filter found %d %s", #filteredColonists, category)) end
    return #filteredColonists or 0
  end -- TraitsObject:GetAvailableColonistsForCategory(city, category)


  -- rewrite from LanderRocketBase
  -- Interecpt call for opening payload dialog so can play along
  local Old_LanderRocketBase_UIEditPayloadRequest = LanderRocketBase.UIEditPayloadRequest
  function LanderRocketBase:UIEditPayloadRequest()
    if not g_BLR_Options.modEnabled then return Old_LanderRocketBase_UIEditPayloadRequest(self) end -- short circuit
    if lf_printd then print("-- g_BLR_PayloadRequest_Thread Function started --") end
    
    self:BLRfixCargoAnomolies() -- fix any cargo anomolies
    
    enforceFilter = not ObjectIsInEnvironment(self, "Asteroid") -- enforce filter on Mars only in GetAvailableColonistsForCategory
    self.prefab_count_fail = false -- reset this here since Find only runs when target set
    
    -- start realtime thread to watch for variables
    DeleteThread(g_BLR_PayloadRequest_Thread) -- just in case
    g_BLR_PayloadRequest_Thread = CreateRealTimeThread(function()
      if lf_printd then print("-- g_BLR_PayloadRequest_Thread Thread Started --") end
      
      -- wait for the screen to paint
      WaitMsg("OnRender") -- wait for screen to open
      while Dialogs.MarsPauseDlg and not Dialogs.PayloadRequest do
        Sleep(100)
      end -- while
      
      Sleep(100) -- give it chance to paint
      
      -- if we are in the dialog then start the watcher loop
      if Dialogs.MarsPauseDlg and Dialogs.PayloadRequest then
        local host = Dialogs.PayloadRequest  -- They forgot this
        if lf_printd then print("-- Starting Watcher Loop --") end
        local modEnabled = g_BLR_Options.modEnabled
        -- run replacement loop when back on items screen only
        while modEnabled and host.idContent do
          -- devs removed offending code so no need to replace this.  Not used but keeping loop for enforceFilter and example
          -- moved replaced code from this file into file called UnUsed_LuaCode.lua
          -- if host.idContent.idToolBar.idrequest then
          --   host.idContent.idToolBar.idrequest.action.OnAction = BLRonAction
          -- end -- if mode
          Sleep(100)
        end -- while
        
      end -- if Dialogs
      
      enforceFilter = false
      if lf_printd then print("-- g_BLR_PayloadRequest_Thread Thread Exited --") end
    end) -- thread
    
    if LuaRevision >= 1009232 then -- for beta code
      if self:CanRequestPayload() then
        self:OpenPayloadDialog("PayloadRequest", self, {
          meta_key = const.vkControl,
          close_on_rmb = true })
      end -- if self:CanRequestPayload()
    else
      if self:AutoLoadCargoEnabled() then 
        CloseDialog("PayloadRequest") 
        CargoTransporter.OpenPayloadDialog(self, "PayloadPriority", self, { 
          meta_key = const.vkControl, 
          close_on_rmb = true 
        }) 
      else 
        CloseDialog("PayloadPriority") 
        CargoTransporter.UIEditPayloadRequest(self) 
      end
    end -- if LuaRevision

  end -- LanderRocketBase:UIEditPayloadRequest()

  
end -- OnMsg.ClassesBuilt()

-----------------------------------------------------------------------------------------------------

function OnMsg.ClassesGenerate()

  
  
  -- new function
  -- check for cargo anamolies, because shit happened
  function LanderRocketBase:BLRfixCargoAnomolies()
    local cargo = self.cargo or empty_table
    local stock = self.stockpiled_amount or empty_table
    
    -- fix the cargo
    for item, payload in pairs(cargo) do
      if payload.amount < 0 then payload.amount = 0 end  
    end -- for item
    
    -- fix the stockpile
    for item, amount in pairs(stock) do
      if amount < 0 then self:AddResource((amount * -1), item) end  -- needed to do it this way
    end -- for item
  end -- LanderRocketBase:BLRfixCargoAnomolies()
  
  
  -- new function
  -- determine what cargo is being requested
  function LanderRocketBase:BLRgetCargoRequested()
    local cargoRequested = {}
    for _, entry in pairs(self.cargo) do
      if entry.amount < entry.requested then
        table.insert(cargoRequested, entry)
      end -- if
    end -- for
    return cargoRequested
  end -- LanderRocketBase:BLRgetCargoRequested()
 
 
  -- new function, copy of ancestor so we can properly convert drones to prefabs
  local Old_LanderRocketBase_ConvertDroneToPrefab = LanderRocketBase.ConvertDroneToPrefab
  function LanderRocketBase:ConvertDroneToPrefab(bulk)
    if not g_BLR_Options.modEnabled  then return Old_LanderRocketBase_ConvertDroneToPrefab(self, bulk) end -- short circuit
    bulk = bulk and 5 or 1
    while bulk > 0 do
      local drone = self:FindDroneToConvertToPrefab()
      if drone then
        if drone.demolishing then
          drone:ToggleDemolish()
        end
        drone.can_demolish = false
        table.remove_entry(self.drones, drone)
        SelectionArrowRemove(drone)
        drone:DropCarriedResource()
        if DroneApproachingRocket(drone) then
          local rocket = drone.s_request:GetBuilding()
          table.remove_entry(rocket.drones_entering, drone)
        end -- if DroneApproachingRocket(d)
        drone:DespawnNow()
        self.city.drone_prefabs = self.city.drone_prefabs + 1
      else
        break
      end -- if drone
      bulk = bulk - 1
    end -- while
  end -- LanderRocketBase:ConvertDroneToPrefab(bulk) 
   
  
  -- new function used in text display for RolloverText in xTemplate
  function LanderRocketBase:Getsurface_drone_prefabs()
    return UICity.drone_prefabs or 0
  end -- LanderRocketBase:Getsurface_drone_prefabs()  


  -- rewrite of ancestor from DroneControl.lua
  -- original broken
  -- missing spot indexes
  local Old_LanderRocketBase_SpawnDrone = LanderRocketBase.SpawnDrone
  function LanderRocketBase:SpawnDrone() 
    if not g_BLR_Options.modEnabled  then return Old_LanderRocketBase_SpawnDrone(self) end -- short circuit
    local drone = self.city:CreateDrone()
    drone:SetHolder(self)
    drone:SetCommandCenter(self)
    CreateGameTimeThread(function(drone, rocket)
      if IsValid(drone) then
        local droneexit = rocket:GetSpotLoc(rocket:GetSpotBeginIndex(rocket.drone_spawn_spot)) 
        drone:SetPos(droneexit)
        drone:SetCommand(false) -- otherwise its Idle while leadout
        Sleep(10)
        CreateGameTimeThread(function()
          drone.command_thread = CurrentThread()
          rocket:LeadOut(drone)
        end)
        Sleep(250)
        while drone.holder do
          Sleep(100)
        end -- while still exiting
        drone:SetCommand("GoHome", nil, nil, droneexit, "ReturningToController")
      end -- if IsValid
    end, drone, self) -- thread
    return drone    
  end -- LanderRocketBase:SpawnDrone()

  
  -- rewrite of ancestor from DroneControl.lua
  -- original broken
  local Old_LanderRocketBase_UseDronePrefab = LanderRocketBase.UseDronePrefab
  function LanderRocketBase:UseDronePrefab(bulk)
    if not g_BLR_Options.modEnabled then return Old_LanderRocketBase_UseDronePrefab(self, bulk) end -- short circuit
    bulk = bulk and 5 or 1
    self.drones = self.drones or empty_table
    local maxdrones = self:GetMaxDrones()
    CreateGameTimeThread(function(bulk, rocket)
      local city = rocket.city
      while bulk > 0 and city.drone_prefabs and city.drone_prefabs > 0 and #rocket.drones < maxdrones do
        local drone = rocket:SpawnDrone()
        if drone then
          city.drone_prefabs = city.drone_prefabs - 1
          table.insert_unique(rocket.drones, drone)
        end -- if drone
        bulk = bulk - 1
        Sleep(250)
      end -- bulk > 0
    end, bulk, self) -- thread
  end -- LanderRocketBase:UseDronePrefab(bulk)  
  
  
  -- rewrite from LanderRocketBase
  -- original does not zero out both target_spot and requested_spot
  -- rocket also not in WaitLaunchOrder
  local Old_LanderRocketBase_CancelFlight = LanderRocketBase.CancelFlight
  function LanderRocketBase:CancelFlight()
    if not g_BLR_Options.modEnabled then return Old_LanderRocketBase_CancelFlight(self) end -- short circuit
    self.target_spot = false
    self.requested_spot = false
    self:SetCommand("WaitLaunchOrder")
  end -- LanderRocketBase:CancelFlight()


  -- new function
  -- add BLR pin Thread
  function LanderRocketBase:BLRaddPinChangeThread()
    if IsValidThread(self.BLR_pinThread) then DeleteThread(self.BLR_pinThread) end 
    self.BLR_pinThread = CreateRealTimeThread(function(rocket)
      BLRchangePinHint(rocket, true)
      while IsValid(rocket) and rocket.command == "WaitInOrbit" do
        Sleep(500)
      end -- while
      BLRchangePinHint(rocket, false)
    end, self) -- thread    
  end -- LanderRocketBase:BLRaddPinChangeThread()
  
  
  -- rewrite from ancestor so we can intercept the command and start a thread.
  local Old_LanderRocketBase_WaitInOrbit = LanderRocketBase.WaitInOrbit
  function LanderRocketBase:WaitInOrbit(arrive_time)
    if not g_BLR_Options.modEnabled then return Old_LanderRocketBase_WaitInOrbit(self, arrive_time) end -- short circuit
    
    self:BLRaddPinChangeThread()
    
    RocketBase.WaitInOrbit(self, arrive_time or GameTime() or false)
  end -- LanderRocketBase:WaitInOrbit(arrive_time)
  

  -- rewrite from LanderRocketBase.lua
  -- intercept pin click to offer alternate travel options
  function LanderRocketBase:OnPinClicked(gamepad)
    if not g_BLR_Options.modEnabled then return RocketBase.OnPinClicked(self, gamepad) end -- short circuit
    if IsMassUIModifierPressed() then 
      CreateRealTimeThread(function(rocket)
        local params  = {title = "Travel to Another Location", image = "UI/Messages/asteroid_view_of_mars.tga", start_minimized = false}
        local choices = {}
        local choice  = false
        local locations = {}
        local hasFuel = rocket.cargo.Fuel.amount >= 15
        local currentLocation = rocket.city and rocket.city.map_id or ""
        if hasFuel then
          params.text = "You have enough fuel to travel to:"
          if currentLocation ~= HomeColonySpot().map then 
            locations[#locations+1] = {spot = HomeColonySpot() , name = "Back to Mars", timeleft = ""}
            choices[#choices+1] = "Back to Mars"
          end -- if currentLocation
          local asteroids = UIColony.asteroids or empty_table
          for i = 1, #asteroids do
            if currentLocation ~= asteroids[i].map then 
              locations[#locations+1] = {spot = asteroids[i].poi , name = asteroids[i].poi.display_name, timeleft = BLRconvertDateTime(asteroids[i].end_time - GameTime())} 
              choices[#choices+1] = asteroids[i].poi.display_name .. " - Time Left: " .. BLRconvertDateTime(asteroids[i].end_time - GameTime())
            end -- if currentLocation
          end -- for i
          choices[#choices+1] = "Cancel"
          for i, choice in ipairs(choices) do
            params["choice" .. i] = choice
          end -- for i,
          choice = WaitPopupNotification(false, params)
          
          if locations[choice] then
            rocket.cargo.Fuel.amount = rocket.cargo.Fuel.amount - 15
            rocket.target_spot = locations[choice].spot
            rocket:SetCommand("FlyToSpot", locations[choice].spot)
            if lf_print then print("Choice: ", choice, " Location: ", _InternalTranslate(locations[choice].name), " MapID: ", locations[choice].spot.map) end
          end -- if choices[choice]
        else
          params.text    = "Rocket does not have enough fuel in the cargo hold for another journey.<newline>Minimum 15 units required."
          params.choice1 = "Cancel"
          choice = WaitPopupNotification(false, params)
        end -- if hasFuel
      end, self) -- CreateRealTimeThread

      return true -- no infopanel popup
    end
    return RocketBase.OnPinClicked(self, gamepad)
  end -- RocketBase:OnPinClicked(gamepad)
  
  
  -- new function to prevent CTD and lockup when colonists are on mars
  -- yeah they try to call a shuttle.  duh.
  function MicroGHabitat:GetNearestLandingSlot(ref_pos, ...)
    return nil, nil
  end -- MicroGHabitat:GetNearestLandingSlot(ref_pos, ...)


  -- rewrite from Asteroids.lua
  -- intercept call and save orbiting rockets and rockets on their way to asteroid
  local Old_Asteroids_NotifyRocketsAsteroidMovingOutOfRange = Asteroids.NotifyRocketsAsteroidMovingOutOfRange
  function Asteroids:NotifyRocketsAsteroidMovingOutOfRange(asteroid)
    if not g_BLR_Options.modEnabled then return Old_Asteroids_NotifyRocketsAsteroidMovingOutOfRange(self, asteroid) end

    -- look for any rockets in orbit
    local city = Cities[asteroid.map]
    local lost_rockets = {}
    
    if city then
      for _, rocket in ipairs(city.labels.AllRockets or empty_table) do
        local orbiting_rocket = (rocket.command == "WaitInOrbit") and (rocket.cargo.Fuel.amount >= 15)
        if orbiting_rocket then
          -- send them home
          rocket.target_spot = HomeColonySpot()
          rocket.cargo.Fuel.amount = rocket.cargo.Fuel.amount - 15
          rocket:TransferToMap(HomeColonySpot().map) -- have to do this now otherwise assets get DoneObject on asteriod demolish
          rocket:SetCommand("FlyToSpot", HomeColonySpot())
          Sleep(100) -- just in case
        end -- orbiting_rocket
        if not rocket.command == "FlyToSpot" then
          table.insert(lost_rockets, rocket)
        end -- if not rocket.command
      end -- for _, rocket
    else
      -- determine if any enroute or already orbiting asteroid not map switched
      local rockets = UIColony.city_labels.labels.LanderRocketBase or empty_table
      local save_rockets = {}
      for _, rocket in ipairs(rockets) do
        if rocket.target_spot and (rocket.target_spot.map == asteroid.map) and (rocket.command == "FlyToSpot" or rocket.command == "WaitInOrbit") and (rocket.cargo.Fuel.amount >= 15) then
          table.insert(save_rockets, rocket)
        elseif rocket.target_spot and (rocket.target_spot.map == asteroid.map) and (rocket.command == "FlyToSpot" or rocket.command == "WaitInOrbit") and (rocket.cargo.Fuel.amount < 15) then
          table.insert(lost_rockets, rocket)
        end -- if rocket
      end -- for _, rocket
      for i = 1, #save_rockets do
        local rocket = save_rockets[i]
        rocket.target_spot = HomeColonySpot()
        rocket.cargo.Fuel.amount = rocket.cargo.Fuel.amount - 15
        rocket:TransferToMap(HomeColonySpot().map)
        rocket:SetCommand("FlyToSpot", HomeColonySpot())      
      end -- for i
      -- if map not exposed yet then these should have the rockets listed in the asteroid object here
      -- since we are sending the rockets home or blowing them up just nil out the asteroid object here
      MapSwitchCallbackRockets[asteroid.map] = nil
      MapSwitchCallbacks[asteroid.map] = nil
    end -- if city

    -- kill the rockets that cant come home
    for _, rocket in ipairs(lost_rockets) do
      Msg("RocketLost", rocket)
      DoneObject(rocket)
    end -- for _, rocket

    -- run the old function to finish up
    return Old_Asteroids_NotifyRocketsAsteroidMovingOutOfRange(self, asteroid)
  end -- Asteroids:NotifyRocketsAsteroidMovingOutOfRange(asteroid)


  -- new function for use here
  function LanderRocketBase:IsLandedOnAsteroid()
    return self:IsRocketLanded() and ObjectIsInEnvironment(self, "Asteroid")
  end -- LanderRocketBase:IsLandedOnAsteroid()


  -- new function
  -- copy of ancestor.  They forgot unit
  -- not putting in a short circuit
  function LanderRocketBase:GetEntrance(target, entrance_type, spot_name, unit)
    if not g_BLR_Options.modEnabled then return CargoTransporter.GetEntrancePoints(self, entrance_type, spot_name, unit) end
    return WaypointsObj.GetEntrance(self, target, entrance_type or "rocket_entrance", spot_name or "openInside", unit)
  end -- LanderRocketBase:GetEntrance(target, entrance_type, spot_name, unit)


  -- new function
  -- copy of ancestor.  They forgot self
  -- not putting in a short circuit
  function LanderRocketBase:GetEntrancePoints(entrance_type, spot_name)
    if not g_BLR_Options.modEnabled then return CargoTransporter.GetEntrancePoints(self, entrance_type, spot_name) end
    return WaypointsObj.GetEntrancePoints(self, entrance_type or "rocket_entrance", spot_name)
  end -- LanderRocketBase:GetEntrancePoints(entrance_type, spot_name)

  

  -- new function to replace ancestor
  -- fixes missing waypoints for entrances
  -- copy from CargoTransporter.lua
  function LanderRocketBase:GetEntrancePoint()
    if not g_BLR_Options.modEnabled then return CargoTransporter.GetEntrancePoint(self) end
    if not self.waypoint_chains or not self.waypoint_chains.rocket_entrance then self:BuildWaypointChains() end -- fix broken waypoints
    local entrance
    if not self.waypoint_chains then
      return entrance
    end
    if self.waypoint_chains.entrance then
      entrance = self.waypoint_chains.entrance[1]
    end
    if self.waypoint_chains.rocket_exit then
      entrance = self.waypoint_chains.rocket_exit[1]
    end
    return entrance
  end -- LanderRocketBase:GetEntrancePoint()

  
  -- new function, copied from Rocketbase.lua ancestor
  -- fixing colonist suffocation here
  local Old_LanderRocketBase_Disembark = LanderRocketBase.Disembark
  function LanderRocketBase:Disembark(crew)
    if not g_BLR_Options.modEnabled then return Old_LanderRocketBase_Disembark(self, crew) end -- short circuit
    local crew = crew or empty_table -- safety
    local domes, safety_dome = GetDomesInWalkableDistance(self.city, self:GetPos())
    for _, unit in pairs(crew) do
      unit:Appear(self)
      unit:SetCommand("ReturnFromExpedition", self, ChooseDome(unit.traits, domes, safety_dome))
      Sleep(100)
      unit:ClearDetrimentalStatusEffects()  -- wtf they were just on a rocket from a near mars object, why are they suffocating?
      Sleep(1000 + SessionRandom:Random(0, 500))
    end -- for _,
  end -- LanderRocketBase:Disembark(crew)
  
  -- new function to correct cargo amount when lander lands on asteroid
  -- did not exist
  function LanderRocketBase:WaitToFinishDisembarking(crew)
    if not g_BLR_Options.modEnabled then return CargoTransporter.WaitToFinishDisembarking(self, crew) end
    
    -- create a gametime thread to allow for the rest of the cargo to get unloaded without waiting for crew
    if IsValidThread(self.BLR_CrewUnloadThread) then DeleteThread(self.BLR_CrewUnloadThread) end -- just in case
    self.BLR_CrewUnloadThread = CreateGameTimeThread(function(rocket)
      local crew = rocket.crew or empty_table -- use the rocket var not the passed var
      while #crew > 0 do
        for _, unit in ipairs(crew) do
          if unit.command ~= "ReturnFromExpedition" then
            table.remove_value(crew, unit)
            rocket.cargo[unit.specialist].amount = rocket.cargo[unit.specialist].amount - 1
            rocket.cargo[unit.specialist].requested = 0
            if rocket.cargo[unit.specialist].amount < 0 then rocket.cargo[unit.specialist].amount = 0 end -- math, you know
          end -- if
        end -- for
        Sleep(200) -- we dont need to wait so long, there is no animation here to really wait for
      end -- while
    end, self) -- thread
  end -- LanderRocketBase:WaitToFinishDisembarking(crew)


  -- from DroneBase
  -- This use to be DroneBase:CanBeControlled()  but they hosed that with a duplicate function of the same name
  -- So putting it in the mod to see what the hell happens.
  local Old_DroneBase_CanBeControlled = DroneBase.CanBeControlled
  function DroneBase:CanBeControlled()
    if not g_BLR_Options.modEnabled then return Old_DroneBase_CanBeControlled(self) end -- short circuit
    return not self.control_override and self.command ~= "Malfunction" and self.command ~= "Dead" and not self.disappeared and not self:IsShroudedInRubble()
  end -- DroneBase:CanBeControlled()


  -- new function to prevent using the ancestor
  -- the ancestor duplicates the drones from the cargo
  function LanderRocketBase:SpawnDronesFromEarth()
    -- we dont need no stinkin drones from earth
    -- purposely left blank to prevent the Unload command from generating drones during that call.
    -- we'll make our own drones in UnLoadDrones()
  end -- LanderRocketBase:SpawnDronesFromEarth()


  -- new function to override ancestor
  -- fix drones unloading from under rocket
  local Old_CargoTransporter_UnloadDrones = CargoTransporter.UnloadDrones
  function LanderRocketBase:UnloadDrones(drones)
    DoneObjects(self.drones)
    self.drones = {}
    local amount = self.cargo.Drone and self.cargo.Drone.amount or 0
    if lf_print then print("+++ Unloading Drones: ", amount) end
    self.cargo.Drone.amount = 0 -- to prevent the unload cargo function from attempting to unload drones.
    CreateGameTimeThread(function(rocket, amount)
      while amount > 0 do
        local drone = rocket:SpawnDrone()
        if drone then
          table.insert_unique(rocket.drones, drone)
        else
          ModLog("ERROR - Better Lander Rockets could not spawn drones during UnloadDrones")
        end -- if drone
        amount = amount - 1
        Sleep(250)      
      end -- while
      Sleep(2000) -- wait to unload the rest of cargo
    end, self, amount) -- thread
  end -- LanderRocketBase:UnloadDrones(drones)

  
  -- new function
  -- copied from CargoTransporter.lua
  -- intercept this function only for Lander Rockets and make sure drones drop any resources before despawn.
  -- this is so we can select nearby drones faster without the default filter.
  function CargoTransporter:BLRExpeditionLoadDrones(found_drones, quick_load)
    if lf_print then print("CargoTransporter:BLRExpeditionLoadDrones running") end
    
    for idx, d in ipairs(found_drones or empty_table) do
      if not dronefilter(d) then       -- if the drone was found it fine, otherwise lets rebuild it.
        if DroneApproachingRocket(d) then
          local rocket = drone.s_request:GetBuilding()
          table.remove_entry(rocket.drones_entering, d)
        end -- if DroneApproachingRocket(d)   
        d:DropCarriedResource()   -- in case they are delivering something
        local controller = self   -- changed this to the rocket since Despawn could be causing issues when the drone no longer exists.
        d:DespawnNow()
        d = controller.city:CreateDrone()
        Sleep(100)
        d.init_with_command = false
        d:SetCommandCenter(controller)
        found_drones[idx] = d
      end -- if not dronefilter(d)
    end -- for idx
    
    for _, drone in ipairs(found_drones) do
      if drone == SelectedObj then
        SelectObj()
      end
      drone:DropCarriedResource()   -- in case they are still delivering something
      drone:SetCommandCenter(false, "do not orphan!")
      drone:SetHolder(self)
      drone:SetCommand("Disappear", "keep in holder")
    end -- for _, drone
  end -- CargoTransporter:BLRExpeditionLoadDrones(found_drones, quick_load)
  
  
  -- new function
  -- for finding closest drones to the rockets
  -- cannot use original since choggi has a mod Expeditions Use Nearest which would not be compatible
  function CargoTransporter:BLRexpeditionFindDrones(num_drones, quick_load)
    if lf_print then print("CargoTransporter:BLRexpeditionFindDrones running") end

  	-- wait to have enough drones, load if we are a go, stop if not
  	while self:HasDestination() do
  	  if lf_print then 
  	    print("Destination Set - Running Find Drones")
        print("Drones needed: ", num_drones) 
      end -- if lf_print
  		local found_drones = {}
  
  		-- prefer own drones first
  		while #found_drones < num_drones and #(self.drones or empty_table) > 0 do
  			local drone = PickDroneFrom(self, found_drones, dronefilter)
  			if not drone then
  				break
  			end -- not drone
  			table.insert(found_drones, drone)
  		end -- while
  		
  		if lf_print then 
  		  print("Qualfied drones found attached to rocket: ", #found_drones)
  		  print("Actual drones attached to rocket: ", #(self.drones or empty_table)) 
  		end -- if lf_print
  
  		-- sort drone controller list to be closest to rocket
  		local city = self.city or (Cities[self:GetMapID()]) or empty_table
  		local dronecontrollers = city and city.labels and city.labels.DroneControl or empty_table
  		local list = table.copy(dronecontrollers)
  		if lf_print then print("Number of nearby drone controllers: ", #list) end
  		
  		-- remove any Lander Rockets - dont steal drones from other Landers
  		-- except your own
  		for i = #list, 1, -1 do
  		  if IsKindOf(list[i], "LanderRocketBase") and list[i] ~= self then
  		    table.remove(list, i)
  		    if lf_print then print("Removing lander rocket from drone controller list") end
  		  end -- if IsKindOf
  		end -- for i
  		
  		sort_obj = self
  		table.sort(list, SortByDist)
  		-- pick from other drone controllers
  		local idx = 1
  		while #found_drones < num_drones and #list > 0 do
  			local success
        
  			local controller = list[idx]
  			for i = 1, #(controller.drones or "") do
  				local drone = controller.drones[i]
  				-- find any idle drones and check if we've hit max added
  				if #found_drones < num_drones and drone.command == "Idle" and drone:CanBeControlled() and not table.find(found_drones, drone) then
  					table.insert(found_drones, drone)
  					success = true
  				end -- if drone.command
  			end -- for i
  
  			if success then
  				idx = idx + 1
  			else
  				table.remove(list, idx)
  			end -- if success
  			
  			if idx > #list then idx = 1 end
  			Sleep(50) -- give this loop a break
  		end -- while #found_drones
  
  		self.drone_summon_fail = #found_drones < num_drones
  		ObjModified(self)
  		if #found_drones >= num_drones then
  		  if lf_print then print("Successfully found drones: ", #found_drones) end
  			return found_drones
  		else
  		  if lf_print then print(string.format("Failed finding %d drones, only %d found. Trying again.", num_drones, #found_drones)) end
  			Sleep(1000)
  		end -- if #found_drones
  	end -- while self:HasDestination() do
  end  -- function CargoTransporter:BLRexpeditionFindDrones

  
  -- new function
  -- copied from CargoTransporter.lua
  -- just making sure resources are dropped for any rovertype that carries them
  function CargoTransporter:BLRExpeditionLoadRover(rover)
    if lf_print then print("CargoTransporter:BLRExpeditionLoadRover running") end
    if rover then
      if rover == SelectedObj then
        SelectObj()
      end -- if rover
      
      if rover.class == "RCRover" then
        rover.sieged_state = false
      end -- if rover.class
      
      -- drop any onboard resources where they stand
      if IsKindOfClasses(rover, "RCTransport", "RCTerraformer", "RCConstructor", "RCHarvester") then
        rover:ReturnStockpiledResources()
        BLRemptyStockpile(rover)
      end -- if IsKindOfClasses
      
      -- idle any auto mode rovers
      if rover.auto_mode_on then
        rover.auto_mode_on = false
      end -- if rover.auto_mode_on
      
      rover:SetCommand(false)  -- set false here guarantees its not doing a thing and cannot be picked by another controller
      rover:SetHolder(self)
      Sleep(100) -- Give it chance to work   
      rover:SetCommand("Disappear", "keep in holder")
    end -- if rover
  end -- CargoTransporter:BLRExpeditionLoadRover(rover)


  -- new function
  -- for finding closest rovers to the rockets
  function CargoTransporter:BLRexpeditionFindRovers(class, quick_load, amount)
    if lf_print then print("CargoTransporter:BLRexpeditionFindRovers running") end

    local roverfilter = function(unit)
      return (unit.class == class) and (not unit.holder) and ((unit:CanBeControlled() or (quick_load and not unit.holder) or unit.command == "Idle"))
    end -- roverfilter    
    
    local realm = GetRealm(self)
    local list = realm:MapGet("map", class, roverfilter) or empty_table
    if lf_print then print(string.format("BLRexpeditionFindRovers found %d %s rovers. Want: %d", #list, class, amount)) end
    if amount > #list then
      if lf_print then print(string.format("BLRexpeditionFindRovers could not find enough %s rovers.  Trying again.", class)) end
      self.rover_summon_fail = true
      ObjModified(self)
      return nil
    end -- if amount
    self.rover_summon_fail = false
    ObjModified(self)
    local candidates = {}
    for _, unit in ipairs(list) do
      local d = self:GetDist2D(unit)
      table.insert(candidates, {rover = unit, distance = d})
    end
    table.sortby_field(candidates, "distance")
    
    if lf_print then 
      print(string.format("Found %d %s rovers", #candidates, class))
      --ex(candidates, nil, class)
    end -- if lf_print
    
    local rovers = {}
    for i = 1, amount do
      rovers[i] = candidates[i].rover
    end
    return rovers
  end -- CargoTransporter:BLRexpeditionFindRovers(class, quick_load, amount)

  
  -- new function
  -- rewrite from CargoTransporter.lua
  -- modified the filter to only take youth thru middle aged, exclude Child, Senior(if no ForeverYoung tech) and Tourist
  function CargoTransporter:BLRexpeditionGatherCrew(num_crew, label, quick_load)
  	if lf_print then print("CargoTransporter:BLRexpeditionGatherCrew running") end
  
  	-- instead of going through UICity.label, we'll go through each dome in order of distance to rocket
  	-- modified for multi realm
  	label = label or "Colonist"
  	local filterToUse = (ObjectIsInEnvironment(self, "Asteroid") and true) or adultfilter
  	local city = self.city or (Cities[self:GetMapID()]) or empty_table
  	local cityDomes = city and city.labels and city.labels.Community or empty_table  -- using Community here since asteroids have no "Dome" label
  	if lf_print then print(string.format("Found %d Domes to search", #cityDomes)) end
  	
  	-- added destination check to prevent forever stuck cycle
  	-- removed while loop since its just a single pass everytime.
  	if self:HasDestination() then
  	  if lf_print then print("Searching for new crew type: ", label) end
  		local sortedDomes = table.copy(cityDomes)
  		sort_obj = self
  		table.sort(sortedDomes, SortByDist)
      if lf_print then print(string.format("Found %d sortedDomes to search", #sortedDomes)) end
  
  		-- grab colonists from closest domes
  		-- allColonists is all the colonists in the realm city of that specialty
  		local new_crew = {}
  		local allColonists = lf_print and self.city.labels[label] and table.ifilter(self.city.labels[label], filterToUse) or empty_table
  		if lf_print then print(string.format("Found %d Colonists matching filter", #allColonists)) end

  		if lf_print then print("Grabbing colonists") end
  		for i = 1, #sortedDomes do
  			local dome = sortedDomes[i]
  			local dome_colonists = dome.labels[label] and table.ifilter(dome.labels[label], filterToUse) or empty_table
  			if lf_print then print(string.format("Found %d Colonists in %s Dome", #dome_colonists, dome.name or " ")) end
  			for _ = 1, #dome_colonists do
  				if #new_crew < num_crew then
  					local unit = table.rand(dome_colonists, InteractionRand("PickCrew"))
  					table.remove_value(dome_colonists, unit)
  					table.insert(new_crew, unit)
  				else
  				  if lf_print then print("Found enough crew type: ", label) end
  					break
  				end -- if #new_crew
  			end -- for _
  		end -- for i

  
  		self.colonist_summon_fail = num_crew > #new_crew
  		ObjModified(self)
  		if num_crew <= #new_crew or quick_load then
  			local crew = {}
  			while (#new_crew > 0) and (num_crew > #crew) do
  				local unit = table.rand(new_crew, InteractionRand("PickCrew"))
  				table.remove_value(new_crew, unit)
  				table.insert(crew, unit)
  			end -- while o
  			return crew
  		else
  			return {}
  		end -- if num_crew
  	end -- if self:HasDestination()
  	return {} -- return nothing since we have no destination - just in case
  end -- CargoTransporter:BLRexpeditionGatherCrew(num_crew, label, quick_load)


  -- new function
  -- just in case they delete the original as well
  function CargoTransporter:BLRExpeditionLoadCrew(crew)
    for _, unit in pairs(crew) do
      if unit == SelectedObj then
        SelectObj()
      end
      unit:SetDome(false)
      if not unit:IsValidPos() then
        unit:SetPos(self:GetPos())
      end
      unit:SetHolder(self)
      unit:SetCommand("Disappear", "keep in holder")
    end
  end -- CargoTransporter:BLRExpeditionLoadCrew(crew)


  -- new function
  -- copy of ExpeditionGatherPrefabs from Picard-HF4 which no longer exists
  function CargoTransporter:BLRExpeditionGatherPrefabs(num_prefabs, prefab)
  	local city = self.city or MainCity
  	local available_prefabs = city:GetPrefabs(prefab)
  	if available_prefabs >= num_prefabs then
  		return num_prefabs
  	else
  		return available_prefabs
  	end
  end -- CargoTransporter:BLRExpeditionGatherPrefabs(num_prefabs, prefab)


  -- rewrite from CargoTransporter.lua
  -- used to add some code to stop the forever while loop when a rocket launch is cancelled
  local Old_CargoTransporter_Load = CargoTransporter.Load
  function CargoTransporter:Load(manifest, quick_load, transfer_available)
    if not g_BLR_Options.modEnabled or (not IsKindOf(self, "LanderRocketBase")) then return Old_CargoTransporter_Load(self, manifest, quick_load, transfer_available) end -- short circuit
    if lf_print then print("CargoTransporter:Load running") end
    
    self.boarding = {}
    self.departures = {}
    self.cargo = self.cargo or {}
    local SetCargoAmount = function(cargo, class_id, amount)
      if not cargo[class_id] then
        cargo[class_id] = {
          class = class_id,
          requested = 0,
          amount = 0
        }
      end -- if not cargo
      cargo[class_id].amount = cargo[class_id].amount + amount
    end -- local SetCargoAmount
    local succeed, rovers, drones, crew, prefabs = self:Find(manifest, quick_load)
    while not succeed and self:HasDestination() do  -- forever loop now canceled when destination is cancelled
      Sleep(1000)
      succeed, rovers, drones, crew, prefabs = self:Find(manifest, quick_load)
    end -- while
    
    -- if short circuit then dont load anything
    if not self:HasDestination() then
      rovers, drones, crew, prefabs = {}, {}, {}, {}
      rocket.drone_summon_fail = false
      rocket.rover_summon_fail = false
      rocket.prefab_count_fail = false
      rocket.BLR_resIssues = nil
      rocket.BLR_cargoIssues = nil
      rocket.BLR_crewIssues = nil
      rocket.colonist_summon_fail = false
      return rovers, drones, crew, prefabs
    end --  if not self:HasDestination()
    
    -- need to have empty_table here in case of nil
    rovers = rovers or empty_table
    drones = drones or empty_table
    crew = crew or empty_table
    prefabs = prefabs or empty_table
    
    for _, rover in pairs(rovers) do
      self:BLRExpeditionLoadRover(rover)
      SetCargoAmount(self.cargo, rover.class, 1)
    end -- for _

    self:BLRExpeditionLoadDrones(drones, quick_load)
    SetCargoAmount(self.cargo, "Drone", #drones)
    
    self:BLRExpeditionLoadCrew(crew)
    for _, member in pairs(crew) do
      if member.traits.Tourist then
        SetCargoAmount(self.cargo, "Tourist", 1)
      else
        SetCargoAmount(self.cargo, member.specialist, 1)
      end
    end -- for _
    
    for _, prefab in pairs(prefabs) do
      SetCargoAmount(self.cargo, prefab.class, prefab.amount)
      self.city:AddPrefabs(prefab.class, -prefab.amount, false)
    end -- for _
    return rovers, drones, crew, prefabs
  end -- CargoTransporter:Load(manifest, quick_load, transfer_available)


  -- no longer exists anymore after LuaRevision 1009232
  -- rewrite from CargoTransporter.lua
  -- hooking into this function to avoid conflict with choggies Expedition Use Nearest mod
  -- called from CargoTransporter:Load(manifest, quick_load) or LanderRocketBase:Load(manifest, quick_load)
  local Old_CargoTransporter_Find = CargoTransporter.Find
  function CargoTransporter:Find(manifest, quick_load)
    if not g_BLR_Options.modEnabled or (not IsKindOf(self, "LanderRocketBase")) then return Old_CargoTransporter_Find(self, manifest, quick_load) end -- short circuit
    if lf_print then print("CargoTransporter:Find running") end
    
    local rovers = {}
    for rover_type, count in pairs(manifest.rovers) do
      if lf_print then print("Find using BLRExpeditionFindRovers function") end
      local new_rovers = {}
      -- call new function for LanderRocketBase and never call any function if count is zero
      if count > 0 then
        new_rovers = self:BLRexpeditionFindRovers(rover_type, quick_load, count) or empty_table
      end -- if count > 0
      if not quick_load and count > #new_rovers then
        return false
      end
      if #new_rovers > 0 then table.iappend(rovers, new_rovers) end -- dont append empty tables here
    end -- for rover_type
    
    local drones = {}
    if manifest.drones > 0 then
      if lf_print then print("Find using BLRExpeditionFindDrones function") end
      drones = self:BLRexpeditionFindDrones(manifest.drones, quick_load) or empty_table
      
      if not quick_load and #drones < manifest.drones then
        return false
      end -- if not
    end -- if manifest.drones
    
    local crew = {}
    for specialization, count in pairs(manifest.passengers) do
      local new_crew = {}
      if count > 0 then
        if lf_print then print(string.format("Searching for %d %s", count, specialization)) end
        new_crew = self:BLRexpeditionGatherCrew(count, specialization, quick_load) or empty_table
      end -- if count > 0
      if not quick_load and count > #new_crew then
        return false
      end
      if #new_crew > 0 then table.iappend(crew, new_crew) end -- dont append empty tables
    end -- for specialization
    
    local prefabs = {}
    local manifest_prefabs = table.filter(manifest.prefabs, function(k, v)
      return v > 0
    end)
    for prefab, count in pairs(manifest_prefabs) do
      local available_count = self:BLRExpeditionGatherPrefabs(count, prefab)
      if not quick_load and count > available_count then
        self.prefab_count_fail = true
        if lf_print then print("-Counting prefabs failed-") end
        return false
      end
      table.insert(prefabs, {class = prefab, amount = count})
      self.prefab_count_fail = false
      if lf_print then print("-Counting prefabs success-") end
    end -- for prefab
    
    return true, rovers, drones, crew, prefabs
  end -- function CargoTransporter:Find(manifest, quick_load)


  local BLR_defaultRocketCargoPreset = {
    {class = "Drone",        amount = 0},
    {class = "Fuel",         amount = 35},
    {class = "Concrete",     amount = 0},
    {class = "Metals",       amount = 0},
    {class = "Polymers",     amount = 0},
    {class = "MachineParts", amount = 0},
  } -- BLRdefaultRocketCargoPreset
  
  local LanderRocketCargoPreset = LanderRocketCargoPreset or {
    {class = "Drone", amount = 6},
    {class = "Fuel", amount = 35},
    {class = "Concrete", amount = 5},
    {class = "Metals", amount = 15},
    {class = "Polymers", amount = 10},
    {class = "MachineParts", amount = 5}
  } -- LanderRocketCargoPreset

  -- re-write from LanderRocket.lua
  -- LanderRocketCargoPreset is a table from LanderRocketCargoPreset.lua
  local Old_LanderRocketBase_SetDefaultPayload = LanderRocketBase.SetDefaultPayload
  function LanderRocketBase:SetDefaultPayload(payload)
    if not g_BLR_Options.modEnabled and g_BLR_Options.rocketOptions then return Old_LanderRocketBase_SetDefaultPayload(self, payload) end -- short circuit
    if lf_print then print("SetDefaultPayload running") end
    if ObjectIsInEnvironment(self, "Asteroid") then
      if self.drones and #self.drones > 0 then
        payload:SetItem("Drone", #self.drones)
      end -- if self.drones
      return
    end -- if ObjectIsInEnvironment
    if not self.BLR_loadout then self.BLR_loadout = "Remember" end
    if not self.BLR_defaultRocketCargoPreset then self.BLR_defaultRocketCargoPreset = table.copy(BLR_defaultRocketCargoPreset) or empty_table end -- make a local copy on the rocket
    if self.BLR_loadout == "Remember" then
      self.BLR_defaultRocketCargoPreset = table.copy(self.BLR_defaultRocketCargoPreset) or empty_table
    elseif self.BLR_loadout == "Default" then
      self.BLR_defaultRocketCargoPreset = table.copy(LanderRocketCargoPreset) or empty_table
    elseif self.BLR_loadout == "Empty" then
      return
    end --  if self.BLR_loadout
    
    for _, entry in pairs(self.BLR_defaultRocketCargoPreset) do
      payload:SetItem(entry.class, entry.amount)
    end -- for _,
    CargoTransporter.FixCargoToPayloadObject(self, payload)
  end -- LanderRocketBase:SetDefaultPayload(payload)
 
  
  -- new function
  -- sets local default parameters to whats in the rocket at launch from mars
  -- dont take colonists
  function LanderRocketBase:BLRresetDefaultPayload()
    if lf_print then print("BLRresetDefaultPayload running") end
    local cargo = {}
    local specialists = GetSortedColonistSpecializationTable()
    for item, payload in pairs(self.cargo or empty_table) do
      if (payload.amount > 0) and not table.find(specialists, payload.class) then
        cargo[#cargo+1] = {amount = payload.amount, class = payload.class}
      end -- if payload.amount
    end -- for item, payload
    self.BLR_defaultRocketCargoPreset = cargo
    --ex(self.BLRdefaultRocketCargoPreset)
  end -- LanderRocketBase:BLRresetDefaultPayload(payload)
  
  
  -- new function
  -- cannot use DoneObjects in Unload otherwise you get orphaned threads
  function LanderRocketBase:DeleteOnboardDrones()
    local drones = self.drones or empty_table
    for _, drone in ipairs(drones) do
      DeleteThread(drone.thread_running_destructors)
      DeleteThread(drone.command_thread)
      DoneObject(drone)
    end -- for _, drone
    -- do it again to make sure command thread has been killed after any popdestructors
    for _, drone in ipairs(drones) do
      DeleteThread(drone.thread_running_destructors)
      DeleteThread(drone.command_thread)
      DoneObject(drone)
    end -- for _, drone
    --self.drones = {}
  end -- LanderRocketBase:DeleteOnboardDrones()


  -- re-write from LanderRocket.lua
  -- cannot use DoneObjects in Unload otherwise you get orphaned threads
  local Old_LanderRocketBase_Unload = LanderRocketBase.Unload
  function LanderRocketBase:Unload()
    if not g_BLR_Options.modEnabled then return Old_LanderRocketBase_Unload(self) end -- short circuit
    self.stockpiled_amount = {}
    self.cargo = NormalizeCargo(self.cargo)
    self:DeleteOnboardDrones()
    --DoneObjects(self.drones)
    --self.drones = {}
    local specializations = GetSortedColonistSpecializationTable()
    for _, entry in pairs(self.cargo) do
      local classdef = g_Classes[entry.class]
      if IsKindOf(classdef, "BaseRover") and self.rovers or table.find(specializations, entry.class) and self.crew then
        entry.amount = 0
      end
      entry.requested = 0
    end
    RocketBase.Unload(self)
  end -- LanderRocketBase:Unload()
  

  -- rewrite from ResourceOverview.lua
  -- they are using the wrong math
  -- this is in the load cargo screen of the rocket.
  local Old_ResourceOverview_GetAvailable = ResourceOverview.GetAvailable
  function ResourceOverview:GetAvailable(resource_type)
    if not g_BLR_Options.modEnabled then return Old_ResourceOverview_GetAvailable(self, resource_type) end -- short circuit
    if lf_printc then 
      local round = RoundDownResourceAmount(self.data[resource_type])
      print("Resource Amount: ", tostring(self.data[resource_type]), "  Amount: ", round)
    end -- if lf_print
    return RoundDownResourceAmount(self.data[resource_type])
  end -- ResourceOverview:GetAvailable(resource_type)
  
  
  -- I gave the devs the fix and they chose to screw it up even worse, so now I need to fix their double screwup
  -- the below re-writes fix all of it.
  ---------------------------------------------------------------------------------------
  local Old_ResourceOverview_GetProducedYesterday = ResourceOverview.GetProducedYesterday
  function ResourceOverview:GetProducedYesterday(resource_type)
    if not g_BLR_Options.modEnabled then return Old_ResourceOverview_GetProducedYesterday(self, resource_type) end
    return RoundDownResourceAmount(self.city.gathered_resources_yesterday[resource_type] + self.data.produced_resources_yesterday[resource_type])
  end -- ResourceOverview:GetProducedYesterday(resource_type)
  
  local Old_ResourceOverview_GetGatheredYesterday = ResourceOverview.GetGatheredYesterday
  function ResourceOverview:GetGatheredYesterday(resource_type)
    if not g_BLR_Options.modEnabled then return Old_ResourceOverview_GetGatheredYesterday(self, resource_type) end
    return RoundDownResourceAmount(self.city.gathered_resources_yesterday[resource_type])
  end --ResourceOverview:GetGatheredYesterday(resource_type)
  
  local Old_ResourceOverview_GetConsumedByConsumptionYesterday = ResourceOverview.GetConsumedByConsumptionYesterday
  function ResourceOverview:GetConsumedByConsumptionYesterday(resource_type)
    if not g_BLR_Options.modEnabled then return Old_ResourceOverview_GetConsumedByConsumptionYesterday(self, resource_type) end
    return RoundDownResourceAmount(self.city.consumption_resources_consumed_yesterday[resource_type])
  end --ResourceOverview:GetConsumedByConsumptionYesterday(resource_type)
  
  local Old_ResourceOverview_GetConsumedByMaintenanceYesterday = ResourceOverview.GetConsumedByMaintenanceYesterday
  function ResourceOverview:GetConsumedByMaintenanceYesterday(resource_type)
    if not g_BLR_Options.modEnabled then return Old_ResourceOverview_GetConsumedByConsumptionYesterday(self, resource_type) end
    return RoundDownResourceAmount(self.city.maintenance_resources_consumed_yesterday[resource_type])
  end --ResourceOverview:GetConsumedByMaintenanceYesterday(resource_type)
  ---------------------------------------------------------------------------------------

end -- function OnMsg.ClassesGenerate()

------------------------------------------------------------------------------------------------

function OnMsg.RocketLaunched(rocket)
  if g_BLR_Options.modEnabled and IsKindOf(rocket, "LanderRocketBase") then
    
    if not ObjectIsInEnvironment(rocket, "Asteroid") then rocket:BLRresetDefaultPayload() end -- reset payload

  end -- if lander rocket
end -- OnMsg.RocketLaunched(rocket)


function OnMsg.LoadGame()
  BLRfixLanderRockets()
end -- OnMsg.LoadGame()


-- on rocket landing then extend the linger time
function OnMsg.RocketLanded(rocket)
  if IsKindOf(rocket, "LanderRocketBase") and ObjectIsInEnvironment(rocket, "Asteroid") then 
    BLRextendAsteroidTime(rocket)
  end -- if IsKindOf
end -- OnMsg.RocketLanded(rocket)



function OnMsg.SpawnedAsteroid(asteroid)
  -- add variables to newly discover asteroids
  asteroid.BLR_extendedTime = false
end -- OnMsg.SpawnedAsteroid(asteroid)


-- on rocket built on mars disable auto load
function OnMsg.ConstructionComplete(rocket)
  if IsKindOf(rocket, "LanderRocketBase") then rocket.auto_load_enabled = false end
end -- OnMsg.ConstructionComplete(rocket)


function OnMsg.RocketLaunchFromEarth(rocket)
  if IsKindOf(rocket, "LanderRocketBase") then rocket.auto_load_enabled = false end
end -- OnMsg.RocketLaunchFromEarth(rocket)


function OnMsg.ToggleLFPrint(modname, lfvar)
	-- use Msg("ToggleLFPrint", "BLR") to toggle
	if modname == "BLR" then
		if lfvar == "printdebug" then
			 lf_printDebug = not lf_printDebug
		elseif lfvar == "printc" then
		  lf_printc = not lf_printc
		elseif lfvar == "printd" then
		  lf_printc = not lf_printd
		else
			lf_print = not lf_print
		end -- if lfvar
  end -- if
end -- OnMsg.ToggleLFPrint(modname)