-- Code developed for Better Lander Rockets
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- Created Sept 20th, 2021
-- Updated Oct 12th, 2021

local lf_print        = false  -- Setup debug printing in local file -- use Msg("ToggleLFPrint", "BLR", "printdebug") to toggle
local lf_printc       = false  -- print for classes that are chatty
local lf_printDebug   = false


local StringIdBase = 17764706000 -- Better Lander Rockets    : 706000 - 706199  This File Start 100-199, 180-199 reserved for texts, Next: 134
local ModDir   = CurrentModPath
local mod_name = "Better Lander Rockets"
local iconBLRSection  = ModDir.."UI/Icons/BLRSection.png"

-- used to fix rounding errors in stock
-- same round down forumla without adding back the 1000's
local function RoundDownResAmtScaled(r)
  r = r or 0
  r = r / const.ResourceScale
  r = (r - (r % 1)) 
  return r
end -- function RoundDownResAmtScaled(r)



-- set rollover text
local function BLRsetRollOverText(rocket)
  local texts = {}
  texts[1] = T{StringIdBase + 100, "<em>Loadout</em> = The default cargo manifest when landing on Mars."}
  texts[2] = T{StringIdBase + 101, "<em>Launch issues</em> =  Show whats holding up a launch."}
  texts[3] = T{StringIdBase + 102, "<em>Cargo issues</em> = Problems with requested cargo. Only drones rovers and prefabs are considered cargo."}
  texts[4] = T{StringIdBase + 103, "<em>Drone issues</em> = Problems with drones."}
  texts[5] = T{StringIdBase + 104, "<em>Resource issues</em> = Problems gathering resources on the planet or asteroid."}
  
  local issues = (rocket and (rocket.BLR_resIssues or rocket.BLR_crewIssues or rocket.BLR_cargoIssues)) or empty_table
  local dest = rocket and (rocket.target_spot or rocket.requested_spot)
  if #issues > 0 then
    local vicinity = (ObjectIsInEnvironment(rocket, "Asteroid") and "On Asteroid: ") or "On Mars: "
    texts[6] = (dest and T{StringIdBase + 105, "<newline><em>Launch Issues Reported:</em>"}) or T{StringIdBase + 106, "<newline><em>Potential Launch Issues:</em>"}
    for i = 1, #issues do
      -- {item = payload.class, requested = payload.requested, onplanet = (RoundDownResAmtScaled(stock[item]) - RocketStock(item)), onrockets = RocketStock(item)}
      texts[i+6] = T{StringIdBase + 179+i, string.format("<em>Item:</em> %s, <em>Requested:</em> %d, <em>%s</em>%d, <em>On Rockets:</em> %d", issues[i].item, issues[i].requested, vicinity, issues[i].onplanet, issues[i].onrockets)}
    end -- for i
  end -- if rocket.BLR_issues
  
  return table.concat(texts, "<newline><left>")
end -- BLRsetRollOverText()


-- function to find any issues with resources on planet when loading
local function BLRfindResourceIssues(rocket)
  local stock = {}
  local rockets = rocket.city.labels.LanderRocketBase or empty_table
  GatherResourceOverviewData(stock, rocket.city or UICity) -- check the current map
  
  -- gather all rockets on the the ground stock
  local function RocketStock(item)
    local total = 0
    for _, r in ipairs(rockets) do
      if r:IsRocketLanded() and r.cargo[item] then total = total + r.cargo[item].amount end
    end -- for _, 
    return total
  end -- RocketStock(item)
  
  local cargo = rocket:BuildCargoInfo(rocket.cargo)
  local issues = {}
  for _, payload in pairs(cargo) do
    local item = payload.class
    --print("Item: ", payload.class, " Ask: ", (payload.requested - payload.amount) , " Planet Stock: ", RoundDownResAmtScaled(stock[item]), "RocketStock: ", RocketStock(item))
    if payload.requested > 0 and stock[item] and payload.requested > payload.amount and
      (payload.requested - payload.amount) > (RoundDownResAmtScaled(stock[item]) - RocketStock(item)) then      
      issues[#issues+1] = {item = payload.class, requested = payload.requested, onplanet = (RoundDownResAmtScaled(stock[item]) - RocketStock(item)), onrockets = RocketStock(item)}
    end -- if payload.requested > 0
  end -- for _, payload 
  if #issues > 0 then
    rocket.BLR_resIssues = issues
    return issues, T{StringIdBase + 107, "Not Enough"}  
  end -- if #issues > 0
  rocket.BLR_resIssues = nil
  return false, T{StringIdBase + 108, "None"}
end -- BLRfindResourceIssues(rocket)


-- function to find any cargo issues on the rocket when loading
-- omit crew
local function BLRfindCargoIssues(rocket)
  local dest = rocket.target_spot or rocket.requested_spot
  local manifest = CreateManifest(rocket.cargo)
  local crew     = manifest.passengers
  local cargo = rocket:BuildCargoInfo(rocket.cargo)
  local issues = {}
  local cargofail = rocket.drone_summon_fail or rocket.rover_summon_fail or rocket.prefab_count_fail  --rocket.colonist_summon_fail
  if not rocket:GetCargoLoadingStatus() then
    for _, payload in pairs(cargo) do
      if payload.requested > 0 and (not crew[payload.class]) and payload.requested > payload.amount then 
        local onplanetcount = (rocket.city.labels[payload.class] and #rocket.city.labels[payload.class]) or 0
        issues[#issues+1] = {item = payload.class, requested = payload.requested, onplanet = onplanetcount, onrockets = 0} 
      end -- if payload
    end -- for _,
    if dest and cargofail then 
      rocket.BLR_cargoIssues = issues
      return issues, T{StringIdBase + 109, "Cargo missing"} 
    end -- if dest
    if #issues > 0 then
      rocket.BLR_cargoIssues = issues
      return issues, T{StringIdBase + 110, "Cargo Not Loaded"} 
    end -- if #issues
  end -- not rocket:GetCargoLoadingStatus()
  rocket.BLR_cargoIssues = nil
  if rocket:GetCargoLoadingStatus() == "loading" then return false, T{StringIdBase + 111, "Cargo requested"} end
  return false, T{StringIdBase + 5108, "None"}
end -- BLRfindCargoIssues(rocket)

-- function to find any drone issues on the rocket when loading
local function BLRfindDroneIssues(rocket)
  local dest = rocket.target_spot or rocket.requested_spot
  local manifest = CreateManifest(rocket.cargo)
  local crew     = manifest.passengers
  local cargo = rocket:BuildCargoInfo(rocket.cargo)
  local issues = {}
  local dronefail = rocket.drone_summon_fail
  
  if not rocket:GetCargoLoadingStatus() then
    for _, payload in pairs(cargo) do
      if payload.class == "Drone" and payload.requested > 0 and payload.requested > payload.amount then issues[#issues+1] = payload end
    end -- for _,
    
    -- only report if a destination set
    if dest and dronefail and #issues > 0 then 
      -- check if on an asteroid and asking for more drones than attached
      local dronesAttached = #rocket.drones or 0
      if dronefail and issues[1].class and issues[1].requested > dronesAttached then 
        return T{StringIdBase + 113, "Not enough drones"}
      elseif dronefail and issues[1].class and rocket.drones and issues[1].requested <= dronesAttached then
        -- find out whats going on with the drones
        for _, drone in ipairs(rocket.drones or empty_table) do
          if drone.command == "Charge" or drone.command == "EmergencyPower" then return T{StringIdBase + 114, "Drones recharging"} end
          if table.find(rocket.drones_entering, drone) or table.find(rocket.drones_exiting, drone) then return T{StringIdBase + 115, "Drones busy"} end
        end -- for _, drone
      end -- if dronefail and issues.class
      return T{StringIdBase + 116, "Drones unavailable"}
    end -- if dronefail and #issues > 0
  end -- not rocket:GetCargoLoadingStatus()

  if rocket:GetCargoLoadingStatus() == "loading" then return T{StringIdBase + 117, "Drones requested"} end
  return T{StringIdBase + 108, "None"}
end -- BLRfindDroneIssues(rocket)

-- function to find any crew issues on the rocket when loading
-- omit cargo, prefabs and rovers
function BLRfindCrewIssues(rocket)
  local manifest = CreateManifest(rocket.cargo)
  local crew     = manifest.passengers
  local cargo    = rocket:BuildCargoInfo(rocket.cargo)
  local issues = {}
  for _, payload in pairs(cargo) do
    if payload.requested > 0 and crew[payload.class] and payload.requested > payload.amount then
      local onplanetcount = (rocket.city.labels[payload.class] and #rocket.city.labels[payload.class]) or 0
      issues[#issues+1] = {item = payload.class, requested = payload.requested, onplanet = onplanetcount, onrockets = 0}
    end -- if payload
  end -- for _,
  if (#issues > 0) and not rocket:GetCargoLoadingStatus() then
    rocket.BLR_crewIssues = issues
    return true, T{StringIdBase + 118, "Crew missing"} 
  end -- if #issues
  rocket.BLR_crewIssues = nil
  if (#issues > 0) and rocket:GetCargoLoadingStatus() == "loading" then return false, T{StringIdBase + 119, "Crew requested"} end
  return false, T{StringIdBase + 120, "None"}
end -- BLRfindCrewIssues(rocket) 


-- status texts for infopanel section
local function BLRgetStatusTexts(rocket)
  local dest = rocket.target_spot or rocket.requested_spot
  local texts = {}
  local cargoIssues, cargoIssueTxt = BLRfindCargoIssues(rocket)
  local droneIssueTxt              = BLRfindDroneIssues(rocket)
  local resIssues, resIssueTxt     = BLRfindResourceIssues(rocket)
  local crewIssues, crewIssueTxt    = BLRfindCrewIssues(rocket)
  texts[1] = T{StringIdBase + 121, "Loadout:<right><loadout>", loadout = rocket.BLR_loadout or "*"}
  texts[2] = T{StringIdBase + 122, "Launch Issues:<right><issues>", issues = rocket:GetLaunchIssue() or "None"}
  texts[3] = T{StringIdBase + 123, "Cargo Issues:<right><issues>", issues = cargoIssueTxt or "*"}
  texts[4] = T{StringIdBase + 124, "Drone Issues:<right><issues>", issues = droneIssueTxt or "*"}
  texts[5] = T{StringIdBase + 125, "Resource Issues:<right><issues>", issues = resIssueTxt or "*"}
  texts[6] = T{StringIdBase + 126, "Crew Issues:<right><issues>", issues = crewIssueTxt or "*"}
  
  if cargoIssues and dest then texts[2] = T{StringIdBase + 127, "Launch Issues:<right>Cargo"} end    
  if crewIssues and dest then texts[2] = T{StringIdBase + 128, "Launch Issues:<right>Crew"} end
  if resIssues then texts[2] = T{StringIdBase + 129, "Launch Issues:<right>Resources"} end
  if not rocket:HasEnoughFuelToLaunch() then texts[2] = T{StringIdBase + 130, "Launch Issues:<right>Launch Fuel"} end
  
  return table.concat(texts, "<newline><left>")
end -- BLRGetStatusTexts(rocket)

-----------------------------------------------------------------------------------------

function OnMsg.ClassesBuilt()
  local XTemplates = XTemplates
  local ObjModified = ObjModified
  local PlaceObj = PlaceObj
  local BLRSectionID1 = "BLRSection-01"
  local BLRControlVer = "120"
  local XT

  if lf_print then print("Loading Classes in BLR_2Panels.lua") end  
  
  -- retro fix versioning in old customLanderRocket[1] template
  XT = XTemplates.customLanderRocket[1]
  if XT.BLR then
    if lf_print then print("Retro Fit Check BLR buttons and panels in customLanderRocket") end
    for i, obj in pairs(XT or empty_table) do
      if type(obj) == "table" and obj.__context_of_kind == "LanderRocketBase" and (
       obj.UniqueID == BLRSectionID1 ) and
       obj.Version ~= BLRControlVer then
        table.remove(XT, i)
        if lf_print then print("Removed old BLR buttons and panels from customLanderRocket") end
        XT.BLR = nil
      end -- if obj
    end -- for each obj
  end -- retro fix versioning  
  
  if not XT.BLR then 
    XT.BLR = true
    local foundsection, idx = table.find_value(XT, "comment", "Requested Payload") -- find the Payload request section
    idx = idx or 1 -- in case we cant find it
    
    -- BLR Section 1
    table.insert(XT, idx,
      PlaceObj("XTemplateTemplate", {
        "UniqueID", BLRSectionID1,
        "Version", BLRControlVer,
        "Id", "idBLRSection",
        "__context_of_kind", "LanderRocketBase",
        "__condition", function (parent, context) return g_BLR_Options.modEnabled and (not context.demolishing) and (not context.destroyed)
        end,
        "__template", "InfopanelSection",
        "Icon", iconBLRSection,
        "Title", T{StringIdBase, "Better Lander Rocket Status"},
        "RolloverTitle", T{StringIdBase + 131, "Better Lander Rockets"},
        "RolloverText", BLRsetRollOverText(),
        "RolloverHint", T{StringIdBase + 132, "<right_click>Toggle Loadout"},
        "OnContextUpdate", function(self, context)  
          if not context.BLR_loadout then context.BLR_loadout = "Remember" end
          self:SetRolloverText(BLRsetRollOverText(context))
        end, -- OnContextUpdate
      },{    
         PlaceObj("XTemplateFunc", {
                  "name", "OnMouseButtonDown(self, pos, button)",
                  "parent", function(parent, context)
                          return parent.parent
                  end,
                  "func", function(self, pos, button)
                    local rocket = self.context
                    if button == "L" then
                      if lf_print then print("Left Button") end
                      --PlayFX("DomeAcceptColonistsChanged", "start", rocket)
                    end -- buton L
                    if button == "R" then
                      if lf_print then print("Right Button") end
                      PlayFX("DomeAcceptColonistsChanged", "start", rocket)
                      if rocket.BLR_loadout == "Remember" then
                        rocket.BLR_loadout = "Default"
                      elseif rocket.BLR_loadout == "Default" then
                        rocket.BLR_loadout = "Empty"
                      elseif rocket.BLR_loadout == "Empty" then
                        rocket.BLR_loadout = "Remember"
                      end -- if rocket.BLR_loadout
                    end -- button R
                    ObjModified(rocket)
                  end -- function
         }),    
         -- Status Section
         PlaceObj('XTemplateWindow', {
           'comment', "Status Section",
          "Id", "idBLRstatusSection",
           "IdNode", true,
           "Margins", box(0, 0, 0, 0),
           "RolloverTemplate", "Rollover",
          },{
            -- Status Text Section
            PlaceObj("XTemplateTemplate", {
              "__template", "InfopanelText",
              "Id", "idBLRstatusText",
              "Margins", box(0, 0, 0, 0),
              "Text", T{StringIdBase + 133, "Loadout:<newline>Launch Issues:<newline>Cargo Issues:<newline>Drone Issues:<newline>Resource Issues:<newline>Crew Issues:"},
              "OnContextUpdate", function(self, context)
                self:SetText(BLRgetStatusTexts(context))
              end, -- OnContextUpdate
            }),
         }), -- end of idATstatusSection
    


      }) -- End PlaceObject XTemplate
    ) -- table.insert
  end -- if not XT.BLR
  
end -- OnMsg.ClassesBuilt()