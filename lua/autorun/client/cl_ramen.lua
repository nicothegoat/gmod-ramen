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

local markedPlayers = {}
local textColor = Color(255, 0, 0, 255)

local function hookHUDPaint()
	local localPlayer = LocalPlayer()

	if localPlayer:Team() ~= TEAM_HUMAN then return end

	local maxDistance = convarDrawDistance:GetInt()
	local maxDistanceSquared = maxDistance * maxDistance

	if maxDistance == 0 then return end

	local offset = 72

	local text = "BANNED FROM CADING"
	local textFont = "DermaLarge"

	local localTextX = ScrW() / 2
	local localTextY = ScrH() / 12 + draw_GetFontHeight(textFont)

	local textAlpha = 255

	local drawLocalPlayer = localPlayer.OverTheShoulder or localPlayer:ShouldDrawLocalPlayer()

	for plr in pairs(markedPlayers) do
		if plr == localPlayer and not drawLocalPlayer then
			textColor.a = textAlpha

			draw_SimpleText(text, textFont, localTextX, localTextY, textColor,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

		elseif IsValid(plr) then
			local distanceSquared = localPlayer:GetPos():DistToSqr(plr:GetPos())

			if distanceSquared < maxDistanceSquared then
				local worldPosition = plr:GetPos()
				worldPosition.z = worldPosition.z + offset

				local position = worldPosition:ToScreen()

				textColor.a = (1 - distanceSquared / maxDistanceSquared) * textAlpha

				draw_SimpleText(text, textFont, position.x, position.y, textColor,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
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
