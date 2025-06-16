-- Made by rendoXR, base taken from @Neverless GitHub (https://github.com/OfficialLambdax/BeamMP-ServerScripts/tree/main/RaceOptions)

local M = {}
M.routine1Sec = hptimer()
local compModeState = false
local partSelectorUICheckState = false
local vehicleSelectorUICheckState = false
local speedLimitStatus = false
local lastSpeedLimit = 0
local freezeState = false
local toggleNames = false
local adminTagQueue = false
local adminTagData

local roleDisplayNames = {
	Owner = "Owner",
	Admin = "Administrator",
	Moderator = "Moderator"
}
local roleStyles = {
	Owner =       { back = {r=36, g=112, b=255},  fore = {r=255, g=255, b=255} },
	Admin =       { back = {r=14, g=75, b=239},  fore = {r=255, g=255, b=255} },
	Moderator =   { back = {r=108, g=71, b=228}, fore = {r=255, g=255, b=255} }
}

-- ----------------------------------------------------------------------------
-- Common
local function splitString(inputstr)
    local t = {}
    for str in string.gmatch(inputstr, "([^|]+)") do
        table.insert(t, str)
    end
    return t
end


local function isBeamMPSession()
	if MPCoreNetwork then return MPCoreNetwork.isMPSession() end
	return false
end

local function isOwn(game_vehicle_id)
	if not isBeamMPSession() then return true end
	return MPVehicleGE.isOwn(game_vehicle_id)
end

local function alignToSurfaceZ(pos_vec, max)
	local pos_z = be:getSurfaceHeightBelow(vec3(pos_vec.x, pos_vec.y, pos_vec.z + 2))
	if pos_z < -1e10 then return end -- "the function returns -1e20 when the raycast fails"
	if max and math.abs(pos_vec.z - pos_z) > max then return end
	
	return vec3(pos_vec.x, pos_vec.y, pos_z)
end

local function evalTPPosition(pos_vec, vehicle, factor)
	local new_pos = alignToSurfaceZ(pos_vec, 7)
	if not new_pos then return pos_vec end -- tp pos is in the air
	
	local bounding_box = vehicle:getSpawnWorldOOBB()
	local half_extends = bounding_box:getHalfExtents()
	new_pos = new_pos + vec3(0, 0, half_extends.z / (factor or 4)) -- if this ports the vehicle into the ground when damaged, reduce it to / 3
	
	return new_pos
end

local function convertClockTimeToBeamNGTime(hour, minute)
    -- Convert time to total minutes
    local totalMinutes = hour * 60 + minute

    -- Shift time backwards by 12 hours (720 minutes)
    totalMinutes = (totalMinutes - 12 * 60) % (24 * 60)

    -- Normalize to 0-1 range
    local beamngTime = totalMinutes / (24 * 60)

	if core_environment.setTimeOfDay then
		core_environment.setTimeOfDay({time = beamngTime})
	end
end


-- ----------------------------------------------------------------------------
-- Custom Events
M.enableCompetitiveMode = function()
	extensions.core_input_actionFilter.addAction(0, 'restrictions_competitive', true)
	compModeState = true
end

M.disableCompetitiveMode = function()
	extensions.core_input_actionFilter.addAction(0, 'restrictions_competitive', false)
	compModeState = false
end

M.enablepartselectorold = function()
	core_gamestate.setGameState("multiplayer", "multiplayer", "scenario")
end

M.disablepartselectorold = function()
	core_gamestate.setGameState("multiplayer", "multiplayer", "multiplayer")
end

M.enablepartselector = function()
	partSelectorUICheckState = true
end

M.disablepartselector = function()
	partSelectorUICheckState = false
end

M.setSpeedLimit = function(data)
	if data then
		lastSpeedLimit = data
	end
	be:queueAllObjectLua("if restrictions then restrictions.speedLimitChange(" .. lastSpeedLimit .. ") end")
end

M.enableSpeedLimit = function()
	speedLimitStatus = true
	be:queueAllObjectLua("if restrictions then restrictions.enableSpeedLimit() end")
end

M.disableSpeedLimit = function()
	speedLimitStatus = false
	be:queueAllObjectLua("if restrictions then restrictions.disableSpeedLimit() end")
end

M.flipEnable = function()
	be:queueAllObjectLua("if backflip then backflip.backflipEnable() end")
end



M.resetAllOwnedVehicles = function()
	for _, vehicle in ipairs(getAllVehicles()) do
		if isOwn(vehicle:getId()) then
			local pos_vec = evalTPPosition(vehicle:getPosition(), vehicle, 4)
			vehicle:setPosRot(pos_vec.x, pos_vec.y, pos_vec.z + 0.1, 0, 0, 0, 0)
		end
	end
end

M.setFreezeState = function(state)
	local veh = getPlayerVehicle(0)
	if not veh then return end
	local id = veh and veh:getId()
	local vehicle = getObjectByID(id)

	core_vehicleBridge.executeAction(vehicle, 'setFreeze', state)
end

M.freezeVehicleEnable = function()
	freezeState = true
	M.setFreezeState(true)
end

M.freezeVehicleDisable = function()
	freezeState = false
	M.setFreezeState(false)
end

M.enableVehicleSelector = function()
	vehicleSelectorUICheckState = true
end

M.disableVehicleSelector = function()
	vehicleSelectorUICheckState = false
end

M.setTimeOfTheDay = function(data)
	if data then
		local decoded = type(data) == "string" and jsonDecode(data) or data
		if decoded and decoded.hour and decoded.minute then
			convertClockTimeToBeamNGTime(decoded.hour, decoded.minute)
		end
	end
end

local function setAdminTags()
	local playerId = tonumber(adminTagData[1])
	local role = adminTagData[2]

	local displayName = roleDisplayNames[role]
	local style = roleStyles[role]
	if not displayName or not style then
		print("Missing role info")
		return
	end

	local p = MPVehicleGE.getPlayers()[playerId]
	if p then
		p.nickPrefixes = { "[" .. displayName .. "] " }
		p:setCustomRole({
			backcolor = style.back,
			forecolor = style.fore,
			tag = "",
			shorttag = ""
		})
	else
		print("No player found for ID: " .. tostring(playerId))
	end
end

M.setTag = function(data)
	adminTagData = splitString(data)
	dump(adminTagData)
	local state = tonumber(adminTagData[3])
	if state == 1 then
		adminTagQueue = true
	else
		setAdminTags()
	end
end

M.toggleNames = function(data)
	if data == "true" and not toggleNames then
		MPVehicleGE.toggleNicknames()
		toggleNames = true
		print("Nametags hidden")
	elseif data == "false" and toggleNames then
		MPVehicleGE.toggleNicknames()
		toggleNames = false
		print("Nametags not hidden")
	end
end


M.setsuffix = function(data)
	local a = splitString(data)

	local tag = a[1]
	if tonumber(a[2]) == 1 then
		local r = tonumber(a[4])
		local g = tonumber(a[5])
		local b = tonumber(a[6])
		local player = tonumber(a[3])
		MPVehicleGE.setPlayerRole(player, tag, "", r, g, b)
	else
		local player = a[3]
		MPVehicleGE.setPlayerNickSuffix(player, "EventTools", " [" .. tag .. "]")
	end
end

M.setprefix = function(data)
	local a = splitString(data)

	local tag = a[1]
	if tonumber(a[2]) == 1 then
		local player = tonumber(a[3])
		local p = MPVehicleGE.getPlayers()[player]
		local r = tonumber(a[4])
		local g = tonumber(a[5])
		local b = tonumber(a[6])
		if p then
			p.nickPrefixes = { "[" .. tag .. "] " }
			p:setCustomRole({
				backcolor = {r=r, g=g, b=b},
				forecolor = {r=255, g=255, b=255},
				tag = "",
				shorttag = ""
			})
		end
	else
		local player = a[3]
		MPVehicleGE.setPlayerNickPrefix(player, "EventTools", "[" .. tag .. "]")
	end
end

M.cleartag = function(data)
	local playerName = data
	if not playerName then return end

	local player = MPVehicleGE.getPlayerByName(playerName)
	local playerId = player and player.playerID or nil

	MPVehicleGE.setPlayerNickSuffix(playerName, "EventTools", "")
	MPVehicleGE.setPlayerNickPrefix(playerName, "EventTools", "")

	if playerId then
		MPVehicleGE.clearPlayerRole(playerId)
		local p = MPVehicleGE.getPlayers()[playerId]
		if p then
			p.nickPrefixes = { "" }
		end
	else
		-- Fallback if the player is not spawned yet
		for _, playerData in pairs(MPVehicleGE.getPlayers()) do
			if playerData.name == playerName then
				playerData.nickPrefixes = { "" }
				playerData:setCustomRole({
					backcolor = { r = 000, g = 000, b = 000 },
					forecolor = { r = 255, g = 255, b = 255 },
					tag = "",
					shorttag = ""
				})
			end
		end
	end
end


M.popup = function(data)
	guihooks.trigger('ConfirmationDialogOpen', "Message", data, "OK", "guihooks.trigger('ConfirmationDialogClose', 'Message')")
end


-- ----------------------------------------------------------------------------
-- Game Events
M.onUpdate = function(dt)
	if M.routine1Sec:stop() > 1000 then
		if editor.isEditorActive() then editor.setEditorActive(false) end
		
		M.routine1Sec:stopAndReset()
	end
end

M.onUiChangedState = function(new, old)
  	if new:startswith("menu.vehicleconfig") and partSelectorUICheckState then
    	guihooks.trigger("ChangeState", "play")
	elseif new:startswith("menu.vehicles") and vehicleSelectorUICheckState then
		guihooks.trigger("ChangeState", "play")
	elseif new:startswith("blank") and compModeState then
		core_quickAccess.toggle()
		-- extensions.hook("onHideRadialMenu")
		-- guihooks.trigger("ChangeState", "play")
		-- core_gamestate.setGameState("multiplayer", "multiplayer", "multiplayer", "multiplayer")
		-- core_sounds.setAudioBlur(0)
		-- simTimeAuthority.set(1)
	elseif new:startswith("menu.environment") and compModeState then
		guihooks.trigger("ChangeState", "play")
	end
end

M.onVehicleSpawned = function(vehId)
	if adminTagQueue then
		setAdminTags()
		adminTagQueue = false
	end
end


M.onVehicleResetted = function()
	if speedLimitStatus then
		M.enableSpeedLimit()
		M.setSpeedLimit()
	end
	if freezeState then
		M.freezeVehicleEnable()
	end
end

M.onClientPostStartMission = function()
	if isBeamMPSession() then
		extensions.core_input_actionFilter.setGroup("restrictions_competitive", {"toggleRadialMenuMulti","recover_vehicle","reset_physics","reset_all_physics","recover_vehicle_alt","recover_to_last_road","parts_selector","reload_vehicle","reload_all_vehicles","loadHome","saveHome","dropPlayerAtCamera","dropPlayerAtCameraNoReset","toggleConsoleNG","goto_checkpoint","toggleConsole","nodegrabberAction","nodegrabberGrab","nodegrabberRender","editorToggle","objectEditorToggle","editorSafeModeToggle","pause","slower_motion","faster_motion","toggle_slow_motion","toggleTraffic","toggleAITraffic","forceField","funBoom","funBreak","funExtinguish","funFire","funHinges","funTires","funRandomTire"})
		core_input_actionFilter.addAction(0, "restrictions_competitive", false)
		
		AddEventHandler("restrictions_enableCompetitiveMode", M.enableCompetitiveMode)
		AddEventHandler("restrictions_disableCompetitiveMode", M.disableCompetitiveMode)
		AddEventHandler("restrictions_resetAllOwnedVehicles", M.resetAllOwnedVehicles)
		AddEventHandler("restrictions_enablePartSelectorOld", M.enablepartselectorold)
		AddEventHandler("restrictions_disablePartSelectorOld", M.disablepartselectorold)
		AddEventHandler("restrictions_enablePartSelector", M.enablepartselector)
		AddEventHandler("restrictions_disablePartSelector", M.disablepartselector)
		AddEventHandler("restrictions_setSpeedLimit", M.setSpeedLimit)
		AddEventHandler("restrictions_enableSpeedLimit", M.enableSpeedLimit)
		AddEventHandler("restrictions_disableSpeedLimit", M.disableSpeedLimit)
		AddEventHandler("restrictions_flipEnable", M.flipEnable)
		AddEventHandler("restrictions_freezeVehicleEnable", M.freezeVehicleEnable)
		AddEventHandler("restrictions_freezeVehicleDisable", M.freezeVehicleDisable)
		AddEventHandler("restrictions_enableVehicleSelector", M.enableVehicleSelector)
		AddEventHandler("restrictions_disableVehicleSelector", M.disableVehicleSelector)
		AddEventHandler("restrictions_setTimeOfTheDay", M.setTimeOfTheDay)
		AddEventHandler("restrictions_setTag", M.setTag)
		AddEventHandler("restrictions_setsuffix", M.setsuffix)
		AddEventHandler("restrictions_setprefix", M.setprefix)
		AddEventHandler("restrictions_cleartag", M.cleartag)
		AddEventHandler("restrictions_toggleNames", M.toggleNames)
		AddEventHandler("restrictions_popup", M.popup)
	else
		M.onUpdate = nil
	end
end

M.onWorldReadyState = function(state)
	if state == 2 then
		if isBeamMPSession() and compModeState then		
			extensions.core_input_actionFilter.addAction(0, 'restrictions_competitive', true)
		end
	end
end

return M