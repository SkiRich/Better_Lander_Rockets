-- Code developed for Better Lander Rockets
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- Created Sept 20th, 2021

local lf_print        = false  -- Setup debug printing in local file -- use Msg("ToggleLFPrint", "BLR", "printdebug") to toggle
local lf_printc       = false  -- print for classes that are chatty
local lf_printDebug   = false

local table = table
local ObjModified = ObjModified
local Sleep = Sleep

local StringIdBase = 17764703910 -- Better Lander Rockets    : 703910 - 703919 ** 

-- options for Better Lander Rockets Mod
g_BLR_Options = {
  modEnabled = true
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

-- needed for CargoTransporter:BLRexpeditionFindDrones
local sort_obj
local function SortByDist(a, b)
	return a:GetVisualDist2D(sort_obj) < b:GetVisualDist2D(sort_obj)
end -- SortByDist


------------------------------------------- OnMsgs --------------------------------------------------


function OnMsg.ClassesGenerate()
  
  
  
  -- new function
  -- for finding closest drones to the rockets
  -- cannot use original since choggi has a mod Expeditions use nearest which would not be compatible
  function CargoTransporter:BLRexpeditionFindDrones(num_drones, quick_load)
    if lf_print then print("CargoTransporter:BLRexpeditionFindDrones running") end

    -- filter for ExpeditionPickDroneFrom
    local filter = function(drone)
      return not drone.holder
    end -- filter
    
  	-- wait to have enough drones, load if we are a go, stop if not
  	while self:HasDestination() do
  	  if lf_print then 
  	    print("Destination Set - Running Find Drones")
        print("Drones needed: ", num_drones) 
      end -- if lf_print
  		local found_drones = {}
  
  		-- prefer own drones first
  		while #found_drones < num_drones and #(self.drones or empty_table) > 0 do
  			local drone = ExpeditionPickDroneFrom(self, found_drones, filter)
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
  -- hooking into this function to avoid conflict with choggies Expedition Use Nearest mod
  local Old_CargoTransporter_Find = CargoTransporter.Find
  function CargoTransporter:Find(manifest, quick_load)
    if not g_BLR_Options.modEnabled then return Old_CargoTransporter_Find(self, manifest, quick_load) end -- short circuit
    if lf_print then print("CargoTransporter:Find running") end
    
    local rovers = {}
    for rover_type, count in pairs(manifest.rovers) do
      local new_rovers = self:ExpeditionFindRovers(rover_type, quick_load, count) or empty_table
      if not quick_load and count > #new_rovers then
        return false
      end
      table.iappend(rovers, new_rovers)
    end -- for
    
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
      local new_crew = self:ExpeditionGatherCrew(count, specialization, quick_load) or empty_table
      if not quick_load and count > #new_crew then
        return false
      end
      table.iappend(crew, new_crew)
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