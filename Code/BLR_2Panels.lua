-- Code developed for Better Lander Rockets
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- Created Sept 20th, 2021
-- Updated Oct 4th, 2021

local lf_print        = false  -- Setup debug printing in local file -- use Msg("ToggleLFPrint", "BLR", "printdebug") to toggle
local lf_printc       = false  -- print for classes that are chatty
local lf_printDebug   = false


local StringIdBase = 17764706000 -- Better Lander Rockets    : 706000 - 706099  This File Start 40-89, Next: 57
local ModDir   = CurrentModPath
local mod_name = "Better Lander Rockets"
local iconBLRSection  = ModDir.."UI/Icons/BLRSection.png"

-- used to fix rounding errors in stock
local function RoundResourceAmount(r)
  r = r or 0
  r = r / const.ResourceScale
  r = (r - (r % 1)) * const.ResourceScale
  return r
end -- function RoundResourceAmount(r)


-- set rollover text
local function BLRsetRollOverText()
  local texts = {}
  texts[1] = T{StringIdBase + 40, "Loadout is the default cargo request when landing on Mars."}
  texts[2] = T{StringIdBase + 41, "Launch issues shows whats holding up a launch."}
  texts[3] = T{StringIdBase + 42, "Cargo issues are problems wth requested cargo.<newline>Drones rovers and prefabs are considered cargo."}
  texts[4] = T{StringIdBase + 43, "Resource issues are problems with resources on the planet or asteroid."}

  return table.concat(texts, "<newline><left>")
end -- BLRsetRollOverText()


-- function to find any issues with resources on planet when loading
local function BLRfindResourceIssues(rocket)
  local stock = {}
  GatherResourceOverviewData(stock, rocket.city or UICity) -- check the current map

  local cargo = rocket:BuildCargoInfo(rocket.cargo)
  local issues = {}
  for _, payload in pairs(cargo) do
    if payload.requested > 0 and stock[payload.class] and payload.requested > (payload.amount + (RoundResourceAmount(stock[payload.class]))) then 
      issues[#issues+1] = payload.class 
    end -- if payload.requested > 0
  end -- for _, payload 
  if #issues > 0 then return true, T{StringIdBase + 44, "Not Enough"} end
  return false, T{StringIdBase + 45, "None"}
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
      if payload.requested > 0 and (not crew[payload.class]) and payload.requested > payload.amount then issues[#issues+1] = payload.class end
    end -- for _,
    if dest and cargofail then return true, T{StringIdBase + 46, "Cargo missing"} end
    if #issues > 0 then return true, T{StringIdBase + 47, "Cargo Not Loaded"} end -- if #issues
  end -- not rocket:GetCargoLoadingStatus()
  if rocket:GetCargoLoadingStatus() == "loading" then return false, T{StringIdBase + 48, "Cargo requested"} end
  return false, T{StringIdBase + 49, "None"}
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
        return T{StringIdBase + 46, "Not enough drones"}
      elseif dronefail and issues[1].class and rocket.drones and issues[1].requested <= dronesAttached then
        -- find out whats going on with the drones
        for _, drone in ipairs(rocket.drones or empty_table) do
          if drone.command == "Charge" or drone.command == "EmergencyPower" then return T{StringIdBase + 46, "Drones recharging"} end
          if table.find(rocket.drones_entering, drone) or table.find(rocket.drones_exiting, drone) then return T{StringIdBase + 46, "Drones busy"} end
        end -- for _, drone
      end -- if dronefail and issues.class
      return T{StringIdBase + 46, "Drones unavailable"}
    end -- if dronefail and #issues > 0
  end -- not rocket:GetCargoLoadingStatus()

  if rocket:GetCargoLoadingStatus() == "loading" then return T{StringIdBase + 48, "Drones requested"} end
  return T{StringIdBase + 49, "None"}
end -- BLRfindDroneIssues(rocket)

-- function to find any crew issues on the rocket when loading
-- omit cargo, prefabs and rovers
function BLRfindCrewIssues(rocket)
  local manifest = CreateManifest(rocket.cargo)
  local crew     = manifest.passengers
  local cargo    = rocket:BuildCargoInfo(rocket.cargo)
  local issues = {}
  for _, payload in pairs(cargo) do
    if payload.requested > 0 and crew[payload.class] and payload.requested > payload.amount then issues[#issues+1] = payload.class end
  end -- for _,
  if (#issues > 0) and not rocket:GetCargoLoadingStatus() then return true, T{StringIdBase + 50, "Crew missing"} end -- if #issues
  if (#issues > 0) and rocket:GetCargoLoadingStatus() == "loading" then return false, T{StringIdBase + 51, "Crew requested"} end
  return false, T{StringIdBase + 49, "None"}
end -- BLRfindCrewIssues(rocket) 


-- status texts for infopanel section
local function BLRgetStatusTexts(rocket)
  local dest = rocket.target_spot or rocket.requested_spot
  local texts = {}
  local cargoIssue, cargoIssueTxt       = BLRfindCargoIssues(rocket)
  local droneIssueTxt                   = BLRfindDroneIssues(rocket)
  local resourceIssue, resourceIssueTxt = BLRfindResourceIssues(rocket)
  local crewIssue, crewIssueTxt         = BLRfindCrewIssues(rocket)
  texts[1] = T{StringIdBase + 52, "Loadout:<right><loadout>", loadout = rocket.BLR_loadout or "*"}
  texts[2] = T{StringIdBase + 53, "Launch Issues:<right><issues>", issues = rocket:GetLaunchIssue() or "None"}
  texts[3] = T{StringIdBase + 54, "Cargo Issues:<right><issues>", issues = cargoIssueTxt or "*"}
  texts[4] = T{StringIdBase + 54, "Drone Issues:<right><issues>", issues = droneIssueTxt or "*"}
  texts[5] = T{StringIdBase + 55, "Resource Issues:<right><issues>", issues = resourceIssueTxt or "*"}
  texts[6] = T{StringIdBase + 56, "Crew Issues:<right><issues>", issues = crewIssueTxt or "*"}
  
  if cargoIssue and dest then texts[2] = T{StringIdBase + 57, "Launch Issues:<right>Cargo"} end    
  if crewIssue and dest then texts[2] = T{StringIdBase + 58, "Launch Issues:<right>Crew"} end
  if resourceIssue then texts[2] = T{StringIdBase + 59, "Launch Issues:<right>Resources"} end
  if not rocket:HasEnoughFuelToLaunch() then texts[2] = T{StringIdBase + 60, "Launch Issues:<right>Launch Fuel"} end
  
  return table.concat(texts, "<newline><left>")
end -- BLRGetStatusTexts(rocket)

-----------------------------------------------------------------------------------------

function OnMsg.ClassesBuilt()
  local XTemplates = XTemplates
  local ObjModified = ObjModified
  local PlaceObj = PlaceObj
  local BLRSectionID1 = "BLRSection-01"
  local BLRControlVer = "100.2"
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
        "RolloverTitle", T{StringIdBase + 61, "Better Lander Rockets"},
        "RolloverText", BLRsetRollOverText(),
        "RolloverHint", T{StringIdBase + 62, "<right_click>Toggle Loadout"},
        "OnContextUpdate", function(self, context)  
          if not context.BLR_loadout then context.BLR_loadout = "Remember" end
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
                        rocket.BLR_loadout = "Nothing"
                      elseif rocket.BLR_loadout == "Nothing" then
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
              "Text", T{StringIdBase + 63, "Loadout:<newline>Launch Issues:<newline>Cargo Issues:<newline>Drone Issues:<newline>Resource Issues:<newline>Crew Issues:"},
              "OnContextUpdate", function(self, context)
                self:SetText(BLRgetStatusTexts(context))
              end, -- OnContextUpdate
            }),
         }), -- end of idATstatusSection
    


      }) -- End PlaceObject XTemplate
    ) -- table.insert
  end -- if not XT.BLR
  
end -- OnMsg.ClassesBuilt()