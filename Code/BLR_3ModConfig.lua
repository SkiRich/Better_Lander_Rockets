-- Code developed for Better Lander Rockets
-- Author @SkiRich
-- All rights reserved, duplication and modification prohibited.
-- You may not copy it, package it, or claim it as your own.
-- Created Sept 30th, 2021
-- Updated Oct 7th, 2021

local lf_print = false -- Setup debug printing in local file
                       -- Use if lf_print then print("something") end

local StringIdBase = 17764706000 -- Better Lander Rockets    : 706000 - 706099  This File Start 0-29, Next: 8
local mod_name = "Better Lander Rockets"
local steam_id = "2619013940"
local TableFind  = table.find
local ModConfig_id        = "1542863522"
local ModConfigWaitThread = false
local ModConfigLoaded     = TableFind(ModsLoaded, "steam_id", ModConfig_id) or false


local function WaitForModConfig()
	if (not ModConfigWaitThread) or (not IsValidThread(ModConfigWaitThread)) then
		ModConfigWaitThread = CreateRealTimeThread(function()
	    if lf_print then print(string.format("%s WaitForModConfig Thread Started", mod_name)) end
      local tick = 240  -- (60 seconds) loops to wait before fail and exit thread loop
      while tick > 0 do
        if ModConfigLoaded and ModConfig:IsReady() then
          -- if ModConfig loaded and is in ready state then break out of loop
          if lf_print then print(string.format("%s Found Mod Config", mod_name)) end
          tick = 0
          break
        else
          tick = tick -1
          Sleep(250) -- Sleep 1/4 second
          ModConfigLoaded = TableFind(ModsLoaded, "steam_id", ModConfig_id) or false
        end -- if ModConfigLoaded
      end -- while
      if lf_print then print(string.format("%s WaitForModConfig Thread Continuing", mod_name)) end

      if ModConfigLoaded and ModConfig:IsReady() then
        g_BLR_Options.modEnabled         = ModConfig:Get("Better_Lander", "modEnabled")
        g_BLR_Options.rocketOptions      = ModConfig:Get("Better_Lander", "rocketOptions")
        g_BLR_Options.asteroidExtendTime = ModConfig:Get("Better_Lander", "asteroidExtendTime")

    	  ModLog(string.format("%s detected ModConfig running - Setup Complete", mod_name))
      else
    	  if lf_print then print(string.format("**** %s - Mod Config Never Detected On Load - Using Defaults ****", mod_name)) end
    	  ModLog(string.format("**** %s - Mod Config Never Detected On Load - Using Defaults ****", mod_name))
      end -- end if ModConfigLoaded
      if lf_print then print(string.format("%s WaitForModConfig Thread Ended", mod_name)) end
 		end) -- thread
	else
		if lf_print then print(string.format("%s Error - WaitForModConfig Thread Never Ran", mod_name)) end
		ModLog(string.format("%s Error - WaitForModConfig Thread Never Ran", mod_name))
 	end -- if (not g_FWModConfigWaitThread)
end --WaitForModConfig()


function OnMsg.ModConfigReady()

    -- Register this mod's name and description
    ModConfig:RegisterMod("Better_Lander", -- ID
       T{StringIdBase, "Better Lander Rockets"}, -- Optional display name, defaults to ID
       T{StringIdBase + 1, "Options for Better Lander Rockets"} -- Optional description
    )

    -- g_BLR_Options.modEnabled
    ModConfig:RegisterOption("Better_Lander", "modEnabled", {
        name = T{StringIdBase + 2, "Enable Better Lander Rockets Mod"},
        desc = T{StringIdBase + 3, "Enable mod or disable all functions and fixes and return to game original code."},
        type = "boolean",
        default = true,
        order = 1
    })
    
    -- g_BLR_Options.rocketOptions
    ModConfig:RegisterOption("Better_Lander", "rocketOptions", {
        name = T{StringIdBase + 4, "Enable Rocket options:"},
        desc = T{StringIdBase + 5, "Enable or disable individual rocket options such as Loadout (still keeps all fixes)"},
        type = "boolean",
        default = true,
        order = 2
    })

    -- g_BLR_Options.asteroidExtendTime
    ModConfig:RegisterOption("Better_Lander", "asteroidExtendTime", {
        name = T{StringIdBase + 6, "Add Sols to asteroid on landing:"},
        desc = T{StringIdBase + 7, "The amount of Sols to add to the asteroid linger time upon landing the first rocket."},
        type = "number",
        default = 2,
        min = 0,
        max = 50,
        step = 1,
        order = 3
    })    
    

end -- OnMsg.ModConfigReady()


function OnMsg.ModConfigChanged(mod_id, option_id, value, old_value, token)
    if ModConfigLoaded and (mod_id == "Better_Lander") and (token ~= "reset") then

      -- g_BLR_Options.modEnabled
      if option_id == "modEnabled" then
        g_BLR_Options.modEnabled = value
      end -- g_BLR_Options.modEnabled
      
      -- g_BLR_Options.rocketOptions
      if option_id == "rocketOptions" then
        g_BLR_Options.rocketOptions = value
      end -- g_BLR_Options.rocketOptions    
      
      -- g_BLR_Options.asteroidExtendTime
      if option_id == "asteroidExtendTime" then
        g_BLR_Options.asteroidExtendTime = value
      end -- g_BLR_Options.asteroidExtendTime   
      
    end -- if ModConfigLoaded
end --OnMsg.ModConfigChanged


function OnMsg.CityStart()
  WaitForModConfig()
end -- OnMsg.CityStart()


function OnMsg.LoadGame()
  WaitForModConfig()
end -- OnMsg.LoadGame()


local function SRDailyPopup()
    CreateRealTimeThread(function()
        local params = {
              title = "Non-Author Mod Copy",
               text = "We have detected an illegal copy version of : ".. mod_name .. ". Please uninstall the existing version.",
            choice1 = "Download the Original [Opens in new window]",
            choice2 = "Damn you copycats!",
            choice3 = "I don't care...",
              image = "UI/Messages/death.tga",
              start_minimized = false,
        } -- params
        local choice = WaitPopupNotification(false, params)
        if choice == 1 then
          OpenUrl("https://steamcommunity.com/sharedfiles/filedetails/?id=" .. steam_id, true)
        end -- if statement
    end ) -- CreateRealTimeThread
end -- function end


function OnMsg.NewDay(day)
  if table.find(ModsLoaded, "steam_id", steam_id)~= nil then
    --nothing
  else
    SRDailyPopup()
  end -- SRDailyPopup
end --OnMsg.NewDay(day)