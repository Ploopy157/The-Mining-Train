local Label = script.Parent.TextLabel
local Event = game.ReplicatedStorage.OreInfoEvent
local timeout = 2.5
local currenttime = 0

Event.OnClientEvent:Connect(function(text)
	Label.TextTransparency = 0
	script.Parent.Enabled = true
	Label.Text = text
	currenttime = timeout
end)


while true do
	wait(.5)
	if currenttime > 0 then
		currenttime -= 1
		if currenttime < 1 then
			while currenttime <1 and currenttime > 0 do
				Label.TextTransparency += .1
				wait(.1)
			end
		end
	else 
		script.Parent.Enabled = false
	end
end