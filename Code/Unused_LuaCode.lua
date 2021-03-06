-- OnAction function replacement since the original xTemplate version is busted
-- replaced by function LanderRocketBase:UIEditPayloadRequest() below
-- from PayloadRequest.lua
local BLRonAction = function(self, host, source)
  local obj = host.parent.context.object
  local cargo = obj.cargo
  local passenger_manifest = host.context.traits_object.approved_per_trait or empty_table
  local set_cargo_request_cb = function()
    obj.target_spot = obj.requested_spot or obj.target_spot
    obj.requested_spot = false
    obj:SetCargoRequest(g_RocketCargo, passenger_manifest)
  end
  local reset_cargo_request_cb = function()
    obj.cargo = cargo
  end
  local requested_cargo = 0
  local requested_passengers = 0
  table.foreachi_value(g_RocketCargo, function(v)
    requested_cargo = requested_cargo + v.amount
  end)
  table.foreach_value(passenger_manifest, function(v)
    requested_passengers = requested_passengers + v
  end)
  CreateRealTimeThread(function()
    local res
    local target_spot = obj.target_spot or obj.requested_spot -- fixed
    if requested_cargo == 0 and requested_passengers == 0 then
      res = WaitPopupNotification("LaunchIssue_CargoEmpty", {}, false, terminal.desktop)
    elseif obj.requested_spot and (requested_passengers > 0) and (not ObjectIsInEnvironment(obj, "Asteroid"))then
      if not obj.requested_spot.asteroid.available then
        res = WaitPopupNotification("LaunchIssue_AsteroidHabitat", {
          number1 = requested_passengers,
          number2 = BuildingTemplates.MicroGHabitat.capacity
        }, false, terminal.desktop)
      elseif requested_passengers > GetAvailableResidences(Cities[target_spot.map]) then -- fixed
        res = WaitPopupNotification("LaunchIssue_AsteroidHabitatRepeat", {
          number1 = requested_passengers,
          number2 = GetAvailableResidences(Cities[obj.requested_spot.map])
        }, false, terminal.desktop)
      end
    end
    if not res or res == 1 then
      set_cargo_request_cb()
    else
      reset_cargo_request_cb()
    end
  end, self)
  CloseDialog("PayloadRequest")
end -- OnAction function replacement BLRonAction


function OnMsg.SpawnedAsteroid(asteroid)
  -- add variables to newly discover asteroids
  asteroid.BLR_extendedTime = false
  

  -- adjust deposits for long linger asteroids
  local deposits   = {}
  local realm      = GetRealmByID(asteroid.map)
  local longlinger = (((asteroid.end_time - asteroid.start_time) + 0.00) / const.Scale.sols) >= 7
  if realm then 
    realm:MapForEach("map", "SubsurfaceDepositPreciousMinerals", function(obj)
      deposits[deposits+1] = obj
    end) -- map for each
    ex(deposits, nil, "deposits")
    ex(realm, nil, "realm")
    ex(asteroid, nil, "asteroid")
  end -- if realm
  if longlinger and #deposits > 0 then
    for i = 1, #deposits do
      if deposits[i].max_amount < (50 * const.ResourceScale) then 
        deposits[i].max_amount = (50 * const.ResourceScale)
        deposits[i].amount = deposits[i].max_amount
      end -- if deposits
    end -- for i
  end -- if longlinger

  
end -- OnMsg.SpawnedAsteroid(asteroid)