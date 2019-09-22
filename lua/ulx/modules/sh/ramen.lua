-- This work is licensed under the Creative Commons Attribution-ShareAlike 4.0 International License.
-- To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/4.0/.

ramenNoodledPlayers = {}
local markedPlayers = {}

local voteMinRatio
local voteMinVotes

local table_concat = table.concat
local table_insert = table.insert

local ULib_tsay = ULib.tsay
local ULib_tsayError = ULib.tsayError

local ulx_doVote = ulx.doVote
local ulx_command = ulx.command
local ulx_logString = ulx.logString
local ulx_fancyLogAdmin = ulx.fancyLogAdmin

local net_Send = net.Send
local net_Start = net.Start
local net_Receive = net.Receive
local net_Broadcast = net.Broadcast
local net_WriteUInt = net.WriteUInt
local net_WriteBool = net.WriteBool
local net_WriteEntity = net.WriteEntity

local hook_Add = hook.Add

local function noodlePlayer(plr, marked)
	if markedPlayers[plr] ~= (marked or nil) then
		markedPlayers[plr] = marked or nil

		plr.NoObjectPickup = marked or nil

		plr:SetNWBool("ramenNoodled", marked)
	end
end


if SERVER then
	local file_Read = file.Read
	local file_Write = file.Write

	local string_Split = string.Split

	local ulx_convar = ulx.convar

	local function serializeSet(set)
		local resultConcat = {}

		for value in pairs(set) do
			if #value > 0 then
				table_insert(resultConcat, value)
			end
		end

		-- windows compatible newline
		-- for easy manual editing
		return table_concat(resultConcat, "\r\n")
	end

	local function deserializeSet(set)
		local result = {}

		-- windows compatible newline
		-- for easy manual editing
		local setLines = string_Split(set, "\r\n")

		for _, line in pairs(setLines) do
			if #line > 0 then
				result[line] = true
			end
		end

		return result
	end

	do
		local ramenSerialized = file_Read("ramen_noodled_players.txt")

		if ramenSerialized then
			ramenNoodledPlayers = deserializeSet(ramenSerialized)
		end
	end

	local function playerSpawnHook(plr)
		if not ramenNoodledPlayers[plr:SteamID()] then return end

		noodlePlayer(plr, plr:Team() == TEAM_HUMAN)
	end

	local function playerDeathHook(plr)
		noodlePlayer(plr, false)
	end

	local function shutDownHook()
		local ramenSerialized = serializeSet(ramenNoodledPlayers)
		file_Write("ramen_noodled_players.txt", ramenSerialized)
	end

	hook_Add("PlayerSpawn", "ramen", playerSpawnHook)
	hook_Add("PlayerDeath", "ramen", playerDeathHook)
	hook_Add("ShutDown", "ramen", shutDownHook)

	voteMinRatio = ulx_convar("votenoodle_minratio", "0.5", nil, ULib.ACCESS_SUPERADMIN)
	voteMinVotes = ulx_convar("votenoodle_minvotes", "3", nil, ULib.ACCESS_SUPERADMIN)
end

if CLIENT then
	local player_GetHumans = player.GetHumans

	local draw_SimpleTextOutlined = draw.SimpleTextOutlined

	local drawDistanceConvar = CreateClientConVar("cl_ramen_drawdistance", "768", true, false,
		"The distance at which the cade ban text should stop rendering.")

	local function HUDPaintHook()
		local zOffset = 80
		local maxOpacity = 255
		local maxDistance = drawDistanceConvar:GetInt()
		local maxDistanceSquared = maxDistance * maxDistance

		for _, plr in pairs(player_GetHumans()) do
			if IsValid(plr) and plr:GetNWBool("ramenNoodled") and LocalPlayer():Team() == TEAM_HUMAN then
				local distanceSquared = LocalPlayer():GetPos():DistToSqr(plr:GetPos())

				if distanceSquared < maxDistanceSquared then
					local position = (plr:GetPos() + Vector(0, 0, zOffset)):ToScreen()
					local opacity = (1 - distanceSquared / maxDistanceSquared) * maxOpacity

					draw_SimpleTextOutlined("BANNED FROM CADING", "DermaLarge",
						position.x, position.y, Color(255, 0, 0, opacity),
						TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, opacity))
				end
			end
		end
	end

	hook_Add("HUDPaint", "ramen", HUDPaintHook)
end

function ulx.noodle(caller, target, unnoodle)
	if not IsValid(target) then return end

	if unnoodle then
		ramenNoodledPlayers[target:SteamID()] = nil

		noodlePlayer(target, false)

		ulx_fancyLogAdmin(caller, "#A unnoodled #T", target)
	else
		ramenNoodledPlayers[target:SteamID()] = true

		noodlePlayer(target, true)

		ulx_fancyLogAdmin(caller, "#A noodled #T", target)
	end
end

local noodle = ulx.command("ZS ULX Commands", "ulx noodle", ulx.noodle, "!noodle")
noodle:addParam{type = ULib.cmds.PlayerArg}
noodle:addParam{type = ULib.cmds.BoolArg, invisible = true}
noodle:defaultAccess(ULib.ACCESS_ADMIN)
noodle:help("Prevents players from picking up props")
noodle:setOpposite("ulx unnoodle", {nil, nil, true}, "!unnoodle")

local function voteNoodleDone(t, caller, target, targetname, targetid)
	local result
	local resultVotes = 0

	for id, voteCount in pairs(t.results) do
		if voteCount > resultVotes then
			result = id
			resultVotes = voteCount
		end
	end

	local minRatio = voteMinRatio:GetFloat()
	local minVotes = voteMinVotes:GetInt()

	local concat = {
		"Vote results: User will no",
		"",
		" be banned from cading. (",
		"",
		"/",
		t.voters or "0",
		")"
	}

	if result ~= 1 or resultVotes < minVotes or resultVotes / t.voters < minRatio then
		concat[2] = "t"
		concat[4] = t.results[1] or 0
	else
		concat[2] = "w"
		concat[4] = resultVotes or 0

		if IsValid(target) then
			ulx.noodle(caller, target)
		else
			ramenNoodledPlayers[targetid] = true
		end
	end

	local message = table_concat(concat)
	concat[8] = "\n"

	ULib_tsay(nil, message)
	ulx_logString(message)
	Msg(table_concat(concat))
end

function ulx.votenoodle(caller, target)
	if ulx.voteInProgress then
		ULib_tsayError(caller, "There is already a vote in progress. Please wait for the current one to end.", true)
		return
	end

	local concat = {"Ban ", 0, " from cading?"}
	concat[2] = target:Nick()

	ulx_doVote(table_concat(concat), {"Yes", "No"}, voteNoodleDone, nil, nil, nil, caller, target, target:Nick(), target:SteamID())
	ulx_fancyLogAdmin(caller, "#A started a votenoodle against #T", target)
end

local votenoodle = ulx_command("ZS ULX Commands", "ulx votenoodle", ulx.votenoodle, "!votenoodle")
votenoodle:addParam{type = ULib.cmds.PlayerArg}
votenoodle:defaultAccess(ULib.ACCESS_ALL)
votenoodle:help("Starts a public cade ban vote agains target.")
