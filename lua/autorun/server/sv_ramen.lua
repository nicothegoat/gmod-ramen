if ramen then
	error("Global variable \"ramen\" already exists!")
end

local convarHammerBan = CreateConVar("sv_ramen_hammer_ban", "1", FCVAR_ARCHIVE,
	"Prevent noodled players from placing or removing nails?")
local convarHammerWeapons = CreateConVar("sv_ramen_hammer_weapons",
	"weapon_zs_hammer,weapon_zs_electrohammer", FCVAR_ARCHIVE,
	"Comma delimited list of weapons to apply hammer ban to.")

util.AddNetworkString("ramenMarkedAddRemove")
util.AddNetworkString("ramenMarkedSendFull")
util.AddNetworkString("ramenBannedAction")

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


local noSendFull = {}

local markedCount = 0
local markedPlayers = {}
local noodledPlayers

local serialized = file.Read("ramen_noodled_players.txt")
if serialized then
	noodledPlayers = deserialize(serialized)
else
	noodledPlayers = {}
end


local hammerWeaponNames = string.Split(convarHammerWeapons:GetString(), ",")
local hammerWeapons = {}
for _, wepName in pairs(hammerWeaponNames) do
	hammerWeapons[wepName] = true
end

local function hookOwnerChanged(self)
	local super = self.ramenSuper

	self.SecondaryAttack = super.SecondaryAttack
	self.OwnerChanged = super.OwnerChanged
	self.Reload = super.Reload

	self.ramenSuper = nil

	if self.OwnerChanged then
		self:OwnerChanged()
	end
end

local function setHammerBlocked(wep, blocked)
	local super = wep.ramenSuper

	if blocked then
		if super then return end

		super = {}

		local function bannedAction(self)
			if CurTime() < self:GetNextSecondaryFire() then return end

			local plr = self:GetOwner()
			if plr:GetBarricadeGhosting() then return end

			self:SetNextSecondaryFire(CurTime() + 1)

			plr:PrintMessage(HUD_PRINTCENTER, "You are banned from cading!")

			net.Start("ramenBannedAction")
			net.Send(plr)
		end


		super.SecondaryAttack = wep.SecondaryAttack
		super.OwnerChanged = wep.OwnerChanged
		super.Reload = wep.Reload

		wep.SecondaryAttack = bannedAction
		wep.Reload = bannedAction

		wep.OwnerChanged = hookOwnerChanged

		wep.ramenSuper = super
	else
		if not super then return end

		wep.SecondaryAttack = super.SecondaryAttack
		wep.OwnerChanged = super.OwnerChanged
		wep.Reload = super.Reload

		wep.ramenSuper = nil
	end
end

local function hookWeaponEquip(wep, plr)
	if not convarHammerBan:GetBool() then return end

	if markedPlayers[plr] and hammerWeapons[wep:GetClass()] then
		timer.Simple(0, function()
			setHammerBlocked(wep, true)
		end)
	end
end

hook.Add("WeaponEquip", "ramen", hookWeaponEquip)


local function setPlayerMarked(plr, marked)
	marked = marked and true or nil

	if markedPlayers[plr] ~= marked then
		markedCount = markedCount + (marked and 1 or -1)
	end
	markedPlayers[plr] = marked

	plr.NoObjectPickup = marked

	-- This is missing sometimes
	if plr.DoNoodleArmBones then
		plr:DoNoodleArmBones()
	end

	if convarHammerBan:GetBool() or not marked then
		for wepName in pairs(hammerWeapons) do
			local wep = plr:GetWeapon(wepName)

			setHammerBlocked(wep, marked)
		end
	end

	net.Start("ramenMarkedAddRemove")

	net.WriteEntity(plr)
	net.WriteBool(marked or false)

	net.Broadcast()
end

local function setPlayerNoodled(plr, noodled)
	local steamID = plr:SteamID()

	if timer.Exists(steamID) then
		timer.Remove(steamID)
	end

	if isnumber(noodled) and noodled >= 0 then
		if noodled > 0 then
			timeout = noodled * 60 -- convert to seconds

			-- when it should expire
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

	setPlayerMarked(plr, noodled and plr:Team() == TEAM_HUMAN)
end


local function hookPlayerDisconnected(plr)
	noSendFull[plr] = nil

	local steamID = plr:SteamID()
	if not noodledPlayers[steamID] then return end

	setPlayerMarked(plr, false)
end

local function hookPlayerAuthed(plr)
	local steamID = plr:SteamID()
	if not noodledPlayers[steamID] then return end

	if noodledPlayers[steamID] > 0 then
		local curTime = os.time()
		local timestamp = noodledPlayers[steamID]

		if timestamp > curTime then
			local function noodleTimeout()
				noodledPlayers[steamID] = nil
				setPlayerMarked(plr, nil)
			end

			timer.Create(steamID, timestamp - curTime, 1, noodleTimeout)
		else
			noodledPlayers[steamID] = nil
		end
	end
end

local function hookPlayerSpawn(plr)
	if not noodledPlayers[plr:SteamID()] then return end

	setPlayerMarked(plr, plr:Team() == TEAM_HUMAN)
end

local function hookPlayerDeath(plr)
	if not noodledPlayers[plr:SteamID()] then return end

	setPlayerMarked(plr, false)
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


local function netMarkedSendFull(_, plr)
	if noSendFull[plr] then return end
	noSendFull[plr] = true

	timer.Simple(1, function() noSendFull[plr] = nil end)

	net.Start("ramenMarkedSendFull")

	net.WriteUInt(markedCount, 8)
	for markedPlr in pairs(markedPlayers) do
		net.WriteEntity(markedPlr)
	end

	net.Send(plr)
end

net.Receive("ramenMarkedSendFull", netMarkedSendFull)


ramen = {
	noodledPlayers = noodledPlayers,
	setPlayerNoodled = setPlayerNoodled
}
