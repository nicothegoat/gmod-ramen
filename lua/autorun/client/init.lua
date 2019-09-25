-- This work is licensed under the Creative Commons Attribution-ShareAlike 4.0 International License.
-- To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/4.0/.

local pairs = pairs
local IsValid = IsValid

local draw_SimpleTextOutlined = draw.SimpleTextOutlined

local convarDrawDistance = CreateClientConVar("cl_ramen_drawdistance", "256", true, false,
	"The distance at which the cade ban text should stop rendering.")

local markedPlayers = {}

local function hookHUDPaint()
	local localPlayer = LocalPlayer()

	if localPlayer:Team() ~= TEAM_HUMAN then return end

	local offset = Vector(0, 0, 80)
	local textColor = Color(255, 0, 0, 0)
	local outlineColor = Color(0, 0, 0, 0)
	local maxOpacity = 255
	local maxDistance = convarDrawDistance:GetInt()
	local maxDistanceSquared = maxDistance * maxDistance

	local localPlayerPos = localPlayer:GetPos()

	for plr in pairs(markedPlayers) do
		if IsValid(plr) then
			local distanceSquared = localPlayerPos:DistToSqr(plr:GetPos())

			if distanceSquared < maxDistanceSquared then
				local position = (plr:GetPos() + offset):ToScreen()
				local opacity = (1 - distanceSquared / maxDistanceSquared) * maxOpacity

				textColor.a = opacity
				outlineColor.a = opacity

				draw_SimpleTextOutlined("BANNED FROM CADING", "DermaLarge",
					position.x, position.y, textColor,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, outlineColor)
			end
		else
			markedPlayers[plr] = nil
		end
	end
end

local function hookInitPostEntity()
	net.Start("ramenMarkedSendFull")
	net.SendToServer()
end

hook.Add("InitPostEntity", "ramen", hookInitPostEntity)
hook.Add("HUDPaint", "ramen", hookHUDPaint)


local function netMarkedAddRemove()
	local plr = net.ReadEntity()
	local state = net.ReadBool()

	if IsValid(plr) then
		markedPlayers[plr] = state or nil
	end
end

local function netMarkedSendFull()
	for plr in pairs (markedPlayers) do
		markedPlayers[plr] = nil
	end

	local count = net.ReadUInt(8)
	for i = 0, count do
		markedPlayers[net.ReadEntity()] = true
	end
end

net.Receive("ramenMarkedAddRemove", netMarkedAddRemove)
net.Receive("ramenMarkedSendFull", netMarkedSendFull)
