-- Made by rendoXR, base taken from @Neverless GitHub (https://github.com/OfficialLambdax/BeamMP-ServerScripts/tree/main/RaceOptions)

local M = {}
M.routine1Sec = hptimer()
local compModeState = false
local partSelectorUICheckState = false
local vehicleSelectorUICheckState = false
local speedLimitStatus = false
local lastSpeedLimit = 0
local lastSetTime = 0
local freezeState = false
local toggleNamesState = false
local adminTagQueue = false
local adminTagData = {}

local roleDisplayNames = {
	Owner = "Owner",
	Admin = "Administrator",
	Moderator = "Moderator",
	EventManager = "Event Manager"
}
local roleStyles = {
	Owner =       { back = {r=36, g=112, b=255},  fore = {r=255, g=255, b=255} },
	Admin =       { back = {r=14, g=75, b=239},  fore = {r=255, g=255, b=255} },
	Moderator =   { back = {r=108, g=71, b=228}, fore = {r=255, g=255, b=255} },
	EventManager ={ back = {r=121, g=66, b=112}, fore = {r=255, g=255, b=255} }
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

local function convertClockTimeToBeamNGTime(hour, minute, state)
    -- Convert time to total minutes
    local totalMinutes = hour * 60 + minute

    -- Shift time backwards by 12 hours (720 minutes)
    totalMinutes = (totalMinutes - 12 * 60) % (24 * 60)

    -- Normalize to 0-1 range
    local beamngTime = totalMinutes / (24 * 60)

	if tonumber(state) == 1 then
		lastSetTime = beamngTime
	else
		lastSetTime = 0
	end
	if core_environment.getTimeOfDay() then
		core_environment.setTimeOfDay({time = beamngTime, play = false})
	end
end


-- ----------------------------------------------------------------------------
-- Custom Events
M.enableCompetitiveMode = function()
	extensions.core_input_actionFilter.addAction(0, 'EventTools_competitive', true)
	compModeState = true
end

M.disableCompetitiveMode = function()
	extensions.core_input_actionFilter.addAction(0, 'EventTools_competitive', false)
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
	be:queueAllObjectLua("if EventTools then EventTools.speedLimitChange(" .. lastSpeedLimit .. ") end")
end

M.enableSpeedLimit = function()
	speedLimitStatus = true
	be:queueAllObjectLua("if EventTools then EventTools.enableSpeedLimit() end")
end

M.disableSpeedLimit = function()
	speedLimitStatus = false
	be:queueAllObjectLua("if EventTools then EventTools.disableSpeedLimit() end")
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
	extensions.core_input_actionFilter.addAction(0, "EventTools_vsel", true)
end

M.disableVehicleSelector = function()
	vehicleSelectorUICheckState = false
	extensions.core_input_actionFilter.addAction(0, "EventTools_vsel", false)
end

M.setTimeOfTheDay = function(data)
	if data then
		local decoded = type(data) == "string" and jsonDecode(data) or data
		if decoded and decoded.hour and decoded.minute and decoded.state then
			convertClockTimeToBeamNGTime(decoded.hour, decoded.minute, decoded.state)
		end
	end
end

local function setAdminTags()
	for _, data in pairs(adminTagData) do
		local playerId = tonumber(data[1])
		local role = data[2]

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
		adminTagData[playerId] = nil
	end
end

M.setTag = function(data)
	local splitData = splitString(data)
	local id = tonumber(splitData[1])
	if id then
		adminTagData[id] = splitData
	else
		return 1
	end
	local state = tonumber(splitData[3])
	if state == 1 then
		adminTagQueue = true
	else
		setAdminTags()
	end
end

M.toggleNames = function(data)
	if data == "true" and not toggleNamesState then
		MPVehicleGE.toggleNicknames()
		toggleNamesState = true
		print("Nametags hidden")
	elseif data == "false" and toggleNamesState then
		MPVehicleGE.toggleNicknames()
		toggleNamesState = false
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

M.printCmd = function(data)
	local fixed = data:gsub("%[%[NL%]%]", "\n")
	guihooks.trigger('ConfirmationDialogOpen', "Info", fixed, "OK", "guihooks.trigger('ConfirmationDialogClose', 'Message')")
end

M.resetchat = function(data)
	be:executeJS('localStorage.removeItem("chatMessages");')
	reloadUI()
end


-- ----------------------------------------------------------------------------
-- Game Events
M.onUpdate = function(dt)
	if M.routine1Sec:stop() > 1000 then
		if editor.isEditorActive() then editor.setEditorActive(false) end
		if lastSetTime ~= 0 and core_environment.getTimeOfDay() and core_environment.getTimeOfDay().time ~= lastSetTime then
			core_environment.setTimeOfDay({time = lastSetTime, play = false})
		end
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

M.onExtensionLoaded = function()
	if isBeamMPSession() then
		extensions.core_input_actionFilter.setGroup("EventTools_competitive", {"vehicledebugMenu","toggleRadialMenuMulti","recover_vehicle","reset_physics","reset_all_physics","recover_vehicle_alt","recover_to_last_road","parts_selector","reload_vehicle","reload_all_vehicles","loadHome","saveHome","dropPlayerAtCamera","dropPlayerAtCameraNoReset","toggleConsoleNG","goto_checkpoint","toggleConsole","nodegrabberAction","nodegrabberGrab","nodegrabberRender","editorToggle","objectEditorToggle","editorSafeModeToggle","pause","slower_motion","faster_motion","toggle_slow_motion","toggleTraffic","toggleAITraffic","forceField","funBoom","funBreak","funExtinguish","funFire","funHinges","funTires","funRandomTire"})
		core_input_actionFilter.addAction(0, "EventTools_competitive", false)
		extensions.core_input_actionFilter.setGroup("EventTools_vsel", {"vehicle_selector"})
		core_input_actionFilter.addAction(0, "EventTools_vsel", false)
		
		AddEventHandler("EventTools_enableCompetitiveMode", M.enableCompetitiveMode)
		AddEventHandler("EventTools_disableCompetitiveMode", M.disableCompetitiveMode)
		AddEventHandler("EventTools_resetAllOwnedVehicles", M.resetAllOwnedVehicles)
		AddEventHandler("EventTools_enablePartSelectorOld", M.enablepartselectorold)
		AddEventHandler("EventTools_disablePartSelectorOld", M.disablepartselectorold)
		AddEventHandler("EventTools_enablePartSelector", M.enablepartselector)
		AddEventHandler("EventTools_disablePartSelector", M.disablepartselector)
		AddEventHandler("EventTools_setSpeedLimit", M.setSpeedLimit)
		AddEventHandler("EventTools_enableSpeedLimit", M.enableSpeedLimit)
		AddEventHandler("EventTools_disableSpeedLimit", M.disableSpeedLimit)
		AddEventHandler("EventTools_flipEnable", M.flipEnable)
		AddEventHandler("EventTools_freezeVehicleEnable", M.freezeVehicleEnable)
		AddEventHandler("EventTools_freezeVehicleDisable", M.freezeVehicleDisable)
		AddEventHandler("EventTools_enableVehicleSelector", M.enableVehicleSelector)
		AddEventHandler("EventTools_disableVehicleSelector", M.disableVehicleSelector)
		AddEventHandler("EventTools_setTimeOfTheDay", M.setTimeOfTheDay)
		AddEventHandler("EventTools_setTag", M.setTag)
		AddEventHandler("EventTools_setsuffix", M.setsuffix)
		AddEventHandler("EventTools_setprefix", M.setprefix)
		AddEventHandler("EventTools_cleartag", M.cleartag)
		AddEventHandler("EventTools_toggleNames", M.toggleNames)
		AddEventHandler("EventTools_popup", M.popup)
		AddEventHandler("EventTools_printcmd", M.printCmd)
		AddEventHandler("EventTools_resetchat", M.resetchat)
	else
		M.onUpdate = nil
	end
end

M.onWorldReadyState = function(state)
	if state == 2 then
		if isBeamMPSession() and compModeState then		
			extensions.core_input_actionFilter.addAction(0, 'EventTools_competitive', true)
		end
		if isBeamMPSession() and vehicleSelectorUICheckState then		
			extensions.core_input_actionFilter.addAction(0, "EventTools_vsel", true)
		end
	end
end

return M