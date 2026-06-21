--[[
The prison uses various zones which are toggled restricted/cleared/transitional when someone steps foot into it. This is one of the few scripts I designed along with a few other people as a way to update zones
based on the current period and keep track and notify players when they stepped into a new zone

you'll notice we swapepd out the remoteevents with the blink idl, one difference is that we've started adopting uses of certain libraries to better manage the scale of the game
]]

local CollectionService = game:GetService("CollectionService")
-- local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerPackets = nil
local ClientPackets = nil
if RunService:IsServer() then ServerPackets = require(ServerScriptService.Server.ServerPackets) end
if RunService:IsClient() then ClientPackets = require(ReplicatedStorage.Shared.ClientPackets) end

local ZoneCache = require(script.ZoneCache)
local Zone = require(ReplicatedStorage.Shared.Libraries.Zone)
local RoutinePackets = require(ReplicatedStorage.Shared.Packets.RoutinePackets)

local PrisonZones = {
	PrisonLookup = {},
	PeriodLookup = {},
}
PrisonZones.__index = PrisonZones

type ZoneProperties = {
	ID: string, -- identifier of the zone
	Status: string?, -- current status of the zoneregion
	ApprovedPeriods: { string }, -- allowed periods of the zone
	Zone: any,
}

export type PrisonZoneType = typeof(setmetatable({} :: ZoneProperties, PrisonZones))

type ZoneStatus = {}

function PrisonZones.new(ZoneObject: Instance): PrisonZoneType?
	if RunService:IsClient() then
		warn("Cannot make zone objects on client. This zone has no effect.")
		return nil
	end

	local PrisonZone = setmetatable({}, PrisonZones)

	PrisonZone.ID = ZoneObject:GetAttribute("ZoneID")
	PrisonZone.Status = "Restricted"
	PrisonZone.Zone = Zone.new(ZoneObject)
	PrisonZone.Zone:bindToGroup("EnterOnlyOneZoneAtATime")
	PrisonZone.ApprovedPeriods = CollectionService:GetTags(ZoneObject)
	PrisonZone.Zone.playerEntered:Connect(function(plr: Player)
		local ExistingZone = plr:GetAttribute("CurrentZone")
		plr:SetAttribute("CurrentZone", PrisonZone.ID)
		if not ExistingZone then
			warn("No Zone currently assigned to player!")
		elseif PrisonZone.Status == PrisonZones.GetZoneStatus(ExistingZone) then --do not warn if no status change between zones.
			return
		end

		if PrisonZone.Status == "Transitional" then
			ServerPackets.ClockPackets.NotifyPlayer.Fire(plr, "Transitional")
		elseif PrisonZone.Status == "Restricted" then
			ServerPackets.ClockPackets.NotifyPlayer.Fire(plr, "Restricted")
		end
	end)

	RoutinePackets.packets.UpdateZoneStatus.sendToAll({ name = PrisonZone.ID, status = PrisonZone.Status })

	PrisonZone:RegisterZone()

	return PrisonZone
end

function PrisonZones.RegisterZone(self: PrisonZoneType)
	local id = self.ID
	if not PrisonZones.PrisonLookup[id] then PrisonZones.PrisonLookup[id] = {} end
	table.insert(PrisonZones.PrisonLookup[id], self)
	for _, period in self.ApprovedPeriods do
		if not PrisonZones.PeriodLookup[period] then PrisonZones.PeriodLookup[period] = {} end
		table.insert(PrisonZones.PeriodLookup[period], self)
	end
end

function PrisonZones.GetZoneStatus(zoneName: string)
	if RunService:IsClient() then
		local CachedStatus = ZoneCache.StatusPerZone[zoneName]
		if CachedStatus then return CachedStatus end

		local data = ClientPackets.ZonePackets.GetZoneInfo.Invoke(zoneName)
		ZoneCache.StatusPerZone[zoneName] = data
		return data
	end
	if PrisonZones.PrisonLookup[zoneName] then
		return PrisonZones.PrisonLookup[zoneName][1].Status
	else
		warn("No such Zone: " .. zoneName)
	end
	return nil
end

function PrisonZones.updatePlayerStatus(self: PrisonZoneType)
	for _, player in self.Zone:getPlayers() do
		if self.Status == "Transitional" then
			ServerPackets.ClockPackets.NotifyPlayer.Fire(player, "Transitional")
		elseif self.Status == "Restricted" then
			ServerPackets.ClockPackets.NotifyPlayer.Fire(player, "Restricted")
		end
	end
end

function PrisonZones.ChangeStatus(self: PrisonZoneType, status: string)
	if RunService:IsClient() then warn("Cannot manipulate zones on client!") end

	self.Status = status
	self:updatePlayerStatus()
	RoutinePackets.packets.UpdateZoneStatus.sendToAll({ name = self.ID, status = self.Status })
end

if RunService:IsServer() then
	ServerPackets.ZonePackets.GetZoneInfo.On(function(_plr: Player, ID: string): string
		return PrisonZones.GetZoneStatus(ID)
	end)
end

return PrisonZones
