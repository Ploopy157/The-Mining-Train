local Event = game.ReplicatedStorage:WaitForChild("OreInfoEvent")

game.ServerRestartScheduled:Connect(function(RestartTime)
    Event:FireAllClients("Server restart scheduled in " .. RestartTime .. " seconds.")
end)