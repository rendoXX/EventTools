-- Made by rendoXR, base taken from @Neverless GitHub (https://github.com/OfficialLambdax/BeamMP-ServerScripts/tree/main/RaceOptions)

local M = {}
local speed = 0
local time = {}
local votes = {}
local votedPlayers = {}
local lastDisconnected
local adminDataPath = "Resources/Server/EventTools/admins_data.json"
M.activeTags = {}
M.Admins = {"Admin1", "Admin2", "Admin3", "Admin4"}
M.Commands = {}
M.state = {
	IsRestrictionsEnabled = false,
	CompmodeEnabled = false,
	BlockPartConfigurator = false,
	AdminException = false,
	SpeedLimitation = false,
	SpeedLimitValue = 0,
	CurrentTime = "No time set",
	BeamLingBlocked = false,
	IsFrozen = false,
	BlockVehicleSelector = false,
	HideNames = false
}
M.roles = { -- The player should be added to M.Admins first
	Owner = {"Admin1"},
	Admin = {},
	Moderator = {"Admin2"},
	EventManager = {"Admin3", "Admin4"}
}

local roleHierarchy = {
	EventManager = 1,
	Moderator = 2,
	Admin = 3,
	Owner = 4
}

M.privilegedEventManagers = {"Admin4"} -- The player should be added to M.Admins first

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

function table.contains(tbl, val)
	for _, v in ipairs(tbl) do
		if v == val then return true end
	end
	return false
end

local function tableToLuaString(tbl, indent)
    indent = indent or ""
    local result = "{\n"
    local nextIndent = indent .. "  "
    local isArray = #tbl > 0

    for k, v in pairs(tbl) do
        if not isArray then
            result = result .. nextIndent .. tostring(k) .. " = "
        else
            result = result .. nextIndent
        end

        if type(v) == "table" then
            result = result .. tableToLuaString(v, nextIndent) .. ",\n"
        elseif type(v) == "string" then
            result = result .. string.format("%q", v) .. ",\n"
        else
            result = result .. tostring(v) .. ",\n"
        end
    end

    result = result .. indent .. "}"
    return result
end


---------------------------------------------------------------------------------------------
-- MP Stuff
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
		if M.state.AdminException and M.Admins[player_name] and event_name ~= "restrictions_setTag" and event_name ~= "restrictions_setprefix" and event_name ~= "restrictions_setsuffix" then
		else
			if not self:is_synced(id) and id ~= lastDisconnected then
				print(player_name .. " is not ready yet to receive event data")
			elseif id == lastDisconnected then
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

function isAdminById(player_id)
	local name = MP.GetPlayerName(player_id)
	if not name then return false end
	return M.Admins[name] == true
end

function isAdminByName(name)
	if M.Admins[name] then
		return true
	end
	return false
end

local function getPlayerRole(playerName)
	for role, list in pairs(M.roles) do
		for _, name in ipairs(list) do
			if name:lower() == playerName:lower() then
				return role
			end
		end
	end
	return nil
end

function getPlayerIdByName(name)
    for _, id in pairs(MP.GetPlayers()) do
        if MP.GetPlayerName(id) == name then
            return id
        end
    end
    return nil
end

-- local function loadAdmins()
-- 	local handle = io.open(adminDataPath, "r")
-- 	if handle then
-- 		local content = handle:read("*all")
-- 		handle:close()
-- 		local decoded = Util.JsonDecode(content)
-- 		if decoded then
-- 			M.Admins = decoded.admins or {}
-- 			M.roles = decoded.roles or {}
-- 			M.privilegedEventManagers = decoded.privilegedEventManagers or {}

-- 			return true
-- 		end
-- 	end
-- 	return false
-- end

local function loadAdmins()
	local f = loadfile(adminDataPath)
	if not f then
		print("[ERROR] Failed to load" .. adminDataPath)
		return false
	end

	local ok, decoded = pcall(f)
	if not ok then
		print("[ERROR] Failed to execute" .. adminDataPath .. tostring(decoded))
		return false
	end

	-- decoded is now your admin data table directly
	for _, name in ipairs(decoded.admins or {}) do
		if not table.contains(M.Admins, name) then
			table.insert(M.Admins, name)
		end
	end

	for role, names in pairs(decoded.roles or {}) do
		M.roles[role] = M.roles[role] or {}
		for _, name in ipairs(names) do
			if not table.contains(M.roles[role], name) then
				table.insert(M.roles[role], name)
			end
		end
	end

	for _, name in ipairs(decoded.privilegedEventManagers or {}) do
		if not table.contains(M.privilegedEventManagers, name) then
			table.insert(M.privilegedEventManagers, name)
		end
	end

	return true
end



local function saveAdmins()
	local adminsList = {}
	local privilegedList = {}

	-- Convert M.Admins to list
	if #M.Admins > 0 then
		adminsList = M.Admins
	else
		for name, _ in pairs(M.Admins) do
			table.insert(adminsList, name)
		end
	end

	-- Convert M.privilegedEventManagers to list
	if #M.privilegedEventManagers > 0 then
		privilegedList = M.privilegedEventManagers
	else
		for name, _ in pairs(M.privilegedEventManagers) do
			table.insert(privilegedList, name)
		end
	end

	local data = {
		admins = adminsList,
		roles = M.roles,
		privilegedEventManagers = privilegedList
	}

	local luaString = "return " .. tableToLuaString(data)
	local handle = io.open(adminDataPath, "w")
	if handle then
		handle:write(luaString)
		handle:close()
	else
		print("[ERROR] Failed to open admin JSON file for writing")
	end
end

---------------------------------------------------------------------------------------------
-- Events
function onConsoleInput(cmd)
	onChatMessage(-2, "", cmd, true)
	return ""
end

-- /ropt command
-- or
-- /ropt command status
-- or
-- /ropt command value
-- or
-- /ropt command status player_id
-- or
-- -vote username

function handleVoteCommand(player_id, player_name, message)
    if message:sub(1, 5) ~= "-vote" then return false end
    local args = messageSplit(message)

    -- Check if second argument (the target player name) is missing
    if not args[1] then
        SendChatMessage(player_id, "Usage: -vote PlayerName")
        return true
    end

    local target_name = args[1]
    local target_exists = false

    for id, name in pairs(MP.GetPlayers()) do
        if name == target_name then
            target_exists = true
            break
        end
    end

    if player_name == target_name then
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
	if not M.Admins[player_name] and is_console ~= true then
		SendChatMessage(player_id, "You don't have privileges to use this command.")
		return 1
	end
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
	elseif cmd == "clearchat" or cmd == "results" or cmd == "clearvotes" or cmd == "togglenames" or cmd == "adminlist" then
		M.Commands[cmd]({from_playerid = player_id})
	elseif cmd == "reset" or cmd == "flip" then
		local target_id = tonumber(message[2]) or -1
		M.Commands[cmd]({to_playerid = target_id, from_playerid = player_id})
	elseif cmd == "cleartags" then
		local target_id = tonumber(message[2]) or nil
		if not target_id or target_id and target_id < 0 then
			SendChatMessage(player_id, "Usage: /ropt cleartags playerId")
			return 1
		end
		M.Commands[cmd]({to_playerid = target_id, from_playerid = player_id})
	elseif cmd == "popup" then
		local target_id = tonumber(message[2]) or nil
		local text = table.concat(message, " ", 3)
		if not text or text == "" or not target_id then
			SendChatMessage(player_id, "Usage: /ropt popup playerId message")
			return 1
		end
		M.Commands[cmd]({to_playerid = target_id, from_playername = player_name, text = text})
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
	elseif cmd == "setsuffix" or cmd == "setprefix" then
		local target_id = tonumber(message[2]) or nil
		local tag = (message[3]) or nil
		local r = tonumber(message[4]) or nil
		local g = tonumber(message[5]) or nil
		local b = tonumber(message[6]) or nil
		if (not target_id or not tag or r and not g) or (r and r > 255 or g and g > 255 or b and b > 255) then
			SendChatMessage(player_id, "Usage: /ropt command playerId Tag r g b (r,g,b are color codes and are optional)")
			return 1
		elseif (cmd == "setprefix" and isAdminById(target_id)) or (cmd == "setsuffix" and r and g and b and isAdminById(target_id)) then
			SendChatMessage(player_id, "Administrators are not allowed to use this command on themselves or on any other administrator. You may only use /ropt setsuffix playerId tag (without color codes).")
			return 1
		elseif r and cmd == "setprefix" then -- Delete this `elseif` to allow using RGB prefixes
			SendChatMessage(player_id, "RGB prefixes are currently disabled. You can use RGB suffixes instead.")
			return 1
		end
		if r and g and b then
			M.Commands[cmd]({to_playerid = target_id, from_playerid = player_id, tag = tag, rgb = 1, r=r,g=g,b=b})
		else
			M.Commands[cmd]({to_playerid = target_id, from_playerid = player_id, tag = tag, rgb = 0})
		end
	elseif cmd == "addadmin" or cmd == "removeadmin" then
		local target_name = (message[2]) or nil
		local role = (message[3]) or nil
		if not target_name then
			SendChatMessage(player_id, "Usage: /ropt command player_name role (If no role is assigned, the player won't have a staff tag)")
			return 1
		end
		M.Commands[cmd]({name = target_name, from_playerid = player_id, from_playername = player_name, role = role, isConsole = is_console})
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
	if M.state.CompmodeEnabled then
		TriggerClientEvent:send(player_id, "restrictions_enablePartSelectorOld")
	else
		TriggerClientEvent:send(player_id, "restrictions_disablePartSelectorOld")
	end
	if M.state.BlockPartConfigurator then
		TriggerClientEvent:send(player_id, "restrictions_enablePartSelector")
	else
		TriggerClientEvent:send(player_id, "restrictions_disablePartSelector")
	end
	if M.state.SpeedLimitation then
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
	if M.state.BlockVehicleSelector then
		TriggerClientEvent:send(player_id, "restrictions_enableVehicleSelector")
	else
		TriggerClientEvent:send(player_id, "restrictions_disableVehicleSelector")
	end
	if M.state.HideNames then
		TriggerClientEvent:send(player_id, "restrictions_toggleNames", tostring(M.state.HideNames))
	else
		TriggerClientEvent:send(player_id, "restrictions_toggleNames", tostring(M.state.HideNames))
	end
end

function setTag(player_id, state)
	for id, name in pairs(MP.GetPlayers()) do
		if M.Admins[name] then
			local role = getPlayerRole(name)
			if role then
				local data = id .. "|" .. role .. "|" .. state
				TriggerClientEvent:send(player_id, "restrictions_setTag", data)
			end
		end
	end
end

function onPlayerJoin(player_id)
    TriggerClientEvent:set_synced(player_id)
    setStates(player_id)

	setTag(player_id, 0)

	-- Apply tags if they exist
	for name, tags in pairs(M.activeTags) do
		if tags.prefix then
			local p = tags.prefix
			if p.rgb == 1 then
				local payload = p.tag .. "|" .. p.rgb .. "|" .. p.playerid .. "|" .. p.r .. "|" .. p.g .. "|" .. p.b
				TriggerClientEvent:send(-1, "restrictions_setprefix", payload)
			else
				local payload = p.tag .. "|" .. p.rgb .. "|" .. p.name
				TriggerClientEvent:send(-1, "restrictions_setprefix", payload)
			end
		end

		if tags.suffix then
			local s = tags.suffix
			local payload = s.rgb == 1 and (s.tag .. "|" .. s.rgb .. "|" .. s.playerid .. "|" .. s.r .. "|" .. s.g .. "|" .. s.b) or (s.tag .. "|" .. s.rgb .. "|" .. s.name)
			TriggerClientEvent:send(player_id, "restrictions_setsuffix", payload)
		end
	end

end

function onPlayerDisconnect(player_id)
	TriggerClientEvent:remove(player_id)
	local name = MP.GetPlayerName(player_id)

	if M.activeTags and M.activeTags[name] then
		M.activeTags[name] = nil
	end

	lastDisconnected = player_id
	TriggerClientEvent:send(-1, "restrictions_cleartag", name)
end

function onVehicleSpawn(player_id, vehicle_id, vehicle_data)
	setStates(player_id)
	local player_name = MP.GetPlayerName(player_id)
	if M.state.BeamLingBlocked then
		if M.state.AdminException and M.Admins[player_name] then return end
		if isUnicycle(vehicle_data) then
			SendChatMessage(player_id, 'Unicycles are disabled!')
			return 1 -- deny spawn
		end
	end
		
	if isAdminByName(player_name) then
		setTag(-1, 1)
	end
end

function onVehicleEdited(player_id, vehicle_id, vehicle_data)
	if M.state.BeamLingBlocked then
		local player_name = MP.GetPlayerName(player_id)
		if M.state.AdminException and M.Admins[player_name] then return end
		if isUnicycle(vehicle_data) then
			SendChatMessage(player_id, 'Unicycles are disabled!')
			MP.RemoveVehicle(player_id, vehicle_id)
		end
	end
end

function removeUnicycle()
	for player_id, player_name in pairs(MP.GetPlayers() or {}) do
		if M.state.AdminException and M.Admins[player_name] then
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
	if not loadAdmins() then
		-- Convert list to dict if JSON doesn't exist yet
		local copy = {}
		for _, player_name in ipairs(M.Admins) do
			copy[player_name] = true
		end
		M.Admins = copy
		local copy2 = {}
		for _, player_name in ipairs(M.privilegedEventManagers) do
			copy2[player_name] = true
		end
		M.privilegedEventManagers = copy2
		saveAdmins() -- Save initial state
	else
		local copy = {}
		for _, name in ipairs(M.Admins) do
			copy[name] = true
		end
		M.Admins = copy
		local copy2 = {}
		for _, name in ipairs(M.privilegedEventManagers) do
			copy2[name] = true
		end
		M.privilegedEventManagers = copy2
	end

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
		M.state.CompmodeEnabled = true
		TriggerClientEvent:send(-1, "restrictions_enablePartSelectorOld")
	elseif data.state == "disable" then
		M.state.CompmodeEnabled = false
		TriggerClientEvent:send(-1, "restrictions_disablePartSelectorOld")
	end
end

M.Commands.pcfg = function(data)
	if data.state == "enable" then
		M.state.BlockPartConfigurator = true
		TriggerClientEvent:send(-1, "restrictions_enablePartSelector")
	elseif data.state == "disable" then
		M.state.BlockPartConfigurator = false
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
	M.state.AdminException = not M.state.AdminException
	local state = tostring(M.state.AdminException)
	SendChatMessage(data.from_playerid, "Admin exception state set to: " .. state)
end

M.Commands.sl = function(data)
	if data.state == "enable" then
		M.state.SpeedLimitation = true
		TriggerClientEvent:send(-1, "restrictions_enableSpeedLimit")
	elseif data.state == "disable" then
		M.state.SpeedLimitation = false
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
		M.state.BeamLingBlocked = true
		removeUnicycle()
	elseif data.state == "disable" then
		M.state.BeamLingBlocked = false
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
		M.state.BlockVehicleSelector = true
		TriggerClientEvent:send(-1, "restrictions_enableVehicleSelector")
	elseif data.state == "disable" then
		M.state.BlockVehicleSelector = false
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

M.Commands.setsuffix = function(data)
	local player_name = MP.GetPlayerName(data.to_playerid)
	M.activeTags[player_name] = M.activeTags[player_name] or {}

	local currentSuffix = M.activeTags[player_name].suffix

	-- If tag is already set, block switching between rgb types
	if currentSuffix and currentSuffix.rgb ~= data.rgb then
		SendChatMessage(data.from_playerid, "Cannot switch between RGB and non-RGB suffix for player: " .. player_name)
		return
	end

	if data.rgb == 1 then
		M.activeTags[player_name].suffix = {
			tag = data.tag,
			rgb = 1,
			playerid = data.to_playerid,
			r = data.r,
			g = data.g,
			b = data.b
		}
		local payload = data.tag .. "|" .. data.rgb .. "|" .. data.to_playerid .. "|" .. data.r .. "|" .. data.g .. "|" .. data.b
		TriggerClientEvent:send(-1, "restrictions_setsuffix", payload)
	else
		M.activeTags[player_name].suffix = {
			tag = data.tag,
			rgb = 0,
			name = player_name
		}
		local payload = data.tag .. "|" .. data.rgb .. "|" .. player_name
		TriggerClientEvent:send(-1, "restrictions_setsuffix", payload)
	end
end


M.Commands.setprefix = function(data)
	local player_name = MP.GetPlayerName(data.to_playerid)
	M.activeTags[player_name] = M.activeTags[player_name] or {}

	local currentPrefix = M.activeTags[player_name].prefix
	local currentSuffix = M.activeTags[player_name].suffix

	if currentPrefix and currentPrefix.rgb ~= data.rgb then
		SendChatMessage(data.from_playerid, "Cannot switch between RGB and non-RGB prefix for player: " .. player_name)
		return
	end

	-- Block RGB prefix if RGB suffix is already set
	if data.rgb == 1 and currentSuffix and currentSuffix.rgb == 1 then
		SendChatMessage(data.from_playerid, "Cannot set RGB prefix because RGB suffix is already set for player: " .. player_name)
		return
	end

	if data.rgb == 1 then
		M.activeTags[player_name].prefix = {
			tag = data.tag,
			rgb = 1,
			playerid = data.to_playerid,
			r = data.r,
			g = data.g,
			b = data.b
		}
		local payload = data.tag .. "|" .. data.rgb .. "|" .. data.to_playerid .. "|" .. data.r .. "|" .. data.g .. "|" .. data.b
		TriggerClientEvent:send(-1, "restrictions_setprefix", payload)
	else
		M.activeTags[player_name].prefix = {
			tag = data.tag,
			rgb = 0,
			name = player_name
		}
		local payload = data.tag .. "|" .. data.rgb .. "|" .. player_name
		TriggerClientEvent:send(-1, "restrictions_setprefix", payload)
	end
end

M.Commands.cleartags = function(data)
	local player_name = MP.GetPlayerName(data.to_playerid)
	TriggerClientEvent:send(-1, "restrictions_cleartag", player_name)
	M.activeTags[player_name] = nil
end

M.Commands.togglenames = function(data)
	M.state.HideNames = not M.state.HideNames
	local state = tostring(M.state.HideNames)
	TriggerClientEvent:send(-1, "restrictions_toggleNames", state)
	SendChatMessage(data.from_playerid, "Hide Names state set to: " .. state)
end

M.Commands.popup = function(data)
	TriggerClientEvent:send(data.to_playerid, "restrictions_popup", data.text)
	local player_name = MP.GetPlayerName(data.to_playerid)
	print(data.from_playername .. " sent a popup window to " .. player_name .. " with the message: " .. data.text)
end

M.Commands.addadmin = function(data)
	if not M.Admins[data.name] then
		if data.role and data.role ~= "" then
			if not M.roles[data.role] then
				SendChatMessage(data.from_playerid, "Role '" .. data.role .. "' does not exist.")
				SendChatMessage(data.from_playerid, "=> Available Roles")
				for role, _ in pairs(M.roles) do
					SendChatMessage(data.from_playerid, "-> " .. role)
				end
				return
			end
		end

		local senderRole = getPlayerRole(data.from_playername)
		if not senderRole or senderRole == "EventManager" then
			local isPrivileged = M.privilegedEventManagers[data.from_playername]
			if not isPrivileged and not data.isConsole then
				SendChatMessage(data.from_playerid, "You do not have permission to manage admins.")
				return
			end
		end

		local targetRole = data.role or "EventManager"

		local senderLevel = roleHierarchy[senderRole] or 1
		local targetLevel = roleHierarchy[targetRole] or 1

		if senderLevel < targetLevel and not data.isConsole then
			SendChatMessage(data.from_playerid, "You do not have permission to assign a higher role than your own.")
			return
		end

		M.Admins[data.name] = true
		local roleText = data.role and (" with role - " .. data.role) or ""

		-- Remove from all roles first
		for role, list in pairs(M.roles) do
			for i = #list, 1, -1 do
				if list[i]:lower() == data.name:lower() then
					table.remove(list, i)
				end
			end
		end

		if data.role and data.role ~= "" then
			table.insert(M.roles[data.role], data.name)
		end

		saveAdmins()
		SendChatMessage(data.from_playerid, data.name .. " was added as an admin" .. roleText)
		print(data.from_playername .. " added " .. data.name .. " to administrators" .. roleText)
		TriggerClientEvent:send(-1, "restrictions_cleartag", data.name)
		setTag(-1, 0)
	else
		SendChatMessage(data.from_playerid, data.name .. " is already an admin.")
	end
end

M.Commands.removeadmin = function(data)
	if M.Admins[data.name] then
		local senderRole = getPlayerRole(data.from_playername)
		if not senderRole or senderRole == "EventManager" then
			local isPrivileged = M.privilegedEventManagers[data.from_playername]
			if not isPrivileged and not data.isConsole then
				SendChatMessage(data.from_playerid, "You do not have permission to manage admins.")
				return
			end
		end

		local targetRole = getPlayerRole(data.name) or "EventManager"

		local senderLevel = roleHierarchy[senderRole] or 1
		local targetLevel = roleHierarchy[targetRole] or 1

		if senderLevel < targetLevel and not data.isConsole then
			SendChatMessage(data.from_playerid, "You do not have permission to remove an admin with higher privileges.")
			return
		end

		M.Admins[data.name] = nil

		-- Remove from all roles
		for role, list in pairs(M.roles) do
			for i = #list, 1, -1 do
				if list[i]:lower() == data.name:lower() then
					table.remove(list, i)
				end
			end
		end

		saveAdmins()
		SendChatMessage(data.from_playerid, data.name .. " was removed from admins.")
		print(data.from_playername .. " removed " .. data.name .. " from administrators")
		TriggerClientEvent:send(-1, "restrictions_cleartag", data.name)
	else
		SendChatMessage(data.from_playerid, data.name .. " is not an admin.")
	end
end

M.Commands.adminlist = function(data)
	SendChatMessage(data.from_playerid, "== [Admin List] ==")
	for name, _ in pairs(M.Admins) do
		local role = getPlayerRole(name) or "No role"
		SendChatMessage(data.from_playerid, "  -> " .. name .. " (" .. role .. ")")
	end
end
