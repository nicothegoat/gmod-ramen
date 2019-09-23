-- This work is licensed under the Creative Commons Attribution-ShareAlike 4.0 International License.
-- To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/4.0/.

local pairs = pairs
local IsValid = IsValid
local player_GetHumans = player.GetHumans

local draw_SimpleTextOutlined = draw.SimpleTextOutlined

local drawDistanceConvar = CreateClientConVar("cl_ramen_drawdistance", "256", true, false,
	"The distance at which the cade ban text should stop rendering.")

local function HUDPaintHook()
	local zOffset = 80
	local maxOpacity = 255
	local maxDistance = drawDistanceConvar:GetInt()
	local maxDistanceSquared = maxDistance * maxDistance

	for _, plr in pairs(player_GetHumans()) do
		if LocalPlayer():Team() == TEAM_HUMAN and IsValid(plr) and plr:GetNWBool("ramenNoodled") then
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

hook.Add("HUDPaint", "ramen", HUDPaintHook)
