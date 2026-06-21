--[[
Original code all written by me, with few tweaks from other contributors to update it.
This was my original probationary task. I designed it in mind with the various things a door could have.
It could open, close, be locked, may have a schedule, can autoclose, or need certain clearances. The schedule
and lock are separate components to reuse these parts like the lock for other systems, like adding permissions
to access other things.

It was then updated to handle the tweening and audio on the client to improve performance. We use
separate modules to keep track of the data 


]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenStyles = require(ReplicatedStorage.Shared.Configuration.DoorData.TweenStyles)
local ServerPackets = require(ServerScriptService.Server.ServerPackets)
local Lock = require(script.Parent.Lock)

local Doors = {}
Doors.__index = Doors

local DEFAULT_CLOSE_DELAY = 3

export type DoorConfig = {
	Lock: Lock.LockType?, -- what perms the door uses
	Schedule: any, -- WIP, used to schedule-open/close a door.
	AutoClose: boolean?, -- if the door closes by itself
	AutoCloseDelay: number?, -- how long until the door closes
	NoPrompt: boolean?, -- if the door is interactable with
	TweenCodes: { -- customizable tweens
		Open: string, -- code for opening properties
		Close: string, -- code for closing properties
	},
	SoundCode: string?, -- sound folder to use
}

type MovePartData = {
	Rig: BasePart,
	Model: Instance,
	Node1: CFrame,
	Node2: CFrame,
	SnapToStart: boolean?,
}

type DoorData = {
	-- model components
	MoveParts: { MovePartData },
	Configs: DoorConfig,
	-- status
	IsOpen: boolean,
	AutoCloseThread: thread?,
}

export type DoorType = typeof(setmetatable({} :: DoorData, Doors))

function Doors.new(moveParts: { MovePartData }, configs: DoorConfig): DoorType
	local Door = setmetatable({}, Doors)
	Door.MoveParts = moveParts

	for _, movePart in ipairs(moveParts) do
		if movePart.SnapToStart then movePart.Rig.CFrame = movePart.Node1 end
	end

	Door.Configs = configs
	Door.Configs.AutoCloseDelay = Door.Configs.AutoCloseDelay or DEFAULT_CLOSE_DELAY

	Door.IsOpen = false
	Door.AutoCloseThread = nil
	return Door
end

local function toggleColl(instance: Instance, state: boolean)
	if instance:IsA("BasePart") and instance.Name ~= "RigPart" then
		instance.CanCollide = state
		instance.CanQuery = state
	end
	for _, child in ipairs(instance:GetDescendants()) do
		if child:IsA("BasePart") and child.Name ~= "RigPart" then
			child.CanCollide = state
			child.CanQuery = state
		end
	end
end

function Doors.Open(self: DoorType): RBXScriptSignal
	self.IsOpen = true
	for _, movePart in ipairs(self.MoveParts) do
		toggleColl(movePart.Model, false)
		ServerPackets.DoorPackets.ReplicateDoor.FireAll({
			Action = "Move",
			Rig = movePart.Rig,
			Target = movePart.Node2,
			TweenCode = self.Configs.TweenCodes.Open,
			SoundCode = self.Configs.SoundCode,
		})
	end
	local tweenCode = self.Configs.TweenCodes.Open
	local tweenInfo = TweenStyles[tweenCode]
	local signal = Instance.new("BindableEvent")
	task.delay(tweenInfo.Time, function()
		for _, movePart in ipairs(self.MoveParts) do
			toggleColl(movePart.Model, true)
		end
		signal:Fire()
		signal:Destroy()
	end)

	return signal.Event
end

function Doors.Close(self: DoorType): RBXScriptSignal
	self.IsOpen = false
	for _, movePart in ipairs(self.MoveParts) do
		toggleColl(movePart.Model, false)
		ServerPackets.DoorPackets.ReplicateDoor.FireAll({
			Action = "Move",
			Rig = movePart.Rig,
			Target = movePart.Node1,
			TweenCode = self.Configs.TweenCodes.Open,
			SoundCode = self.Configs.SoundCode,
		})
	end

	if self.Configs.Lock then
		local lock = self.Configs.Lock :: Lock.LockType
		lock:Lock()
	end

	local signal = Instance.new("BindableEvent")
	local tweenCode = self.Configs.TweenCodes.Close
	local tweenInfo = TweenStyles[tweenCode]
	task.delay(tweenInfo.Time, function()
		for _, movePart in ipairs(self.MoveParts) do
			toggleColl(movePart.Model, true)
		end
		signal:Fire()
		signal:Destroy()
	end)

	return signal.Event
end

return Doors
