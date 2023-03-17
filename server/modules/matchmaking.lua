MATCHMAKING = {}

MATCHMAKING.Queues = {}
MATCHMAKING.Queues["deathmatch"] = { MaxPlayers = 8, Queue = {}, ActiveMatches = {} }
MATCHMAKING.Queues["capturetheflag"] = { MaxPlayers = 6, Queue = {}, ActiveMatches = {} }
MATCHMAKING.Queues["teamdeathmatch"] = { MaxPlayers = 10, Queue = {}, ActiveMatches = {} }
-- Add a table to store party information
MATCHMAKING.Parties = {}

-- Add a table to store average match durations per game mode
MATCHMAKING.AverageMatchDurations = {
    ["deathmatch"] = 300, -- Example: average match duration of 300 seconds
    ["capturetheflag"] = 600,
    ["teamdeathmatch"] = 480
}

function MATCHMAKING.CreateParty(partyID, players)
    MATCHMAKING.Parties[partyID] = players
end

function MATCHMAKING.EstimateWaitTime(mode)
    local queueSize = #MATCHMAKING.Queues[mode].Queue
    local maxPlayers = MATCHMAKING.Queues[mode].MaxPlayers
    local averageMatchDuration = MATCHMAKING.AverageMatchDurations[mode]

    -- Calculate the waiting time estimation based on queue size and average match duration
    local estimatedWaitTime = queueSize * averageMatchDuration / maxPlayers
    return estimatedWaitTime
end

function MATCHMAKING.AddToQueue(partyID, mode)
    local partySkill = 0
    for _, player in ipairs(MATCHMAKING.Parties[partyID]) do
        partySkill = partySkill + PLAYERS.GetSkill(player)
    end
    partySkill = partySkill / #MATCHMAKING.Parties[partyID] -- Calculate the average skill of the party

    local inserted = false
    for i = 1, #MATCHMAKING.Queues[mode].Queue do
        local currentPartyID = MATCHMAKING.Queues[mode].Queue[i]
        local currentPartySkill = 0
        for _, player in ipairs(MATCHMAKING.Parties[currentPartyID]) do
            currentPartySkill = currentPartySkill + PLAYERS.GetSkill(player)
        end
        currentPartySkill = currentPartySkill / #MATCHMAKING.Parties[currentPartyID]

        if partySkill < currentPartySkill then
            table.insert(MATCHMAKING.Queues[mode].Queue, i, partyID)
            inserted = true
            break
        end
    end

    if not inserted then
        table.insert(MATCHMAKING.Queues[mode].Queue, partyID)
    end

    -- Calculate the estimated waiting time
    local estimatedWaitTime = MATCHMAKING.EstimateWaitTime(mode)

    -- Send the estimated waiting time to all players in the party
    for _, player in ipairs(MATCHMAKING.Parties[partyID]) do
        TriggerClientEvent("OnEstimatedWaitTime", player, estimatedWaitTime)
    end

    if #MATCHMAKING.Queues[mode].Queue >= MATCHMAKING.Queues[mode].MaxPlayers and #MATCHMAKING.Queues[mode].ActiveMatches == 0 then
        MATCHMAKING.CreateMatch(mode)
    end
end

function MATCHMAKING.CreateMatch(mode)
    local match = {}
    local maxPlayers = MATCHMAKING.Queues[mode].MaxPlayers

    while #match < maxPlayers and #MATCHMAKING.Queues[mode].Queue > 0 do
        local partyID = table.remove(MATCHMAKING.Queues[mode].Queue, 1)
        local party = MATCHMAKING.Parties[partyID]

        if #party + #match <= maxPlayers then
            for _, player in ipairs(party) do
                table.insert(match, player)
            end
        else
            table.insert(MATCHMAKING.Queues[mode].Queue, 1, partyID) -- Return the party back to the queue
            break
        end
    end


    -- Distribute players between teams in a balanced way
    local teams = {}
    for i = 1, MATCHMAKING.Queues[mode].MaxPlayers // 2 do
        local team1Player = match[2 * i - 1]
        local team2Player = match[2 * i]
        if not teams[1] then teams[1] = {} end
        if not teams[2] then teams[2] = {} end
        table.insert(teams[1], team1Player)
        table.insert(teams[2], team2Player)
    end
    
    table.insert(MATCHMAKING.Queues[mode].ActiveMatches, teams)
    
    print("Match created in " .. mode .. " mode with balanced teams:")
    for i, team in ipairs(teams) do
        print("Team " .. i .. ":")
        for _, player in ipairs(team) do
            print(player .. " (Skill: " .. PLAYERS.GetSkill(player) .. ")")
        end
    end
end


function MATCHMAKING.CheckMatches(mode)
    -- Check active matches for disconnected players
    for i = #MATCHMAKING.Queues[mode].ActiveMatches, 1, -1 do
        local teams = MATCHMAKING.Queues[mode].ActiveMatches[i]

        local disconnected_players = {}
        for team_index, team in ipairs(teams) do
            for j = #team, 1, -1 do
                local player = team[j]

                if GetPlayerPing(player) == 0 then
                    table.remove(team, j)
                    table.insert(disconnected_players, player)
                end
            end
        end

        -- Remove match if all players are disconnected
        if #teams[1] == 0 and #teams[2] == 0 then
            table.remove(MATCHMAKING.Queues[mode].ActiveMatches, i)
            print("Match in " .. mode .. " mode ended.")
        else
            -- Find replacement players for disconnected players
            for _, player in ipairs(disconnected_players) do
                if #MATCHMAKING.Queues[mode].Queue > 0 then
                    local replacement_player = table.remove(MATCHMAKING.Queues[mode].Queue, 1)
                    local teamWithFewestPlayers = (#teams[1] < #teams[2]) and 1 or 2
                    table.insert(teams[teamWithFewestPlayers], replacement_player) -- Add the replacement player to the team with the fewest players
                    print("Replacement player " .. replacement_player .. " joined the match in " .. mode .. " mode.")
                end
            end
        end
    end

    -- Check the queue for disconnected players
    for i = #MATCHMAKING.Queues[mode].Queue, 1, -1 do
        local player = MATCHMAKING.Queues[mode].Queue[i]

        if MATCHMAKING.IsPlayerDisconnected(player) then
            table.remove(MATCHMAKING.Queues[mode].Queue, i)
            print("Player " .. player .. " disconnected from the " .. mode .. " queue.")
        end
    end
end

function MATCHMAKING.IsPlayerDisconnected(player)
    return GetPlayerPing(player) == 0
end

function MATCHMAKING.RemoveDisconnectedPlayersFromQueue(mode)
    local queue = MATCHMAKING.Queues[mode].Queue
    for i = #queue, 1, -1 do
        local player = queue[i]
        if MATCHMAKING.IsPlayerDisconnected(player) then
            table.remove(queue, i)
            print("Player " .. player .. " disconnected from the " .. mode .. " queue.")
        end
    end
end

function MATCHMAKING.MatchmakingLoop(mode)
    while true do
        Wait(1000)
        MATCHMAKING.CheckMatches(mode)

        if #MATCHMAKING.Queues[mode].Queue >= MATCHMAKING.Queues[mode].TeamSize then
            MATCHMAKING.CreateMatch(mode)
        end
    end
end

function MATCHMAKING.SimulatePlayers()
    for i = 1, 5 do
        local partyID = "Party " .. i
        local players = {"Player " .. (2 * i - 1), "Player " .. (2 * i)}
        MATCHMAKING.CreateParty(partyID, players)
        MATCHMAKING.AddToQueue(partyID, "deathmatch")
        MATCHMAKING.AddToQueue(partyID, "capturetheflag")
        MATCHMAKING.AddToQueue(partyID, "teamdeathmatch")
    end
end

function MATCHMAKING.StartMatchmaking()
    for mode, config in pairs(MATCHMAKING.Queues) do
        CreateThread(function() MATCHMAKING.MatchmakingLoop(mode) end)
    end
end

MATCHMAKING.SimulatePlayers()
MATCHMAKING.StartMatchmaking()