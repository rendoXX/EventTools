-- Made by rendoXR, base taken from @Neverless GitHub (https://github.com/OfficialLambdax/BeamMP-ServerScripts/tree/main/RaceOptions)

local M = {}
local speed = 0
local time = {}
local votes = {}
local votedPlayers = {}
-- local lastDisconnected
local adminDataFolder = "Resources/Server/EventTools/AdminData"
local adminDataFile = "admins.lua"
local adminDataPath = adminDataFolder .. "/" .. adminDataFile
M.activeTags = {}
M.Admins = {"admin1", "admin2", "admin3", "admin4"}
M.Commands = {}
M.Comments = {
	restr = "Disables access to: Environment settings, Radial menu, Part Configurator, and restricts using some of the keybinds.",
	vsel = "Enables or disables access to the Vehicle Selector.",
	startrace = "Starts the race by enabling restrictions and disabling access to vehicle selector and part selector.",
	stoprace = "Stops the race by disabling restrictions.",
	-- compmode = "Disables many features, similar to Scenario Mode. This command is deprecated and not recommended!!!",
	reset = "Resets the vehicle of the specified player. If no playerId is provided, resets all vehicles.",
	status = "Displays the status of all restriction features.",
	adminx = "Toggles admin exception from restrictions. Must be used before applying any restrictions.",
	sl = "Enables or disables the speed limiter.",
	slset = "Sets the speed limit in km/h. Enable the speed limit using /ropt sl enable.",
	flip = "Makes a player's vehicle do a front flip. If playerId is not specified, all vehicles will flip.",
	nowalk = "Prevents players from using BeamLing (unicycle) and removes existing ones.",
	clearchat = "Clears the chat by sending empty messages.",
	freeze = "Freezes the player's vehicle. If playerId is not specified, everyone's vehicle will freeze.",
	help = "Displays a list of all /ropt commands.",
	settime = "Sets the time for all players. If [isLocked] is set to true, players won't be able to change the time.",
	results = "Displays voting results.",
	clearvotes = "Clears all votes.",
	togglenames = "Hides or shows player usernames globally.",
	popup = "Displays a popup window with a message and “OK” button.",
	setprefix = "Adds a tag before a player’s name.", 
	setsuffix = "Adds a tag after the player’s name.",
	removeveh = "Removes all vehicles of the specified player. If playerId is not specified, all vehicles will be removed.",
	addadmin = "Adds a player as an admin. If the role is left empty, the player is granted privileges equivalent to Event Manager, but no visible tag will appear next to their name in-game.",
	removeadmin = "Removes a player from the admin list.", 
	adminlist = "Lists all current admins and their assigned roles.",
	aoc = "Enables Admin Only Chat, preventing regular players from typing in the chat.",
	cleartags = "Clears the tag (prefix or suffix) for the specified player.",
	resetchat = "Clears the chat and resets the UI (to finish the clearing process) for everyone."
}
M.CmdUsage = {
	restr = "/ropt restr [state]",
	vsel = "/ropt vsel [state]",
	startrace = "/ropt startrace",
	stoprace = "/ropt stoprace",
	-- compmode = "/ropt compmode [state]",
	reset = "/ropt reset [player]",
	status = "/ropt status",
	adminx = "/ropt adminx",
	sl = "/ropt sl [state]",
	slset = "/ropt slset [speed]",
	flip = "/ropt flip [player]",
	nowalk = "/ropt nowalk [state]",
	clearchat = "/ropt clearchat",
	freeze = "/ropt freeze [state] [player]",
	help = "/ropt help",
	settime = "/ropt settime [time] [isLocked]",
	results = "/ropt results",
	clearvotes = "/ropt clearvotes",
	togglenames = "/ropt togglenames",
	popup = "/ropt popup [player] [text]",
	setprefix = "/ropt setprefix [player] [Tag] [r] [g] [b]", 
	setsuffix = "/ropt setsuffix [player] [Tag] [r] [g] [b]",
	removeveh = "/ropt removeveh [player]",
	addadmin = "/ropt addadmin [PlayerName] [Role]",
	removeadmin = "/ropt removeadmin [PlayerName]", 
	adminlist = "/ropt adminlist",
	aoc = "/ropt aoc",
	cleartags = "/ropt cleartags [player]",
	resetchat = "/ropt resetchat"
}

M.state = {
	IsRestrictionsEnabled = false,
	-- CompmodeEnabled = false,
	-- BlockPartConfigurator = false,
	AdminException = false,
	SpeedLimitation = false,
	SpeedLimitValue = 0,
	CurrentTime = "No time set",
	BeamLingBlocked = false,
	IsFrozen = false,
	BlockVehicleSelector = false,
	HideNames = false,
	AdminOnlyChat = false
}
M.roles = { -- The player should be added to M.Admins first
	Owner = {"admin1"},
	Admin = {},
	Moderator = {"admin3"},
	EventManager = {"admin4", "admin2"}
}

local roleHierarchy = {
	EventManager = 1,
	Moderator = 2,
	Admin = 3,
	Owner = 4
}
M.privilegedEventManagers = {"admin4", "admin2"} -- The player should be added to M.Admins first

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
		for player_id, _ in pairs(MP.GetPlayers()) do
			table.insert(send_to, player_id)
		end
	end
	for _, player_id in pairs(send_to) do
		local player_name = MP.GetPlayerName(player_id)
		if M.state.AdminException and M.Admins[player_name] and event_name ~= "EventTools_setTag" and event_name ~= "EventTools_setprefix" and event_name ~= "EventTools_setsuffix" then
		else
			if not self:is_synced(player_id) then
				print(MP.GetPlayerName(player_id) .. " is not ready yet to receive event data")
			else
				if type(event_data) == "table" then event_data = Util.JsonEncode(event_data) end
				MP.TriggerClientEvent(player_id, event_name, tostring(event_data) or "")
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

function getPlayerIdByName2(name)
	local idFromName = MP.GetPlayerIDByName(name)
	if idFromName then
		return idFromName
	end
    return nil
end

function sendToAllAdmins(from_playerid, msg)
	if from_playerid ~= -2 then
		SendChatMessage(-2, msg)
	end
	for id = 0, MP.GetPlayerCount() - 1 do
		if id ~= from_playerid and isAdminById(id) then
			SendChatMessage(id, msg)
			break
		end
	end
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

local function ensureFolderExists(path)
	local isWindows = package.config:sub(1,1) == "\\"
	if isWindows then
		os.execute('mkdir "' .. path .. '" >nul 2>&1')
	else
		os.execute('mkdir -p "' .. path .. '" > /dev/null 2>&1')
	end
end

local function loadAdmins()
	local f = loadfile(adminDataPath)
	if not f then
		print("[Warn] Failed to load " .. adminDataFile ..". Trying to create the file...")
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
	-- Ensure directory exists
	ensureFolderExists(adminDataFolder)

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
		print("[ERROR] Failed to open admin file for writing. Make sure this path exist! -> " .. adminDataFolder)
	end
end

function reloadadmindata()
	if loadAdmins() then
		-- convert loaded data to dictionary form
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
		print("Admin data successfully reloaded.")
	else
		print("Failed to reload admin data.")
	end
end

---------------------------------------------------------------------------------------------
-- Events
function onConsoleInput(cmd)
	if not cmd or cmd == "" then return end

	if cmd:sub(1, 5) == "/ropt" then
		onChatMessage(-2, "", cmd, true)
		return "[CommandExecuted]"
	end
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
	if M.state.AdminOnlyChat and not M.Admins[player_name] then
		return 1
	end
	if message:sub(1, 5) ~= "/ropt" then return nil end
	if not M.Admins[player_name] and is_console ~= true then
		SendChatMessage(player_id, "You don't have privileges to use this command.")
		return 1
	end
	local message = messageSplit(message)
	if tableSize(message) < 2 then message[1] = "help" end

	if message[1]:lower() == "help" then
		if is_console == true then
			SendChatMessage(player_id, "=> Available Commands")
			for cmd, _ in pairs(M.Commands) do
				SendChatMessage(player_id, "-> " .. cmd)
			end
		else
			local COMMANDS_PER_POPUP = 7
			local commandList = {}
			for cmd, _ in pairs(M.Commands) do
				local entry = tostring(cmd) .. "\n"
				entry = entry .. "Usage: " .. tostring(M.CmdUsage[cmd] or "No Information") .. "\n"
				entry = entry .. "Comments: " .. tostring(M.Comments[cmd] or "No Information") .. "\n"
				entry = entry .. "------------------------------------------------------------------\n\n"
				table.insert(commandList, entry)
			end

			local popupChunks = {}
			local buffer = ""
			local counter = 0

			for i, entry in ipairs(commandList) do
				buffer = buffer .. entry
				counter = counter + 1
				if counter >= COMMANDS_PER_POPUP then
					table.insert(popupChunks, buffer)
					buffer = ""
					counter = 0
				end
			end

			if buffer ~= "" then
				table.insert(popupChunks, buffer)  -- final chunk if any left
			end

			for _, chunk in ipairs(popupChunks) do
				local popupdata = chunk:gsub("\n", "[[NL]]")
				TriggerClientEvent:send(player_id, "EventTools_printcmd", popupdata)
			end
		end
		return 1
	end
	if message[1]:lower() == "reloadadmindata" and is_console == true then
		reloadadmindata()
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
	elseif cmd == "clearchat" or cmd == "resetchat" or cmd == "results" or cmd == "clearvotes" or cmd == "togglenames" or cmd == "adminlist" or cmd == "startrace" or cmd == "stoprace" or cmd == "adminx" or cmd == "aoc" or cmd == "status" then
		M.Commands[cmd]({from_playerid = player_id, from_playername = player_name, isConsole = is_console})
	elseif cmd == "reset" or cmd == "flip" or cmd == "removeveh" then
		local target_id = tonumber(message[2]) or -1
		if target_id == -1 and message[2] then
			local id = getPlayerIdByName2(message[2])
			if id and id >= 0 then
				target_id = id
			else
				SendChatMessage(player_id, "A player with the given username isn't in the server")
				return 1
			end
		end
		M.Commands[cmd]({to_playerid = target_id, from_playerid = player_id})
	elseif cmd == "cleartags" then
		local target_id = tonumber(message[2]) or nil
		if not target_id and message[2] then
			local id = getPlayerIdByName2(message[2])
			if id and id >= 0 then
				target_id = id
			else
				SendChatMessage(player_id, "A player with the given username isn't in the server")
				return 1
			end
		end
		if not target_id or target_id and target_id < 0 then
			SendChatMessage(player_id, "Usage: /ropt cleartags playerId")
			return 1
		end
		M.Commands[cmd]({to_playerid = target_id, from_playerid = player_id})
	elseif cmd == "popup" then
		local target_id = tonumber(message[2]) or nil
		if not target_id and message[2] then
			local id = getPlayerIdByName2(message[2])
			if id and id >= 0 then
				target_id = id
			else
				SendChatMessage(player_id, "A player with the given username isn't in the server")
				return 1
			end
		end
		local text = table.concat(message, " ", 3)
		if not text or text == "" or not target_id then
			SendChatMessage(player_id, "Usage: /ropt popup playerId message")
			return 1
		end
		M.Commands[cmd]({to_playerid = target_id, from_playerid = player_id, from_playername = player_name, text = text})
	elseif cmd == "freeze" then
		local target_state = (message[2] and message[2]:lower()) or nil
		local target_id = tonumber(message[3]) or -1
		if target_id == -1 and message[3] then
			local id = getPlayerIdByName2(message[3])
			if id and id >= 0 then
				target_id = id
			else
				SendChatMessage(player_id, "A player with the given username isn't in the server")
				return 1
			end
		end
		if target_state ~= "disable" and target_state ~= "enable" then
			SendChatMessage(player_id, "Usage: /ropt freeze state (enable, disable) playerId (optional)")
			return 1
		end
		M.Commands[cmd]({state = target_state, to_playerid = target_id, from_playerid = player_id})
	elseif cmd == "settime" then
		local target_time = (message[2] and message[2]:lower()) or nil
		local isLocked = (message[3] and (message[3]:lower() == "true" or message[3] == "1")) and 1 or 0
		if not target_time or not string.match(target_time, "^%d%d:%d%d$") then
			SendChatMessage(player_id, "Usage: /ropt settime time (e.g. 16:45) [isLocked?] (true or false)")
			return 1
		end
		M.Commands[cmd]({time = target_time, from_playerid = player_id, state = isLocked})
	elseif cmd == "setsuffix" or cmd == "setprefix" then
		local target_id = tonumber(message[2]) or nil
		if not target_id and message[2] then
			local id = getPlayerIdByName2(message[2])
			if id and id >= 0 then
				target_id = id
			else
				SendChatMessage(player_id, "A player with the given username isn't in the server")
				return 1
			end
		end
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
		if target_state ~= "disable" and target_state ~= "enable" then
			SendChatMessage(player_id, "Usage: /ropt command state (enable, disable)")
			return 1
		end
		M.Commands[cmd]({state = target_state, from_playerid = player_id})
	end
	return 1
end


function setStates(player_id)
	print("IS HERE!!!")
	if M.state.IsRestrictionsEnabled then
		TriggerClientEvent:send(player_id, "EventTools_enableCompetitiveMode")
		TriggerClientEvent:send(player_id, "EventTools_enablePartSelector") -- Merged from M.Commands.pcfg
	else
		TriggerClientEvent:send(player_id, "EventTools_disableCompetitiveMode")
		TriggerClientEvent:send(player_id, "EventTools_disablePartSelector") -- Merged from M.Commands.pcfg
	end
	-- if M.state.CompmodeEnabled then
	-- 	TriggerClientEvent:send(player_id, "EventTools_enablePartSelectorOld")
	-- end
	-- if M.state.BlockPartConfigurator then
	-- 	TriggerClientEvent:send(player_id, "EventTools_enablePartSelector")
	-- else
	-- 	TriggerClientEvent:send(player_id, "EventTools_disablePartSelector")
	-- end
	if M.state.SpeedLimitation then
		TriggerClientEvent:send(player_id, "EventTools_enableSpeedLimit")
	else
		TriggerClientEvent:send(player_id, "EventTools_disableSpeedLimit")
	end

	TriggerClientEvent:send(player_id, "EventTools_setSpeedLimit", speed)

	if time.state == 1 then
		print(time)
		TriggerClientEvent:send(player_id, "EventTools_setTimeOfTheDay", time)
	end

	if M.state.IsFrozen then
		TriggerClientEvent:send(player_id, "EventTools_freezeVehicleEnable")
	else
		TriggerClientEvent:send(player_id, "EventTools_freezeVehicleDisable")
	end
	if M.state.BlockVehicleSelector then
		TriggerClientEvent:send(player_id, "EventTools_enableVehicleSelector")
	else
		TriggerClientEvent:send(player_id, "EventTools_disableVehicleSelector")
	end
	if M.state.HideNames then
		TriggerClientEvent:send(player_id, "EventTools_toggleNames", tostring(M.state.HideNames))
	else
		TriggerClientEvent:send(player_id, "EventTools_toggleNames", tostring(M.state.HideNames))
	end
end

function setTag(player_id, state)
	for id, name in pairs(MP.GetPlayers()) do
		if M.Admins[name] then
			local role = getPlayerRole(name)
			if role then
				local data = id .. "|" .. role .. "|" .. state
				TriggerClientEvent:send(player_id, "EventTools_setTag", data)
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
				TriggerClientEvent:send(-1, "EventTools_setprefix", payload)
			else
				local payload = p.tag .. "|" .. p.rgb .. "|" .. p.name
				TriggerClientEvent:send(-1, "EventTools_setprefix", payload)
			end
		end

		if tags.suffix then
			local s = tags.suffix
			local payload = s.rgb == 1 and (s.tag .. "|" .. s.rgb .. "|" .. s.playerid .. "|" .. s.r .. "|" .. s.g .. "|" .. s.b) or (s.tag .. "|" .. s.rgb .. "|" .. s.name)
			TriggerClientEvent:send(player_id, "EventTools_setsuffix", payload)
		end
	end

end

function onPlayerDisconnect(player_id)
	TriggerClientEvent:remove(player_id)
	local name = MP.GetPlayerName(player_id)

	if M.activeTags and M.activeTags[name] then
		M.activeTags[name] = nil
	end

	-- lastDisconnected = player_id
	TriggerClientEvent:send(-1, "EventTools_cleartag", name)
end

function onVehicleSpawn(player_id, vehicle_id, vehicle_data)
	local player_name = MP.GetPlayerName(player_id)

	if isAdminByName(player_name) then
		setTag(-1, 1)
	end

	if M.state.BeamLingBlocked then
		if M.state.AdminException and M.Admins[player_name] then return end
		if isUnicycle(vehicle_data) then
			SendChatMessage(player_id, 'Unicycles are disabled!')
			return 1 -- deny spawn
		end
	end

	setStates(player_id)
end

function onVehicleEdited(player_id, vehicle_id, vehicle_data)
	if M.state.BeamLingBlocked then
		local player_name = MP.GetPlayerName(player_id)
		if M.state.AdminException and M.Admins[player_name] then return end
		if isUnicycle(vehicle_data) then
			MP.RemoveVehicle(player_id, vehicle_id)
			SendChatMessage(player_id, 'Unicycles are disabled!')
		end
	end
end

function removeUnicycle()
	for player_id, player_name in pairs(MP.GetPlayers() or {}) do
		if M.state.AdminException and M.Admins[player_name] then
			-- skip this admin player
		else
			for vehicle_id, vehicle_data in pairs(MP.GetPlayerVehicles(player_id) or {}) do
				if isUnicycle(vehicle_data) then
					MP.RemoveVehicle(player_id, vehicle_id)
				end
			end
		end
	end
end

function clearChat()
  local filler = " "
  for i = 1, 71 do
    SendChatMessage(-1, filler)
  end
end

---------------------------------------------------------------------------------------------
-- Init
function onInit()
	if not loadAdmins() then
		-- Convert list to dict if file doesn't exist yet
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
		TriggerClientEvent:send(-1, "EventTools_enableCompetitiveMode")
		TriggerClientEvent:send(-1, "EventTools_enablePartSelector") -- Merged from M.Commands.pcfg
	elseif data.state == "disable" then
		M.state.IsRestrictionsEnabled = false
		TriggerClientEvent:send(-1, "EventTools_disableCompetitiveMode")
		TriggerClientEvent:send(-1, "EventTools_disablePartSelector") -- Merged from M.Commands.pcfg
	end
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	sendToAllAdmins(data.from_playerid, sender_name .. " has set Restriction mode state to: " .. data.state)
	SendChatMessage(data.from_playerid or -2, "Restriction mode state has been set to: " .. data.state)
end

M.Commands.reset = function(data)
	TriggerClientEvent:send(data.to_playerid, "EventTools_resetAllOwnedVehicles")
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	local target_name = (data.to_playerid ~= -1 and MP.GetPlayerName(data.to_playerid)) or "Everyone"
	sendToAllAdmins(data.from_playerid, sender_name .. " has reset " .. target_name .. "'s vehicle")
	SendChatMessage(data.from_playerid or -2, target_name .. "'s vehicle has been reset")
end

-- M.Commands.compmode = function(data)
-- 	SendChatMessage(data.from_playerid or -2, "Competition Mode (Outdated) state has been set to: " .. data.state)
-- 	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
-- 	sendToAllAdmins(data.from_playerid, sender_name .. " has set Competition Mode (Outdated) state to: " .. data.state)
-- 	if data.state == "enable" then
-- 		M.state.CompmodeEnabled = true
-- 		TriggerClientEvent:send(-1, "EventTools_enablePartSelectorOld")
-- 	elseif data.state == "disable" then
-- 		M.state.CompmodeEnabled = false
-- 		TriggerClientEvent:send(-1, "EventTools_disablePartSelectorOld")
-- 	end
-- end

-- M.Commands.pcfg = function(data)
-- 	if data.state == "enable" then
-- 		M.state.BlockPartConfigurator = true
-- 		TriggerClientEvent:send(-1, "EventTools_enablePartSelector")
-- 	elseif data.state == "disable" then
-- 		M.state.BlockPartConfigurator = false
-- 		TriggerClientEvent:send(-1, "EventTools_disablePartSelector")
-- 	end
-- 	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
-- 	sendToAllAdmins(data.from_playerid, sender_name .. " has set Vehicle Part Configurator Disabler state to: " .. data.state)
-- 	SendChatMessage(data.from_playerid or -2, "Vehicle Part Configurator Disabler state has been set to: " .. data.state)
-- end

M.Commands.status = function(data)
	if data.isConsole == true then
		SendChatMessage(data.from_playerid, "=> Current States")
		for stateKey, stateValue in pairs(M.state) do
			SendChatMessage(data.from_playerid, tostring(stateKey) .. " -> " .. tostring(stateValue))
		end
	else
		local popupdata = ""
		for stateKey, stateValue in pairs(M.state) do
			popupdata = popupdata .. tostring(stateKey) .. " -> " .. tostring(stateValue) .. "\n"
		end
		popupdata = popupdata:gsub("\n", "[[NL]]")
		TriggerClientEvent:send(data.from_playerid, "EventTools_printcmd", popupdata)
	end
end

M.Commands.adminx = function(data)
	M.state.AdminException = not M.state.AdminException
	local state = tostring(M.state.AdminException)
	SendChatMessage(data.from_playerid, "Admin exception mode state has been set to: " .. state)
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	sendToAllAdmins(data.from_playerid, sender_name .. " has set Admin exception mode state to: " .. state)
end

M.Commands.sl = function(data)
	if data.state == "enable" then
		M.state.SpeedLimitation = true
		TriggerClientEvent:send(-1, "EventTools_enableSpeedLimit")
	elseif data.state == "disable" then
		M.state.SpeedLimitation = false
		TriggerClientEvent:send(-1, "EventTools_disableSpeedLimit")
	end
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	sendToAllAdmins(data.from_playerid, sender_name .. " has set Vehicle Speed Limiter state to: " .. data.state)
	SendChatMessage(data.from_playerid or -2, "Vehicle Speed Limiter state has been set to: " .. data.state)
end

M.Commands.slset = function(data)
	speed = data.speed
	M.state.SpeedLimitValue = data.speed
	TriggerClientEvent:send(-1, "EventTools_setSpeedLimit", speed)
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	sendToAllAdmins(data.from_playerid, sender_name .. " has changed the speed limit to: " .. tostring(data.speed))
	SendChatMessage(data.from_playerid or -2, "Speed limit has been changed to: " .. tostring(data.speed))
end

M.Commands.flip = function(data)
	TriggerClientEvent:send(data.to_playerid, "EventTools_flipEnable")
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	local target_name = (data.to_playerid ~= -1 and MP.GetPlayerName(data.to_playerid)) or "Everyone"
	sendToAllAdmins(data.from_playerid, sender_name .. " has flipped " .. target_name .. "'s vehicle")
	SendChatMessage(data.from_playerid or -2, target_name .. "'s vehicle has been flipped")
end

M.Commands.nowalk = function(data)
	SendChatMessage(data.from_playerid or -2, "NoWalk state has been set to: " .. data.state)
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	sendToAllAdmins(data.from_playerid, sender_name .. " has set the NoWalk state to: " .. data.state)
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

M.Commands.resetchat = function(data)
	TriggerClientEvent:send(-1, "EventTools_resetchat")
end

M.Commands.freeze = function(data)
	if data.state == "enable" then
		M.state.IsFrozen = true
		TriggerClientEvent:send(data.to_playerid, "EventTools_freezeVehicleEnable")
	elseif data.state == "disable" then
		M.state.IsFrozen = false
		TriggerClientEvent:send(data.to_playerid, "EventTools_freezeVehicleDisable")
	end
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	sendToAllAdmins(data.from_playerid, sender_name .. " has set the vehicle freeze state to: " .. tostring(M.state.IsFrozen))
	SendChatMessage(data.from_playerid or -2, "Vehicle freeze state has been set to: " .. tostring(M.state.IsFrozen))
end

M.Commands.vsel = function(data)
	if data.state == "enable" then
		M.state.BlockVehicleSelector = true
		TriggerClientEvent:send(-1, "EventTools_enableVehicleSelector")
	elseif data.state == "disable" then
		M.state.BlockVehicleSelector = false
		TriggerClientEvent:send(-1, "EventTools_disableVehicleSelector")
	end
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	sendToAllAdmins(data.from_playerid, sender_name .. " has set Vehicle Selector Disabler state to: " .. data.state)
	SendChatMessage(data.from_playerid or -2, "Vehicle Selector Disabler state has been set to: " .. data.state)
end

M.Commands.settime = function(data)
	local hour, minute = data.time:match("^(%d%d):(%d%d)$")
	hour, minute = tonumber(hour), tonumber(minute)
	local state = data.state
	if not hour or not minute or hour > 23 or minute > 59 then
		SendChatMessage(data.from_playerid or -2, "Invalid time. Use format HH:MM (24h).")
		return
	end
	time = {hour = hour, minute = minute, state = state}
	M.state.CurrentTime = data.time
	TriggerClientEvent:send(-1, "EventTools_setTimeOfTheDay", time)
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	sendToAllAdmins(data.from_playerid, sender_name .. " has set the time of day to " .. data.time .. " with time lock state: " .. ((state and state == 1) and "true" or "false"))
	SendChatMessage(data.from_playerid or -2, "Time of day set to " .. data.time .. " with time lock state: " .. ((state and state == 1) and "true" or "false"))
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
	if data.isConsole == true then
    	SendChatMessage(from, "=> Voting Results:")
	end

    if next(votes) == nil then
		if data.isConsole == true then
			SendChatMessage(from, "No votes yet.")
		else
			local popupdata = "No votes yet."
			TriggerClientEvent:send(data.from_playerid, "EventTools_printcmd", popupdata)
		end
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
	if data.isConsole == true then
		for _, entry in ipairs(voteList) do
			SendChatMessage(from, entry.name .. ": " .. entry.count .. " vote(s)")
		end
	else
		local popupdata = ""
		for _, entry in ipairs(voteList) do
			popupdata = popupdata .. entry.name .. ": " .. entry.count .. " vote(s)" .. "\n"
		end
		popupdata = popupdata:gsub("\n", "[[NL]]")
		TriggerClientEvent:send(data.from_playerid, "EventTools_printcmd", popupdata)
	end
end

M.Commands.clearvotes = function(data)
	votes = {}
	votedPlayers = {}
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	sendToAllAdmins(data.from_playerid, sender_name .. " has cleared all votes.")
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
		TriggerClientEvent:send(-1, "EventTools_setsuffix", payload)
	else
		M.activeTags[player_name].suffix = {
			tag = data.tag,
			rgb = 0,
			name = player_name
		}
		local payload = data.tag .. "|" .. data.rgb .. "|" .. player_name
		TriggerClientEvent:send(-1, "EventTools_setsuffix", payload)
	end
	local target_name = (data.to_playerid ~= -1 and MP.GetPlayerName(data.to_playerid)) or "Everyone"
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	SendChatMessage(data.from_playerid, "Tag (suffix) has been set for " .. target_name .. " with the text: " .. data.tag)
	sendToAllAdmins(data.from_playerid, sender_name .. " has set a tag (suffix) for " .. target_name .. " with the text: " .. data.tag)
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
		TriggerClientEvent:send(-1, "EventTools_setprefix", payload)
	else
		M.activeTags[player_name].prefix = {
			tag = data.tag,
			rgb = 0,
			name = player_name
		}
		local payload = data.tag .. "|" .. data.rgb .. "|" .. player_name
		TriggerClientEvent:send(-1, "EventTools_setprefix", payload)
	end
	local target_name = (data.to_playerid ~= -1 and MP.GetPlayerName(data.to_playerid)) or "Everyone"
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	SendChatMessage(data.from_playerid, "Tag (prefix) has been set for " .. target_name .. " with the text: " .. data.tag)
	sendToAllAdmins(data.from_playerid, sender_name .. " has set a tag (prefix) for " .. target_name .. " with the text: " .. data.tag)
end

M.Commands.cleartags = function(data)
	local player_name = MP.GetPlayerName(data.to_playerid)
	TriggerClientEvent:send(-1, "EventTools_cleartag", player_name)
	M.activeTags[player_name] = nil
	local target_name = (data.to_playerid ~= -1 and MP.GetPlayerName(data.to_playerid)) or "Everyone"
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	SendChatMessage(data.from_playerid, "Tags have been cleared for: " .. target_name)
	sendToAllAdmins(data.from_playerid, sender_name .. " has cleared tags for " .. target_name)
end

M.Commands.togglenames = function(data)
	M.state.HideNames = not M.state.HideNames
	local state = tostring(M.state.HideNames)
	TriggerClientEvent:send(-1, "EventTools_toggleNames", state)
	SendChatMessage(data.from_playerid, "Hide Names state set to: " .. state)
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	sendToAllAdmins(data.from_playerid, sender_name .. " set Hide Names state set to: " .. state)
end

M.Commands.popup = function(data)
	TriggerClientEvent:send(data.to_playerid, "EventTools_popup", data.text)
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
		TriggerClientEvent:send(-1, "EventTools_cleartag", data.name)
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
		TriggerClientEvent:send(-1, "EventTools_cleartag", data.name)
	else
		SendChatMessage(data.from_playerid, data.name .. " is not an admin.")
	end
end

M.Commands.adminlist = function(data)
	if data.isConsole == true then
		SendChatMessage(data.from_playerid, "== [Admin List] ==")
		for name, _ in pairs(M.Admins) do
			local role = getPlayerRole(name) or "No role"
			SendChatMessage(data.from_playerid, "  -> " .. name .. " (" .. role .. ")")
		end
	else
		local popupdata = ""
		for name, _ in pairs(M.Admins) do
			local role = getPlayerRole(name) or "No role"
			popupdata = popupdata .. "  -> " .. name .. " (" .. role .. ")" .. "\n"
		end
		popupdata = popupdata:gsub("\n", "[[NL]]")
		TriggerClientEvent:send(data.from_playerid, "EventTools_printcmd", popupdata)
	end
end

M.Commands.removeveh = function(data)
	if data.to_playerid == -1 then
		for player_id, player_name in pairs(MP.GetPlayers() or {}) do
			if M.state.AdminException and M.Admins[player_name] then
				-- skip this admin player
			else
				for vehicle_id, _ in pairs(MP.GetPlayerVehicles(player_id) or {}) do
					MP.RemoveVehicle(player_id, vehicle_id)
				end
			end
		end
	else
		for vehicle_id, _ in pairs(MP.GetPlayerVehicles(data.to_playerid) or {}) do
			MP.RemoveVehicle(data.to_playerid, vehicle_id)
		end
	end
	local target_name = (data.to_playerid ~= -1 and MP.GetPlayerName(data.to_playerid)) or "Everyone"
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	SendChatMessage(data.from_playerid, "All vehicles have been removed for " .. target_name .. ".")
	sendToAllAdmins(data.from_playerid, sender_name .. " has removed all of " .. target_name .. "'s vehicles.")
end

M.Commands.startrace = function(data)
	M.state.IsRestrictionsEnabled = true
	TriggerClientEvent:send(-1, "EventTools_enableCompetitiveMode")
	-- M.state.BlockPartConfigurator = true
	TriggerClientEvent:send(-1, "EventTools_enablePartSelector")
	M.state.BlockVehicleSelector = true
	TriggerClientEvent:send(-1, "EventTools_enableVehicleSelector")

	
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	sendToAllAdmins(data.from_playerid, sender_name .. " has started the race!")
	SendChatMessage(data.from_playerid or -2, "The race has been started!")
end

M.Commands.stoprace = function(data)
	M.state.IsRestrictionsEnabled = false
	TriggerClientEvent:send(-1, "EventTools_disableCompetitiveMode")
	-- M.state.BlockPartConfigurator = false
	TriggerClientEvent:send(-1, "EventTools_disablePartSelector")
	M.state.BlockVehicleSelector = false
	TriggerClientEvent:send(-1, "EventTools_disableVehicleSelector")

	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	sendToAllAdmins(data.from_playerid, sender_name .. " has stopped the race!")
	SendChatMessage(data.from_playerid or -2, "The race has been stopped!")
end

M.Commands.aoc = function(data)
	M.state.AdminOnlyChat = not M.state.AdminOnlyChat
	local state = tostring(M.state.AdminOnlyChat)
	SendChatMessage(data.from_playerid, "Admin Only Chat mode state has been set to: " .. state)
	local sender_name = (data.from_playerid ~= -2 and MP.GetPlayerName(data.from_playerid)) or "Console"
	sendToAllAdmins(data.from_playerid, sender_name .. " has set Admin Only Chat mode state to: " .. state)
end