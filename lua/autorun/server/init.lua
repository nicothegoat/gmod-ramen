-- This work is licensed under the Creative Commons Attribution-ShareAlike 4.0 International License.
-- To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/4.0/.

if ramen then
	error("\"ramen\" table already exists!")
end

local function serializeSet(set)
	local resultConcat = {}

	for value in pairs(set) do
		if #value > 0 then
			table.insert(resultConcat, value)
		end
	end

	-- windows compatible newline
	-- for easy manual editing
	return table.concat(resultConcat, "\r\n")
end

local function deserializeSet(set)
	local result = {}

	-- windows compatible newline
	-- for easy manual editing
	local setLines = string.Split(set, "\r\n")

	for _, line in pairs(setLines) do
		if #line > 0 then
			result[line] = true
		end
	end

	return result
end

local markedPlayers = {}
local noodledPlayers

local ramenSerialized = file.Read("ramen_noodled_players.txt")
if ramenSerialized then
	noodledPlayers = deserializeSet(ramenSerialized)
else
	noodledPlayers = {}
end

local function setPlayerNoodled(plr, marked)
	marked = marked and true or nil
	if markedPlayers[plr] ~= (marked) then
		noodledPlayers[plr] = marked
		markedPlayers[plr] = marked

		plr.NoObjectPickup = marked

		-- This is missing sometimes
		if plr.DoNoodleArmBones then
			plr:DoNoodleArmBones()
		end

		plr:SetNWBool("ramenNoodled", marked)
	end
end

local function hookPlayerSpawn(plr)
	if not noodledPlayers[plr:SteamID()] then return end

	setPlayerNoodled(plr, plr:Team() == TEAM_HUMAN)
end

local function hookPlayerDeath(plr)
	setPlayerNoodled(plr, false)
end

local function hookShutDown()
	local serialized = serializeSet(noodledPlayers)
	file.Write("ramen_noodled_players.txt", serialized)
end

hook.Add("PlayerSpawn", "ramen", hookPlayerSpawn)
hook.Add("PlayerDeath", "ramen", hookPlayerDeath)
hook.Add("ShutDown", "ramen", hookShutDown)

ramen = {
	noodledPlayers = noodledPlayers,
	markedPlayers = markedPlayers,
	setPlayerNoodled = setPlayerNoodled
}
