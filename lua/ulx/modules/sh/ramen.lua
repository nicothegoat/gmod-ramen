-- This work is licensed under the Creative Commons Attribution-ShareAlike 4.0 International License.
-- To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/4.0/.

local voteMinRatio
local voteMinVotes

if SERVER then
	voteMinRatio = ulx.convar("votenoodle_minratio", "0.5", nil, ULib.ACCESS_SUPERADMIN)
	voteMinVotes = ulx.convar("votenoodle_minvotes", "3", nil, ULib.ACCESS_SUPERADMIN)
end

function ulx.noodle(caller, target, unnoodle)
	if not IsValid(target) then return end

	if unnoodle then
		ramen.setPlayerNoodled(target, false)

		ulx.fancyLogAdmin(caller, "#A unnoodled #T", target)
	else
		ramen.setPlayerNoodled(target, true)

		ulx.fancyLogAdmin(caller, "#A noodled #T", target)
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
		0,
		" be banned from cading. (",
		0,
		"/",
		t.voters or "0",
		")",
		"\n"
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
			ramen.noodledPlayers[targetid] = true
		end
	end

	local message = table.concat(concat)

	ULib.tsay(nil, message)
	ulx.logString(message)
end

function ulx.votenoodle(caller, target)
	if ulx.voteInProgress then
		ULib.tsayError(caller, "There is already a vote in progress. Please wait for the current one to end.", true)
		return
	end

	local concat = {"Ban ", 0, " from cading?"}
	concat[2] = target:Nick()

	ulx.doVote(table.concat(concat), {"Yes", "No"}, voteNoodleDone, nil, nil, nil, caller, target, target:Nick(), target:SteamID())
	ulx.fancyLogAdmin(caller, "#A started a votenoodle against #T", target)
end

local votenoodle = ulx.command("ZS ULX Commands", "ulx votenoodle", ulx.votenoodle, "!votenoodle")
votenoodle:addParam{type = ULib.cmds.PlayerArg}
votenoodle:defaultAccess(ULib.ACCESS_ALL)
votenoodle:help("Starts a public cade ban vote agains target.")
