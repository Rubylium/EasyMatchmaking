-- Add event handlers for custom events
AddEventHandler("MATCHMAKING:PlayerJoinedQueue", function(player, mode)
    print("Player " .. player .. " joined the " .. mode .. " queue.")
end)

AddEventHandler("MATCHMAKING:PlayerLeftQueue", function(player, mode)
    print("Player " .. player .. " left the " .. mode .. " queue.")
end)

AddEventHandler("MATCHMAKING:MatchStarted", function(mode, matchID)
    print("Match " .. matchID .. " started in " .. mode .. " mode.")
end)

AddEventHandler("MATCHMAKING:MatchEnded", function(mode, matchID)
    print("Match " .. matchID .. " ended in " .. mode .. " mode.")
end)
