-- Code developed for Better Lander Rockets
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- Created Sept 20th, 2021
-- Updated Oct 4th, 2021

local lf_print        = false  -- Setup debug printing in local file -- use Msg("ToggleLFPrint", "BLR", "printdebug") to toggle
local lf_printc       = false  -- print for classes that are chatty
local lf_printDebug   = false

local mod_name = "Better Lander Rockets"
local table = table
local ObjModified = ObjModified
local Sleep = Sleep

local StringIdBase = 17764706000 -- Better Lander Rockets    : 706000 - 706099  This File Start 90-99, Next: 90

-- options for Better Lander Rockets Mod
g_BLR_Options = {
  modEnabled    = true,
  rocketOptions = true,
}



-- copy of local function from ResourceOverview.lua
-- changed the math so we drop remainders instead of rounding up.
-- rounding up here causes inventory to be wrong when loading rockets
-- so we drop remainders
local function RoundResourceAmount(r)
  r = r or 0
  r = r / const.ResourceScale
  r = (r - (r % 1)) * const.ResourceScale
  return r
end -- function RoundResourceAmount(r)

-- needed for CargoTransporter:BLRexpeditionFindDrones and ExpeditionGatherCrew
local sort_obj
local function SortByDist(a, b)
	return a:GetVisualDist2D(sort_obj) < b:GetVisualDist2D(sort_obj)
end -- SortByDist

-- used in ExpeditionLoadDrones and ExpeditionFindDrones
local dronefilter = function(drone)
  return drone:CanBeControlled() and (not drone.holder)
end -- dronefilter

-- used in ExpeditionGatherCrew
local function adultfilter(_, c)
  local workingSeniors = IsTechResearched("ForeverYoung") and true  -- IsTechResearched returns digit 1 if true so replace it here
	return not (c.traits.Child or c.traits.Tourist or (c.traits.Senior and not workingSeniors)) -- use not workingSeniors here to negate the original not and allow the senior
end -- adultfilter

------------------------------------------- OnMsgs --------------------------------------------------


function OnMsg.ClassesGenerate()

  -- from DroneBase
  -- This use to be DroneBase:CanBeControlled()  but they hosed that with a duplicate function of the same name
  -- So putting  it the mod to see what the hell happens.
  local Old_DroneBase_CanBeControlled = DroneBase.CanBeControlled
  function DroneBase:CanBeControlled()
    if not g_BLR_Options.modEnabled then return Old_DroneBase_CanBeControlled(self) end -- short circuit
    return not self.control_override and self.command ~= "Malfunction" and self.command ~= "Dead" and not self.disappeared and not self:IsShroudedInRubble()
  end -- DroneBase:CanBeControlled()


  -- rewrite from CargoTransporter.lua
  -- intercept this function only for Lander Rockets and make sure drones drop any resources before despawn.
  -- this is so we can select nearby drones faster without the default filter.
  local Old_CargoTransporter_ExpeditionLoadDrones = CargoTransporter.ExpeditionLoadDrones
  function CargoTransporter:ExpeditionLoadDrones(found_drones, quick_load)
    if (not g_BLR_Options.modEnabled) or (not IsKindOf(self, "LanderRocketBase")) then 
      return Old_CargoTransporter_ExpeditionLoadDrones(self, found_drones, quick_load)  -- short circuit
    end -- if not
    if lf_print then print("CargoTransporter:ExpeditionLoadDrones running") end
    
    for idx, d in ipairs(found_drones or empty_table) do
      if not dronefilter(d) then
        d:DropCarriedResource()        -- in case they are delivering something
        d:SetCommand("WaitingCommand") -- have them stop what they are doing
        Sleep(100)                     -- lets give the command a sec to work
        local controller = d.command_center
        d:DespawnNow()
        d = controller.city:CreateDrone()
        d.init_with_command = false
        d:SetCommandCenter(controller)
        found_drones[idx] = d
      end -- if not
    end -- for idx
    
    for _, drone in ipairs(found_drones) do
      if drone == SelectedObj then
        SelectObj()
      end
      drone:SetCommandCenter(false, "do not orphan!")
      drone:SetHolder(self)
      drone:SetCommand("Disappear", "keep in holder")
    end -- for _, drone
  end -- CargoTransporter:ExpeditionLoadDrones(found_drones, quick_load)
  
  
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
  			local drone = ExpeditionPickDroneFrom(self, found_drones, dronefilter)
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
  		for i = #list, 1, -1 do
  		  if IsKindOf(list[i], "LanderRocketBase") then
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
  				if drone.command == "Idle" and #found_drones < num_drones and
  					drone:CanBeControlled() and not table.find(found_drones, drone)
  				then
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


  -- rewrite from CargoTransporter.lua
  -- just making sure resources are dropped for any rovertype that carries them
  local Old_CargoTransporter_ExpeditionLoadRover = CargoTransporter.ExpeditionLoadRover
  function CargoTransporter:ExpeditionLoadRover(rover)
    if not g_BLR_Options.modEnabled then return Old_CargoTransporter_ExpeditionLoadRover(rover) end -- short circuit
    if lf_print then print("CargoTransporter:ExpeditionLoadRover running") end
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
      end -- if IsKindOfClasses
      
      rover:SetHolder(self)
      rover:SetCommand("Disappear", "keep in holder")
    end -- if rover
  end -- CargoTransporter:ExpeditionLoadRover(rover)


  -- new function
  -- for finding closest rovers to the rockets
  function CargoTransporter:BLRexpeditionFindRovers(class, quick_load, amount)
    if lf_print then print("CargoTransporter:BLRexpeditionFindRovers running") end

    local roverfilter = function(unit)
      return (unit.class == class) and (not unit.holder) and ((unit:CanBeControlled() or quick_load or unit.command == "Idle"))
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
    self.rover_summon_fail = nil
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
  	local city = self.city or (Cities[self:GetMapID()]) or empty_table
  	local cityDomes = city and city.labels and city.labels.Dome or empty_table
  	
  	-- added destination check to prevent forever stuck cycle
  	-- removed while loop since its just a single pass everytime.
  	if self:HasDestination() then
  	  if lf_print then print("Searching for new crew type: ", label) end
  		local sortedDomes = table.copy(cityDomes)
  		sort_obj = self
  		table.sort(sortedDomes, SortByDist)
  
  		-- grab colonists from closest domes
  		-- allColonists is all the colonists in the realm city of that specialty
  		local new_crew = {}
  		local allColonists = self.city.labels[label] and table.ifilter(self.city.labels[label], adultfilter) or empty_table
  		local doloop = true -- used for breakout shortcircuit
  		if #allColonists >= num_crew then
  			for i = 1, #sortedDomes do
  			  if not doloop then break end -- short circuit
  				local dome = sortedDomes[i]
  				local dome_colonists = dome.labels[label] and table.ifilter(dome.labels[label], adultfilter) or empty_table
  				for _ = 1, #dome_colonists do
  					if #new_crew < num_crew then
  						local unit = table.rand(dome_colonists, InteractionRand("PickCrew"))
  						table.remove_value(dome_colonists, unit)
  						table.insert(new_crew, unit)
  					else
  					  if lf_print then print("Found enough crew type: ", label) end
  					  doloop = false
  						break
  					end -- if #new_crew
  				end -- for _
  			end -- for i
  		end -- if #allColonistssortedDomes
  
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



  -- rewrite from CargoTransporter.lua
  -- hooking into this function to avoid conflict with choggies Expedition Use Nearest mod
  -- called from CargoTransporter:Load(manifest, quick_load) or LanderRocketBase:Load(manifest, quick_load)
  local Old_CargoTransporter_Find = CargoTransporter.Find
  function CargoTransporter:Find(manifest, quick_load)
    if not g_BLR_Options.modEnabled then return Old_CargoTransporter_Find(self, manifest, quick_load) end -- short circuit
    if lf_print then print("CargoTransporter:Find running") end
    
    local rovers = {}
    for rover_type, count in pairs(manifest.rovers) do
      if lf_print then print("Find using BLRExpeditionFindRovers function") end
      local new_rovers = {}
      -- call new function for LanderRocketBase and never call any function if count is zero
      if IsKindOf(self, "LanderRocketBase") and count > 0 then
        new_rovers = self:BLRexpeditionFindRovers(rover_type, quick_load, count) or empty_table
      elseif count > 0 then
        new_rovers = self:ExpeditionFindRovers(rover_type, quick_load, count) or empty_table
      end -- if IsKindOf
      if not quick_load and count > #new_rovers then
        return false
      end
      if #new_rovers > 0 then table.iappend(rovers, new_rovers) end -- dont append empty tables here
    end -- for rover_type
    
    local drones = {}
    if manifest.drones > 0 then
      
      if IsKindOf(self, "LanderRocketBase") then
        if lf_print then print("Find using BLRExpeditionFindDrones function") end
        drones = self:BLRexpeditionFindDrones(manifest.drones, quick_load)
      else
        if lf_print then print("Find using legacy ExpeditionFindDrones function") end
        drones = self:ExpeditionFindDrones(manifest.drones, quick_load)
      end -- if IsKindOf
      
      if not quick_load and #drones < manifest.drones then
        return false
      end
    end -- if manifest.drones
    
    local crew = {}
    for specialization, count in pairs(manifest.passengers) do
      local new_crew = {}
      if IsKindOf(self, "LanderRocketBase") and count > 0 then
        if lf_print then print("Find using BLRexpeditionGatherCrew function") end
        new_crew = self:BLRexpeditionGatherCrew(count, specialization, quick_load) or empty_table
      elseif count > 0 then
        if lf_print then print("Find using legacy ExpeditionGatherCrew function") end
        new_crew = self:ExpeditionGatherCrew(count, specialization, quick_load) or empty_table
      end -- if IsKindOf
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
      local available_count = self:ExpeditionGatherPrefabs(count, prefab)
      if not quick_load and count > available_count then
        return false
      end
      table.insert(prefabs, {class = prefab, amount = count})
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
      return
    end
    if not self.BLR_loadout then self.BLR_loadout = "Remember" end
    if not self.BLR_defaultRocketCargoPreset then self.BLR_defaultRocketCargoPreset = table.copy(BLR_defaultRocketCargoPreset) or empty_table end -- make a local copy on the rocket
    if self.BLR_loadout == "Remember" then
      self.BLR_defaultRocketCargoPreset = table.copy(self.BLR_defaultRocketCargoPreset) or empty_table
    elseif self.BLR_loadout == "Default" then
      self.BLR_defaultRocketCargoPreset = table.copy(LanderRocketCargoPreset) or empty_table
    elseif self.BLR_loadout == "Nothing" then
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
  

  -- rewrite from ResourceOverview.lua
  -- they are using the wrong math
  local Old_ResourceOverview_GetAvailable = ResourceOverview.GetAvailable
  function ResourceOverview:GetAvailable(resource_type)
    if not g_BLR_Options.modEnabled then return Old_ResourceOverview_GetAvailable(self, resource_type) end -- short circuit
    if lf_printc then 
      local round = RoundResourceAmount(self.data[resource_type])
      print("Resource Amount: ", tostring(self.data[resource_type]), "  Amount: ", round)
    end -- if lf_print
    return RoundResourceAmount(self.data[resource_type])
  end -- ResourceOverview:GetAvailable(resource_type)

end -- function OnMsg.ClassesGenerate()

------------------------------------------------------------------------------------------------

function OnMsg.RocketLaunched(rocket)
  if g_BLR_Options.modEnabled and IsKindOf(rocket, "LanderRocketBase") and (not ObjectIsInEnvironment(rocket, "Asteroid")) then rocket:BLRresetDefaultPayload() end
end -- OnMsg.RocketLaunched(rocket)


function OnMsg.ToggleLFPrint(modname, lfvar)
	-- use Msg("ToggleLFPrint", "BLR") to toggle
	if modname == "BLR" then
		if lfvar == "printdebug" then
			 lf_printDebug = not lf_printDebug
		elseif lfvar == "printc" then
		  lf_printc = not lfprintc
		else
			lf_print = not lf_print
		end -- if lfvar
  end -- if
end -- OnMsg.ToggleLFPrint(modname)