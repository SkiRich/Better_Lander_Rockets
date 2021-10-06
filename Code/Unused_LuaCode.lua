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