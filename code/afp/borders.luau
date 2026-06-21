--[[
one challenge with this one was designing the borders to work in multiple areas at the same time, especially when considering a map with FilteringEnabled on.
80% of the scripting was made by me with another 20% as help with performance by another scripter. 

The changes to help make this work with complex zone geometry is to bind each border with a tag indicating that it is a border, and then providing 2 attributes which are the zoneIDs of the adjacent zones. This border will only activate
and do the proximity checks if they are within vicinity, and shuts off saving resources when it leaves the vicinity of the border.

By doing so, we were able to tag all the important borders and set these pieces up quickly by modifying just 2 properties of it for the entire map.

]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ZoneCache = require(ReplicatedStorage.Shared.Modules.PrisonZones.ZoneCache)
local RoutinePackets = require(ReplicatedStorage.Shared.Packets.RoutinePackets)
local PrisonZones = require(script.Parent.PrisonZones)
local Borders = {
	Active = false,
}
Borders.__index = Borders

local BorderRegistry = {}

if RunService:IsServer() then
	warn(
		debug.traceback("Borders is not meant to be used on server. Why require on server?? Returning empty table.", 2)
	)
	return Borders
end

local LocalPlayer = Players.LocalPlayer

type ZoneData = {
	UI: SurfaceGui,
	ID: string,
	Status: string,
	FrameDisplaying: boolean,
}

export type BorderData = {
	Part: BasePart, -- the object to build borders on -- need a better typeof of this.
	Zone1Data: ZoneData,
	Zone2Data: ZoneData,
	Scanner: RBXScriptConnection?, -- Whether the scanner is active or not.
	HideAllBordersInterface: () -> (),
	AttributeChangedSignal: RBXScriptConnection?,
	PacketListenerDisconnect: () -> ()?,
}

export type BorderType = typeof(setmetatable({} :: BorderData, Borders))

local TWEEN_CONFIGS = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Borders.TerminateBorder(Border: BorderType)
	Border.HideAllBordersInterface()
	if Border.AttributeChangedSignal then Border.AttributeChangedSignal:Disconnect() end
	if Border.PacketListenerDisconnect then Border.PacketListenerDisconnect() end
	if Border.Scanner then Border.Scanner:Disconnect() end
end

local function TweenStatusFrame(StatusFrame: Frame, ToDo: "Hide" | "Show")
	local Label = StatusFrame:FindFirstChild("TextLabel") :: TextLabel?
	assert(Label, "This statusframe is missing its textlabel.")
	assert(ToDo == "Hide" or ToDo == "Show", "Invalid state was given.")

	local NewTransparency = ToDo == "Hide" and 1 or 0
	--1 to hide, 0 to show
	local Tween = TweenService:Create(StatusFrame, TWEEN_CONFIGS, { BackgroundTransparency = NewTransparency })
	local TweenText = TweenService:Create(Label, TWEEN_CONFIGS, { TextTransparency = NewTransparency })
	Tween:Play()
	TweenText:Play()
end

function Borders.Activate(self: BorderType)
	if not Borders.Active then return end

	local currentZone = LocalPlayer:GetAttribute("CurrentZone")
	local oppositeZone = nil
	if currentZone == self.Zone1Data.ID then
		oppositeZone = "Zone2Data"
	elseif currentZone == self.Zone2Data.ID then
		oppositeZone = "Zone1Data"
	else
		warn(debug.traceback("Not an active zone? Deactivating."))
		return
	end
	self.Scanner = RunService.Heartbeat:Connect(function()
		if not LocalPlayer.Character then
			print("No character!")
			return
		end
		if not LocalPlayer.Character.PrimaryPart then
			print("No rootpart!")
			return
		end

		local RootPart = LocalPlayer.Character.PrimaryPart
		local CloserThan25 = (RootPart.Position - self.Part.Position).Magnitude < 25
		if CloserThan25 then
			local Frame = self[oppositeZone].UI:FindFirstChild(self[oppositeZone].Status) :: Frame
			if not self[oppositeZone].FrameDisplaying then
				if self[oppositeZone].ID == nil then
					warn("There is no ID for the frame displayed!")
					return
				end
				if
					PrisonZones.GetZoneStatus(ZoneCache.CurrentZoneFastRead)
					== PrisonZones.GetZoneStatus(self[oppositeZone].ID)
				then
					return
				end
				TweenStatusFrame(Frame, "Show")
				self[oppositeZone].FrameDisplaying = true
			end
		elseif self[oppositeZone].FrameDisplaying then
			local Frame = self[oppositeZone].UI:FindFirstChild(self[oppositeZone].Status) :: Frame
			TweenStatusFrame(Frame, "Hide")
			self[oppositeZone].FrameDisplaying = false
		end
	end)
end

function Borders.RefreshBorders()
	for _, border in BorderRegistry do
		local currentZone = LocalPlayer:GetAttribute("CurrentZone")
		if border.Zone1Data.ID == currentZone or border.Zone2Data.ID == currentZone then border.Activate() end
	end
end

function Borders.Deactivate(self: BorderType)
	if not Borders.Active then return end
	if self.Scanner then self.Scanner:Disconnect() end
	if self.AttributeChangedSignal then self.AttributeChangedSignal:Disconnect() end
	if self.Zone1Data.FrameDisplaying then
		TweenStatusFrame(self.Zone1Data.UI:FindFirstChild(self.Zone1Data.Status) :: Frame, "Hide")
		self.Zone1Data.FrameDisplaying = false
	end
	if self.Zone2Data.FrameDisplaying then
		TweenStatusFrame(self.Zone2Data.UI:FindFirstChild(self.Zone2Data.Status) :: Frame, "Hide")
		self.Zone2Data.FrameDisplaying = false
	end
end

function Borders.HideAllBordersInterface(self: BorderType)
	for _, StatusFrame in pairs(self.Zone1Data.UI:QueryDescendants(">Frame")) do
		TweenStatusFrame(StatusFrame, "Hide")
	end
	for _, StatusFrame in pairs(self.Zone2Data.UI:QueryDescendants(">Frame")) do
		TweenStatusFrame(StatusFrame, "Hide")
	end
end

function Borders.new(part: BasePart): BorderType?
	if RunService:IsServer() then
		warn(part.Name .. ": Borders visualize on the client. This instance has no effect.")
		return
	end

	local Border = setmetatable({}, Borders)
	Border.Part = part
	Border.Part.Destroying:Connect(function()
		if Border.Scanner then Border.Scanner:Disconnect() end
		if Border.AttributeChangedSignal then Border.AttributeChangedSignal:Disconnect() end
	end)

	local zone1ID = part:GetAttribute("Zone1") :: string
	local zone2ID = part:GetAttribute("Zone2") :: string
	if not zone1ID or not zone2ID then
		warn(debug.traceback("Zone1/Zone2 is not configured properly!"))
		return
	end
	Border.Zone1Data = {
		ID = zone1ID,
		Status = PrisonZones.GetZoneStatus(zone1ID) or "Restricted",
		UI = part:FindFirstChild(zone1ID) :: SurfaceGui,
		FrameDisplaying = false,
	}
	Border.Zone2Data = {
		ID = zone2ID,
		Status = PrisonZones.GetZoneStatus(zone2ID) or "Restricted",
		UI = part:FindFirstChild(zone2ID) :: SurfaceGui,
		FrameDisplaying = false,
	}

	Border.PacketListenerDisconnect = RoutinePackets.packets.UpdateZoneStatus.listen(function(data)
		if data.name == Border.Zone1 then
			TweenStatusFrame(Border.Part[Border.Zone1][Border.Zone1Status], "Hide")
			Border.Zone1Status = data.status
			Border.Zone2Data.FrameDisplaying = false
		end
		if data.name == Border.Zone2 then
			TweenStatusFrame(Border.Part[Border.Zone2][Border.Zone2Status], "Hide")
			Border.Zone2Status = data.status
			Border.Zone1Data.FrameDisplaying = false
		end
	end)

	LocalPlayer:GetAttributeChangedSignal("CurrentZone"):Connect(function()
		if not Borders.Active then return end
		local zone = LocalPlayer:GetAttribute("CurrentZone") :: string
		if zone == Border.Zone1Data.ID or zone == Border.Zone2Data.ID then
			Border:Activate()
		elseif Border.Zone1Data.FrameDisplaying or Border.Zone2Data.FrameDisplaying then
			Border:Deactivate()
		end
	end)
	table.insert(BorderRegistry, Border)
	return Border
end

return Borders
