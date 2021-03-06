local voteMinRatio
local voteMinVotes
local voteTimeout

if SERVER then
	voteMinRatio = ulx.convar("votenoodleminratio", "0.5", nil, ULib.ACCESS_SUPERADMIN)
	voteMinVotes = ulx.convar("votenoodleminvotes", "3", nil, ULib.ACCESS_SUPERADMIN)
	voteTimeout  = ulx.convar("votenoodletimeout", "-1", nil, ULib.ACCESS_SUPERADMIN)
end

function ulx.noodle(caller, target, time, unnoodle)
	if unnoodle then
		ramen.setPlayerNoodled(target, false)

		ulx.fancyLogAdmin(caller, "#A unnoodled #T", target)
	else
		if time >= 0 then
			ramen.setPlayerNoodled(target, time)
		else
			ramen.setPlayerNoodled(target, true)
		end

		ulx.fancyLogAdmin(caller, "#A noodled #T", target)
	end
end

local noodle = ulx.command("ZS ULX Commands", "ulx noodle", ulx.noodle, "!noodle")
noodle:addParam{type = ULib.cmds.PlayerArg}
noodle:addParam{type = ULib.cmds.NumArg, default = -1, hint = "Timeout in minutes (0 = next map)", ULib.cmds.optional}
noodle:addParam{type = ULib.cmds.BoolArg, invisible = true}
noodle:defaultAccess(ULib.ACCESS_ADMIN)
noodle:help("Prevents players from picking up props")
noodle:setOpposite("ulx unnoodle", {nil, nil, -1, true}, "!unnoodle")

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

		local timeout = voteTimeout:GetFloat()

		if IsValid(target) then
			ulx.noodle(caller, target, timeout)
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
