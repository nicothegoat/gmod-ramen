-- This work is licensed under the Creative Commons Attribution-ShareAlike 4.0 International License.
-- To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/4.0/.

local pairs = pairs
local Color = Color
local Vector = Vector
local IsValid = IsValid
local LocalPlayer = LocalPlayer
local string_ToColor = string.ToColor
local draw_SimpleText = draw.SimpleText
local draw_GetFontHeight = draw.GetFontHeight
local draw_SimpleTextOutlined = draw.SimpleTextOutlined

local convarDrawDistance = CreateClientConVar("cl_ramen_drawdistance", "256",
	true, false, "Set to 0 to disable cade ban text rendering.")
local convarZOffset = CreateClientConVar("cl_ramen_zoffset", "80")
local convarText = CreateClientConVar("cl_ramen_text", "BANNED FROM CADING")
local convarFont = CreateClientConVar("cl_ramen_font", "DermaLarge")
local convarColor = CreateClientConVar("cl_ramen_color", "255 0 0 255")
local convarOutlineColor = CreateClientConVar("cl_ramen_outline_color", "0 0 0 255",
	true, false, "Set alpha to 0 to disable the outline.")


local markedPlayers = {}

local function hookHUDPaint()
	local localPlayer = LocalPlayer()

	if localPlayer:Team() ~= TEAM_HUMAN then return end

	local maxDistance = convarDrawDistance:GetInt()
	local maxDistanceSquared = maxDistance * maxDistance

	if maxDistance == 0 then return end

	local offset = Vector(0, 0, convarZOffset:GetFloat())

	local text = convarText:GetString()
	local textFont = convarFont:GetString()

	local localTextX = ScrW() / 2
	local localTextY = ScrH() / 12 + draw_GetFontHeight(textFont)

	local textColor = string_ToColor(convarColor:GetString()) or Color(255, 0, 0, 255)
	local textAlpha = textColor.a
	local outlineColor = string_ToColor(convarOutlineColor:GetString()) or Color(0, 0, 0, 255)
	local outlineAlpha = outlineColor.a

	local drawFunc

	if outlineAlpha == 0 then
		drawFunc = draw_SimpleText
	else
		drawFunc = draw_SimpleTextOutlined
	end

	local drawLocalPlayer = localPlayer.OverTheShoulder or localPlayer:ShouldDrawLocalPlayer()

	local localPlayerPos = localPlayer:GetPos()

	for plr in pairs(markedPlayers) do
		if plr == localPlayer and not drawLocalPlayer then
			textColor.a = textAlpha
			outlineColor.a = outlineAlpha

			drawFunc(text, textFont, localTextX, localTextY, textColor,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, outlineColor)

		elseif IsValid(plr) then
			local distanceSquared = localPlayerPos:DistToSqr(plr:GetPos())

			if distanceSquared < maxDistanceSquared then
				local position = (plr:GetPos() + offset):ToScreen()

				textColor.a = (1 - distanceSquared / maxDistanceSquared) * textAlpha
				outlineColor.a = (1 - distanceSquared / maxDistanceSquared) * outlineAlpha

				drawFunc(text, textFont, position.x, position.y, textColor,
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

local function netBannedAction()
	surface.PlaySound("ambient/alarms/klaxon1.wav")
end

net.Receive("ramenMarkedAddRemove", netMarkedAddRemove)
net.Receive("ramenMarkedSendFull", netMarkedSendFull)
net.Receive("ramenBannedAction", netBannedAction)
