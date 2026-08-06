local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OreInfoEvent = ReplicatedStorage:WaitForChild("OreInfoEvent")

local function GetMinutesUntilRestart(RestartTime)
	local CurrentTime = DateTime.now()
	local MillisecondsRemaining = RestartTime.UnixTimestampMillis - CurrentTime.UnixTimestampMillis
	local SecondsRemaining = math.max(0, MillisecondsRemaining / 1000)

	return math.ceil(SecondsRemaining / 60)
end

game.ServerRestartScheduled:Connect(function(RestartTime)
	local MinutesRemaining = GetMinutesUntilRestart(RestartTime)
	local MinuteWord = MinutesRemaining == 1 and "minute" or "minutes"
	local Message = string.format("Server restart scheduled in %d %s.", MinutesRemaining, MinuteWord)

	OreInfoEvent:FireAllClients(Message)
end)