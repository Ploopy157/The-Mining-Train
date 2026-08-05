local Workspace = game:GetService("Workspace")
script.Parent.Label.Text = "00:00:00"

while true do
	task.wait(1)
	local SecondsRemaining = Workspace:GetAttribute("MineResetSecondsRemaining")
	local time = os.date("!*t", SecondsRemaining)
	local formattedTime = string.format("%02d:%02d:%02d", time.hour, time.min, time.sec)
	script.Parent.Label.Text = ("The Mine will reset in: "..formattedTime)
end