local Matchmaking = {}
Matchmaking.__index = Matchmaking

-- Constructor for the Matchmaking class
function Matchmaking.new()
    local self = setmetatable({}, Matchmaking)
    self.matches = {}
    self.queues = {
        ["deathmatch"] = { maxPlayers = 8, queue = {} },
        ["capturetheflag"] = { maxPlayers = 6, queue = {} },
        ["teamdeathmatch"] = { maxPlayers = 10, queue = {} },
    }
    self.parties = {}
    self.averageMatchDurations = {
        ["deathmatch"] = 300,
        ["capturetheflag"] = 600,
        ["teamdeathmatch"] = 480
    }
    return self
end

-- Create a party with the given ID and players
function Matchmaking:createParty(partyID, players)
    self.parties[partyID] = players
end

-- Estimate the wait time for a player in the given game mode
function Matchmaking:estimateWaitTime(mode)
    local queueSize = #self.queues[mode].queue
    local maxPlayers = self.queues[mode].maxPlayers
    local averageMatchDuration = self.averageMatchDurations[mode]

    local estimatedWaitTime = queueSize * averageMatchDuration / maxPlayers
    return estimatedWaitTime
end

function Matchmaking:getAveragePartySkill(partyID)
    local partySkill = 0
    for _, player in ipairs(self.parties[partyID]) do
        partySkill = partySkill + player:GetSkill()
    end
    return partySkill / #self.parties[partyID]
end

-- Add a party to the queue for a specified game mode
function Matchmaking:addToQueue(partyID, mode)
    local partySkill = self:getAveragePartySkill(partyID)

    local inserted = false
    for queueIndex = 1, #self.queues[mode].queue do
        local currentPartyID = self.queues[mode].queue[queueIndex]
        local currentPartySkill = self:getAveragePartySkill(currentPartyID)

        if partySkill < currentPartySkill then
            table.insert(self.queues[mode].queue, queueIndex, partyID)
            inserted = true
            break
        end
    end

    if not inserted then
        table.insert(self.queues[mode].queue, partyID)
    end

    self:removeDisconnectedPlayersFromQueue(mode)

    local estimatedWaitTime = self:estimateWaitTime(mode)

    for _, player in ipairs(self.parties[partyID]) do
        TriggerClientEvent("OnEstimatedWaitTime", player, estimatedWaitTime)
        self:onPlayerJoinedQueue(player, mode)
    end

    local queuedPlayers = 0
    for _, queuedPartyID in ipairs(self.queues[mode].queue) do
        queuedPlayers = queuedPlayers + #self.parties[queuedPartyID]
    end

    if queuedPlayers >= self.queues[mode].maxPlayers then
        self:createMatch(mode)
    end
    print("Party " .. partyID .. " added to the " .. mode .. " queue.")
end

-- Fill a match with parties from the queue for the given game mode
function Matchmaking:fillMatchWithParties(match, mode)
    local maxPlayers = self.queues[mode].maxPlayers

    while #match < maxPlayers and #self.queues[mode].queue > 0 do
        local partyID = table.remove(self.queues[mode].queue, 1)
        local party = self.parties[partyID]

        if #party + #match <= maxPlayers then
            for _, player in ipairs(party) do
                table.insert(match, player)
            end
        else
            table.insert(self.queues[mode].queue, 1, partyID) -- Return the party back to the queue
            break
        end
    end
end

-- Distribute players evenly into two teams for the given match and game mode
function Matchmaking:distributePlayersToTeams(match, mode)
    local teams = {}
    local maxPlayers = self.queues[mode].maxPlayers

    for i = 1, maxPlayers // 2 do
        local team1Player = match[2 * i - 1]
        local team2Player = match[2 * i]
        if not teams[1] then teams[1] = {} end
        if not teams[2] then teams[2] = {} end
        table.insert(teams[1], team1Player)
        table.insert(teams[2], team2Player)
    end

    return teams
end

-- Create a new match for the given game mode
function Matchmaking:createMatch(mode)
    local matchID = generateUUID()

    local match = {
        ID = matchID,
        Mode = mode,
        Players = {},
        StartTime = os.time(),
    }

    self:fillMatchWithParties(match.Players, mode)
    match.teams = self:distributePlayersToTeams(match.Players, mode)

    table.insert(self.matches, match)

    print("Match created in " .. mode .. " mode with balanced teams (Match ID: " .. matchID .. ")")
    -- Trigger the custom event
    self:onMatchStarted(mode, matchID)
end

-- Check the status of ongoing matches for the given game mode
function Matchmaking:checkMatches(mode)
    print("Checking matches for mode: " .. mode)
    for i = #self.matches, 1, -1 do
        local match = self.matches[i]

        if match.Mode == mode then
            local teams = match.teams
            local disconnectedPlayers = {}
            for teamIndex, team in ipairs(teams) do
                for j = #team, 1, -1 do
                    local player = team[j]
    
                    if self:isPlayerDisconnected(player) then
                        table.remove(team, j)
                        table.insert(disconnectedPlayers, player)
                    end
                end
            end
    
            -- Remove match if all players are disconnected
            if #teams[1] == 0 and #teams[2] == 0 then
                local matchID = match.ID
                table.remove(self.matches, i)
                print("Match in " .. mode .. " mode ended (Match ID: " .. matchID .. ")")

                -- Trigger the custom event
                self:onMatchEnded(mode, matchID)
            else
                -- Find replacement players for disconnected players
                for _, player in ipairs(disconnectedPlayers) do
                    if #self.queues[mode].queue > 0 then
                        local replacementPlayer = table.remove(self.queues[mode].queue, 1)
                        local teamWithFewestPlayers = (#teams[1] < #teams[2]) and 1 or 2
                        table.insert(teams[teamWithFewestPlayers], replacementPlayer) -- Add the replacement player to the team with the fewest players
                        print("Replacement player " .. replacementPlayer .. " joined the match in " .. mode .. " mode.")
                    end
                end
            end
        end
    end

    -- Check the queue for disconnected players
    for i = #self.queues[mode].queue, 1, -1 do
        local player = self.queues[mode].queue[i]

        if self:isPlayerDisconnected(player) then
            table.remove(self.queues[mode].queue, i)
            print("Player " .. player .. " disconnected from the " .. mode .. " queue.")
        end
    end
end

-- Check if a player is disconnected
function Matchmaking:isPlayerDisconnected(player)
    return GetPlayerPing(player) == 0
end

-- Remove disconnected players from the queue for the given game mode
function Matchmaking:removeDisconnectedPlayersFromQueue(mode)
    local queue = self.queues[mode].queue
    for i = #queue, 1, -1 do
        local player = queue[i]
        if self:isPlayerDisconnected(player) then
            table.remove(queue, i)
            print("Player " .. player .. " disconnected from the " .. mode .. " queue.")
        end
    end
end

-- Continuously check matches and create new matches as needed for the given game mode
function Matchmaking:matchmakingLoop(mode)
    while true do
        Wait(1000)
        self:checkMatches(mode)

        if #self.queues[mode].queue >= self.queues[mode].maxPlayers then
            self:createMatch(mode)
        end
    end
end

-- Simulate players joining parties and entering queues for testing purposes
function Matchmaking:simulatePlayers()
    for i = 1, 5 do
        local partyID = "Party " .. i
        local players = {"Player " .. (2 * i - 1), "Player " .. (2 * i)}
        self:createParty(partyID, players)
        self:addToQueue(partyID, "deathmatch")
        self:addToQueue(partyID, "capturetheflag")
        self:addToQueue(partyID, "teamdeathmatch")
    end
end

-- Start the matchmaking process for all game modes
function Matchmaking:startMatchmaking()
    for mode, config in pairs(self.queues) do
        CreateThread(function() self:matchmakingLoop(mode) end)
    end
end

-- Add custom events for monitoring
function Matchmaking:OnPlayerJoinedQueue(player, mode)
    TriggerEvent("MATCHMAKING:PlayerJoinedQueue", player, mode)
end

function Matchmaking:OnPlayerLeftQueue(player, mode)
    TriggerEvent("MATCHMAKING:PlayerLeftQueue", player, mode)
end

function Matchmaking:OnMatchStarted(mode, matchID)
    TriggerEvent("MATCHMAKING:MatchStarted", mode, matchID)
end

function Matchmaking:OnMatchEnded(mode, matchID)
    TriggerEvent("MATCHMAKING:MatchEnded", mode, matchID)
end


-- Instantiate the Matchmaking class and start the matchmaking process
local matchmaking = Matchmaking.new()
matchmaking:SimulatePlayers()
matchmaking:StartMatchmaking()