MATCHMAKING = {}

MATCHMAKING.Matches = {}
MATCHMAKING.Queues = {}
MATCHMAKING.Queues = {
    ["deathmatch"] = { MaxPlayers = 8, Queue = {} },
    ["capturetheflag"] = { MaxPlayers = 6, Queue = {} },
    ["teamdeathmatch"] = { MaxPlayers = 10, Queue = {} },
}
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
    for queueIndex = 1, #MATCHMAKING.Queues[mode].Queue do
        local currentPartyID = MATCHMAKING.Queues[mode].Queue[queueIndex]
        local currentPartySkill = 0
        for _, player in ipairs(MATCHMAKING.Parties[currentPartyID]) do
            currentPartySkill = currentPartySkill + PLAYERS.GetSkill(player)
        end
        currentPartySkill = currentPartySkill / #MATCHMAKING.Parties[currentPartyID]

        if partySkill < currentPartySkill then
            table.insert(MATCHMAKING.Queues[mode].Queue, queueIndex, partyID)
            inserted = true
            break
        end
    end

    if not inserted then
        table.insert(MATCHMAKING.Queues[mode].Queue, partyID)
    end

    -- Remove disconnected players from the queue
    MATCHMAKING.RemoveDisconnectedPlayersFromQueue(mode)

    -- Calculate the estimated waiting time
    local estimatedWaitTime = MATCHMAKING.EstimateWaitTime(mode)

    -- Send the estimated waiting time to all players in the party
    for _, player in ipairs(MATCHMAKING.Parties[partyID]) do
        TriggerClientEvent("OnEstimatedWaitTime", player, estimatedWaitTime)
        MATCHMAKING.OnPlayerJoinedQueue(player, mode)
    end

    local queuedPlayers = 0
    for _, queuedPartyID in ipairs(MATCHMAKING.Queues[mode].Queue) do
        queuedPlayers = queuedPlayers + #MATCHMAKING.Parties[queuedPartyID]
    end

    if queuedPlayers >= MATCHMAKING.Queues[mode].MaxPlayers then
        MATCHMAKING.CreateMatch(mode)
    end
    print("Party " .. partyID .. " added to the " .. mode .. " queue.")
end

function MATCHMAKING.FillMatchWithParties(match, mode)
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
end

function MATCHMAKING.DistributePlayersToTeams(match, mode)
    local teams = {}
    for i = 1, MATCHMAKING.Queues[mode].MaxPlayers // 2 do
        local team1Player = match[2 * i - 1]
        local team2Player = match[2 * i]
        if not teams[1] then teams[1] = {} end
        if not teams[2] then teams[2] = {} end
        table.insert(teams[1], team1Player)
        table.insert(teams[2], team2Player)
    end

    return teams
end

function MATCHMAKING.CreateMatch(mode)
    local matchID = generateUUID()

    local match = {
        ID = matchID,
        Mode = mode,
        Players = {},
        StartTime = os.time(),
    }

    MATCHMAKING.FillMatchWithParties(match.Players, mode)
    match.teams = MATCHMAKING.DistributePlayersToTeams(match.Players, mode)

    table.insert(MATCHMAKING.Matches, match)

    print("Match created in " .. mode .. " mode with balanced teams (Match ID: " .. matchID .. ")")
    -- Trigger the custom event
    MATCHMAKING.OnMatchStarted(mode, matchID)
end


function MATCHMAKING.CheckMatches(mode)
    print("Checking matches for mode: " .. mode)
    for i = #MATCHMAKING.Matches, 1, -1 do
        local match = MATCHMAKING.Matches[i]

        if match.mode == mode then
            local teams = match.teams
            local disconnected_players = {}
            for team_index, team in ipairs(teams) do
                for j = #team, 1, -1 do
                    local player = team[j]
    
                    if MATCHMAKING.IsPlayerDisconnected(player) then
                        table.remove(team, j)
                        table.insert(disconnected_players, player)
                    end
                end
            end
    
            -- Remove match if all players are disconnected
            if #teams[1] == 0 and #teams[2] == 0 then
                local matchID = match.id
                table.remove(MATCHMAKING.Matches, i)
                print("Match in " .. mode .. " mode ended (Match ID: " .. matchID .. ")")

                -- Trigger the custom event
                MATCHMAKING.OnMatchEnded(mode, matchID)
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

-- Add custom events for monitoring
function MATCHMAKING.OnPlayerJoinedQueue(player, mode)
    TriggerEvent("MATCHMAKING:PlayerJoinedQueue", player, mode)
end

function MATCHMAKING.OnPlayerLeftQueue(player, mode)
    TriggerEvent("MATCHMAKING:PlayerLeftQueue", player, mode)
end

function MATCHMAKING.OnMatchStarted(mode, matchID)
    TriggerEvent("MATCHMAKING:MatchStarted", mode, matchID)
end

function MATCHMAKING.OnMatchEnded(mode, matchID)
    TriggerEvent("MATCHMAKING:MatchEnded", mode, matchID)
end


MATCHMAKING.SimulatePlayers()
MATCHMAKING.StartMatchmaking()