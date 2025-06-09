-- Made by rendoXR, base taken from @Neverless GitHub (https://github.com/OfficialLambdax/BeamMP-ServerScripts/tree/main/RaceOptions)

local M = {}
local speed = 0
local time = {}
local votes = {}
local votedPlayers = {}
M.Admins = {"admin1", "admin2"}
M.Commands = {}
M.state = {}
M.state.IsRestrictionsEnabled = false
M.state.IsEnabledCfgOld = false
M.state.IsEnabledCfg = false
M.state.IsAdminException = false
M.state.IsSpeedLimitation = false
M.state.SpeedLimitValue = 0
M.state.CurrentTime = "No time set"
M.state.IsBeamLingBlocked = false
M.state.IsFrozen = false
M.IsEnabledVehicleSelector = false

---------------------------------------------------------------------------------------------
-- Basics
local function messageSplit(message)
	local messageSplit = {}
	local nCount = 0
	for i in string.gmatch(message, "%S+") do
		messageSplit[nCount] = i
		nCount = nCount + 1
	end
	
	return messageSplit
end

local function tableSize(table)
	if type(table) ~= "table" then return 0 end
	local len = 0
	for k, v in pairs(table) do
		len = len + 1
	end
	return len
end

local function sleep(seconds)
	MP.Sleep(math.floor(seconds * 1000))
end

---------------------------------------------------------------------------------------------
-- MP Overwrites
--[[ onPlayerJoin based
	Format
		[players] = table
			["player_id"] = table
				[is_synced] = bool
				[buffer] = table -- unused
]]
local TriggerClientEvent = {}
TriggerClientEvent.players = {}

function TriggerClientEvent:is_synced(player_id)
	return self.players[player_id] or false
end

function TriggerClientEvent:set_synced(player_id)
	self.players[player_id] = true
end

function TriggerClientEvent:remove(player_id)
	self.players[player_id] = nil
end

function TriggerClientEvent:send(player_id, event_name, event_data)
	local send_to = {}
	player_id = tonumber(player_id)

	if player_id ~= -1 then
		table.insert(send_to, player_id)
	else
		for id, _ in pairs(MP.GetPlayers()) do
			table.insert(send_to, id)
		end
	end

	for _, id in pairs(send_to) do
		local player_name = MP.GetPlayerName(id)
		if M.state.IsAdminException and M.Admins[player_name] then
		else
			if not self:is_synced(id) then
				print(player_name .. " is not ready yet to receive event data")
			else
				if type(event_data) == "table" then
					event_data = Util.JsonEncode(event_data)
				end
				MP.TriggerClientEvent(id, event_name, tostring(event_data) or "")
			end
		end
	end
end

function TriggerClientEvent:broadcastExcept(player_id, event_name, event_data)
	for player_id_2, _ in pairs(MP.GetPlayers()) do
		if player_id ~= player_id_2 then
			if not self:is_synced(player_id_2) then
				print(MP.GetPlayerName(player_id_2) .. " is not ready yet to receive event data")
			else
				if type(event_data) == "table" then event_data = Util.JsonEncode(event_data) end
				MP.TriggerClientEvent(player_id_2, event_name, tostring(event_data) or "")			
			end
		end
	end
end

local function SendChatMessage(player_id, message)
	if player_id == -2 then
		print(message)
	else
		MP.SendChatMessage(player_id, message)
	end
end

local function vehicleDataTrim(vehicle_data)
    local start = string.find(vehicle_data, "{")
    return string.sub(vehicle_data, start, -1)
end

local function isUnicycle(vehicle_data)
  vehicle_data = Util.JsonDecode(vehicleDataTrim(vehicle_data))
  return (vehicle_data.jbm or ""):lower() == "unicycle"
end

function isAdmin(playerId)
	local playerBeammpId = MP.GetPlayerIdentifiers(playerId).beammp
	for _, admin in ipairs(M.Admins) do
		if admin == playerBeammpId then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------------------------
-- Events
function onConsoleInput(cmd)
	onChatMessage(-2, "", cmd, true)
end

-- /ropt command
-- or
-- /ropt command player_id

function handleVoteCommand(player_id, player_name, message)
    if message:sub(1, 5) ~= "-vote" then return false end
    local args = messageSplit(message)

    -- Check if second argument (the target player name) is missing
    if not args[1] then
        SendChatMessage(player_id, "Usage: -vote <playername>")
        return true
    end

    local target_name = args[1]:lower()
    local target_exists = false

    for id, name in pairs(MP.GetPlayers()) do
        if name:lower() == target_name then
            target_exists = true
            break
        end
    end

    if player_name:lower() == target_name then
        SendChatMessage(player_id, "You can't vote for yourself, silly.")
        return true
    end

    if not target_exists then
        SendChatMessage(player_id, "Player '" .. target_name .. "' is not in the server.")
        return true
    end

    if votedPlayers[player_id] then
        SendChatMessage(player_id, "You have already voted.")
        return true
    end

    votes[target_name] = (votes[target_name] or 0) + 1
    votedPlayers[player_id] = true

    SendChatMessage(player_id, "You voted for " .. target_name)
    return true
end

function onChatMessage(player_id, player_name, message, is_console)
	if handleVoteCommand(player_id, player_name, message) then return 1 end
	if message:sub(1, 5) ~= "/ropt" then return nil end
	if not M.Admins[player_name] and is_console ~= true then return 1 end
	local message = messageSplit(message)
	if tableSize(message) < 2 then message[1] = "help" end
	
	if message[1]:lower() == "help" then
		SendChatMessage(player_id, "=> Available Commands")
		for cmd, _ in pairs(M.Commands) do
			SendChatMessage(player_id, "-> " .. cmd)
		end
		
		return 1
	end
	
	if M.Commands[message[1]:lower()] == nil then
		SendChatMessage(player_id, "Unknown Command")
		return 1
	end
	
	local cmd = message[1]:lower()

	if cmd == "slset" then
		local speed = tonumber(message[2])
		if not speed then
			SendChatMessage(player_id, "Usage: /ropt slset [speed]")
			return 1
		end
		M.Commands[cmd]({speed = speed, from_playerid = player_id})
	elseif cmd == "clearchat" or cmd == "results" or cmd == "clearvotes" then
		M.Commands[cmd]({from_playerid = player_id})
	elseif cmd == "reset" or cmd == "flip" then
		local target_id = tonumber(message[2]) or -1
		M.Commands[cmd]({to_playerid = target_id, from_playerid = player_id})
	elseif cmd == "freeze" then
		local target_state = (message[2] and message[2]:lower()) or nil
		local target_id = tonumber(message[3]) or -1
		if target_state ~= "disable" and target_state ~= "enable" then
			SendChatMessage(player_id, "Usage: /ropt freeze state (enable, disable) playerId (optional)")
			return 1
		end
		M.Commands[cmd]({state = target_state, to_playerid = target_id, from_playerid = player_id})
	elseif cmd == "settime" then
		local target_time = (message[2] and message[2]:lower()) or nil
		if not target_time or not string.match(target_time, "^%d%d:%d%d$") then
			SendChatMessage(player_id, "Usage: /ropt settime time (e.g. 16:45)")
			return 1
		end
		M.Commands[cmd]({time = target_time, from_playerid = player_id})
	else
		local target_state = (message[2] and message[2]:lower()) or nil
		if cmd ~= "adminx" and cmd ~= "status" and target_state ~= "disable" and target_state ~= "enable" then
			SendChatMessage(player_id, "Usage: /ropt command state (enable, disable)")
			return 1
		end
		M.Commands[cmd]({state = target_state, from_playerid = player_id})
	end
	return 1
end

function setStates(player_id)
	if M.state.IsRestrictionsEnabled then
		TriggerClientEvent:send(player_id, "restrictions_enableCompetitiveMode")
	else
		TriggerClientEvent:send(player_id, "restrictions_disableCompetitiveMode")
	end
	if M.state.IsEnabledCfgOld then
		TriggerClientEvent:send(player_id, "restrictions_enablePartSelectorOld")
	else
		TriggerClientEvent:send(player_id, "restrictions_disablePartSelectorOld")
	end
	if M.state.IsEnabledCfg then
		TriggerClientEvent:send(player_id, "restrictions_enablePartSelector")
	else
		TriggerClientEvent:send(player_id, "restrictions_disablePartSelector")
	end
	if M.state.IsSpeedLimitation then
		TriggerClientEvent:send(player_id, "restrictions_enableSpeedLimit")
	else
		TriggerClientEvent:send(player_id, "restrictions_disableSpeedLimit")
	end

	TriggerClientEvent:send(player_id, "restrictions_setSpeedLimit", speed)
	TriggerClientEvent:send(player_id, "restrictions_setTimeOfTheDay", time)

	if M.state.IsFrozen then
		TriggerClientEvent:send(player_id, "restrictions_freezeVehicleEnable")
	else
		TriggerClientEvent:send(player_id, "restrictions_freezeVehicleDisable")
	end
	if M.state.IsEnabledVehicleSelector then
		TriggerClientEvent:send(player_id, "restrictions_enableVehicleSelector")
	else
		TriggerClientEvent:send(player_id, "restrictions_disableVehicleSelector")
	end
end

function onPlayerJoin(player_id)
	TriggerClientEvent:set_synced(player_id)
	setStates(player_id)
end

function onPlayerDisconnect(player_id)
	TriggerClientEvent:remove(player_id)
end

function onVehicleSpawn(player_id, vehicle_id, vehicle_data)
	setStates(player_id)
	if M.state.IsBeamLingBlocked then
		local player_name = MP.GetPlayerName(player_id)
		if M.state.IsAdminException and M.Admins[player_name] then return end
		if isUnicycle(vehicle_data) then
			SendChatMessage(player_id, 'Unicycles are disabled!')
			return 1 -- deny spawn
		end
	end
end

function onVehicleEdited(player_id, vehicle_id, vehicle_data)
	if M.state.IsBeamLingBlocked then
		local player_name = MP.GetPlayerName(player_id)
		if M.state.IsAdminException and M.Admins[player_name] then return end
		if isUnicycle(vehicle_data) then
			SendChatMessage(player_id, 'Unicycles are disabled!')
			MP.RemoveVehicle(player_id, vehicle_id)
		end
	end
end

function removeUnicycle()
	for player_id, player_name in pairs(MP.GetPlayers() or {}) do
		if M.state.IsAdminException and M.Admins[player_name] then
			-- skip this admin player
		else
			for vehicle_id, vehicle_data in pairs(MP.GetPlayerVehicles(player_id) or {}) do
				if onVehicleSpawn(player_id, vehicle_id, vehicle_data) then
					MP.RemoveVehicle(player_id, vehicle_id)
				end
			end
		end
	end
end

function clearChat()
  local filler = " "
  for i = 1, 20 do -- Send 10 blank messages
    SendChatMessage(-1, filler)
  end
end

---------------------------------------------------------------------------------------------
-- Init
function onInit()
	local copy = {}
	for _, player_name in pairs(M.Admins) do
		copy[player_name] = true
	end
	M.Admins = copy

	MP.RegisterEvent("onChatMessage", "onChatMessage")
	MP.RegisterEvent("onConsoleInput", "onConsoleInput")
	MP.RegisterEvent("onPlayerJoin", "onPlayerJoin")
	MP.RegisterEvent("onPlayerDisconnect", "onPlayerDisconnect")
	MP.RegisterEvent("onVehicleSpawn", "onVehicleSpawn")
	MP.RegisterEvent("onVehicleEdited", "onVehicleEdited")
	
	-- hotreload
	for player_id, _ in pairs(MP.GetPlayers()) do
		onPlayerJoin(player_id)
	end
	print("-----. Restriction Mod loaded .-----")
end


---------------------------------------------------------------------------------------------
-- Commands
M.Commands.restr = function(data)
	if data.state == "enable" then
		M.state.IsRestrictionsEnabled = true
		TriggerClientEvent:send(-1, "restrictions_enableCompetitiveMode")
	elseif data.state == "disable" then
		M.state.IsRestrictionsEnabled = false
		TriggerClientEvent:send(-1, "restrictions_disableCompetitiveMode")
	end
end

M.Commands.reset = function(data)
	TriggerClientEvent:send(data.to_playerid, "restrictions_resetAllOwnedVehicles")
end

M.Commands.compmode = function(data)
	if data.state == "enable" then
		M.state.IsEnabledCfgOld = true
		TriggerClientEvent:send(-1, "restrictions_enablePartSelectorOld")
	elseif data.state == "disable" then
		M.state.IsEnabledCfgOld = false
		TriggerClientEvent:send(-1, "restrictions_disablePartSelectorOld")
	end
end

M.Commands.pcfg = function(data)
	if data.state == "enable" then
		M.state.IsEnabledCfg = true
		TriggerClientEvent:send(-1, "restrictions_enablePartSelector")
	elseif data.state == "disable" then
		M.state.IsEnabledCfg = false
		TriggerClientEvent:send(-1, "restrictions_disablePartSelector")
	end
end

M.Commands.status = function(data)
	SendChatMessage(data.from_playerid, "=> Current States")
	for stateKey, stateValue in pairs(M.state) do
		SendChatMessage(data.from_playerid, tostring(stateKey) .. " -> " .. tostring(stateValue))
	end
end

M.Commands.adminx = function(data)
	M.state.IsAdminException = not M.state.IsAdminException
	local state = tostring(M.state.IsAdminException)
	SendChatMessage(data.from_playerid, "Admin exception state set to: " .. state)
end

M.Commands.sl = function(data)
	if data.state == "enable" then
		M.state.IsSpeedLimitation = true
		TriggerClientEvent:send(-1, "restrictions_enableSpeedLimit")
	elseif data.state == "disable" then
		M.state.IsSpeedLimitation = false
		TriggerClientEvent:send(-1, "restrictions_disableSpeedLimit")
	end
end

M.Commands.slset = function(data)
	speed = data.speed
	M.state.SpeedLimitValue = data.speed
	TriggerClientEvent:send(-1, "restrictions_setSpeedLimit", speed)
end

M.Commands.flip = function(data)
	TriggerClientEvent:send(data.to_playerid, "restrictions_flipEnable")
end

M.Commands.nowalk = function(data)
	if data.state == "enable" then
		M.state.IsBeamLingBlocked = true
		removeUnicycle()
	elseif data.state == "disable" then
		M.state.IsBeamLingBlocked = false
		removeUnicycle()
	end
end

M.Commands.clearchat = function(data)
	clearChat()
end

M.Commands.freeze = function(data)
	if data.state == "enable" then
		M.state.IsFrozen = true
		TriggerClientEvent:send(data.to_playerid, "restrictions_freezeVehicleEnable")
	elseif data.state == "disable" then
		M.state.IsFrozen = false
		TriggerClientEvent:send(data.to_playerid, "restrictions_freezeVehicleDisable")
	end
end

M.Commands.vsel = function(data)
	if data.state == "enable" then
		M.state.IsEnabledVehicleSelector = true
		TriggerClientEvent:send(-1, "restrictions_enableVehicleSelector")
	elseif data.state == "disable" then
		M.state.IsEnabledVehicleSelector = false
		TriggerClientEvent:send(-1, "restrictions_disableVehicleSelector")
	end
end

M.Commands.settime = function(data)
	local hour, minute = data.time:match("^(%d%d):(%d%d)$")
	hour, minute = tonumber(hour), tonumber(minute)
	if not hour or not minute or hour > 23 or minute > 59 then
		SendChatMessage(data.from_playerid or -2, "Invalid time. Use format HH:MM (24h).")
		return
	end
	time = {hour = hour, minute = minute}
	M.state.CurrentTime = data.time
	TriggerClientEvent:send(-1, "restrictions_setTimeOfTheDay", time)
	SendChatMessage(data.from_playerid or -2, "Time of day set to " .. data.time)
end

-- M.Commands.results = function(data)
-- 	local from = data.from_playerid or -1
-- 	SendChatMessage(from, "=> Voting Results:")
-- 	if next(votes) == nil then
-- 		SendChatMessage(from, "No votes yet.")
-- 	else
-- 		for name, count in pairs(votes) do
-- 			SendChatMessage(from, name .. ": " .. count .. " vote(s)")
-- 		end
-- 	end
-- end

M.Commands.results = function(data)
    local from = data.from_playerid or -1
    SendChatMessage(from, "=> Voting Results:")

    if next(votes) == nil then
        SendChatMessage(from, "No votes yet.")
        return
    end

    -- Step 1: Copy votes to a sortable array
    local voteList = {}
    for name, count in pairs(votes) do
        table.insert(voteList, {name = name, count = count})
    end

    -- Step 2: Sort the array by count (descending)
    table.sort(voteList, function(a, b)
        return a.count > b.count
    end)

    -- Step 3: Print sorted results
    for _, entry in ipairs(voteList) do
        SendChatMessage(from, entry.name .. ": " .. entry.count .. " vote(s)")
    end
end

M.Commands.clearvotes = function(data)
	votes = {}
	votedPlayers = {}
	SendChatMessage(data.from_playerid, "Votes have been cleared.")
end
