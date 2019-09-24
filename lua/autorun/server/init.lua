-- This work is licensed under the Creative Commons Attribution-ShareAlike 4.0 International License.
-- To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/4.0/.

if ramen then
	error("\"ramen\" table already exists!")
end

local function serialize(tbl)
	local resultConcat = {}

	local curTime = os.time()

	for steamID, timestamp in pairs(tbl) do
		-- don't save expired or temporary entries
		if timestamp == -1 or (timestamp > 0 and timestamp > curTime) then
			table.insert(resultConcat, steamID)
			table.insert(resultConcat, " = ")
			table.insert(resultConcat, timestamp)
			table.insert(resultConcat, "\r\n")
		end
	end

	return table.concat(resultConcat)
end

local function deserialize(text)
	local result = {}

	local curTime = os.time()

	local lines = string.Split(text, "\r\n")

	for _, line in pairs(lines) do
		if #line > 0 then
			local kvPair = string.Split(line, " = ")
			local steamID = kvPair[1]
			local timestamp = tonumber(kvPair[2]) or -1

			if timestamp >= 0 then
				if timestamp > curTime then -- don't load expired entries
					result[steamID] = timestamp
				end
			else
				result[steamID] = -1
			end
		end
	end

	return result
end


local markedPlayers = {}
local noodledPlayers

local serialized = file.Read("ramen_noodled_players.txt")
if serialized then
	noodledPlayers = deserialize(serialized)
else
	noodledPlayers = {}
end


local function setPlayerMarked(plr, marked)
	marked = marked and true or nil

	markedPlayers[plr] = marked

	plr.NoObjectPickup = marked

	-- This is missing sometimes
	if plr.DoNoodleArmBones then
		plr:DoNoodleArmBones()
	end

	plr:SetNWBool("ramenNoodled", marked or false)
end

local function setPlayerNoodled(plr, noodled)
	local steamID = plr:SteamID()

	if timer.Exists(steamID) then
		timer.Remove(steamID)
	end

	if isnumber(noodled) and noodled >= 0 then
		if noodled > 0 then
			timeout = noodled * 60 -- convert to seconds

			-- when the timeout should expire
			local timestamp = os.time() + timeout
			noodledPlayers[steamID] = timestamp

			local function noodleTimeout()
				noodledPlayers[steamID] = nil
				setPlayerMarked(plr, nil)
			end

			timer.Create(steamID, timeout, 1, noodleTimeout)
		else
			noodledPlayers[steamID] = 0
		end
	else
		noodledPlayers[steamID] = noodled and -1 or nil
	end

	setPlayerMarked(plr, noodled)
end


local function hookPlayerDisconnected(plr)
	local steamID = plr:SteamID()

	if timer.Exists(steamID) then
		timer.Remove(steamID)
	end
end

local function hookPlayerAuthed(plr)
	local steamID = plr:SteamID()

	if isnumber(noodledPlayers[steamID]) and noodledPlayers[steamID] > 0 then
		local curTime = os.time()
		local timestamp = noodledPlayers[steamID]

		if timestamp > curTime then
			local function noodleTimeout()
				noodledPlayers[steamID] = nil
				setPlayerMarked(plr, nil)
			end

			timer.Create("steamID", timestamp - curTime, 1, noodleTimeout)

			setPlayerMarked(plr, true)
		else
			noodledPlayers[steamID] = nil
		end
	end
end

local function hookPlayerSpawn(plr)
	if not noodledPlayers[plr:SteamID()] then return end

	setPlayerMarked(plr, plr:Team() == TEAM_HUMAN)
end

local function hookShutDown()
	local serialized = serialize(noodledPlayers)
	file.Write("ramen_noodled_players.txt", serialized)
end

hook.Add("PlayerDisconnected", "ramen", hookPlayerDisconnected)
hook.Add("PlayerAuthed", "ramen", hookPlayerAuthed)
hook.Add("PlayerSpawn", "ramen", hookPlayerSpawn)
hook.Add("PlayerDeath", "ramen", hookPlayerDeath)
hook.Add("ShutDown", "ramen", hookShutDown)


ramen = {
	noodledPlayers = noodledPlayers,
	setPlayerNoodled = setPlayerNoodled
}
