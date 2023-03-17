PLAYERS = {}
PLAYERS.List = {}

-- Function to add a player to the PLAYERS list
function PLAYERS.Add(playerId, level, skill)
    table.insert(PLAYERS.List, {id = playerId, level = level, skill = skill})
end

-- Function to remove a player from the PLAYERS list
function PLAYERS.Remove(playerId)
    for i, player in ipairs(PLAYERS.List) do
        if player.id == playerId then
            table.remove(PLAYERS.List, i)
            return
        end
    end
end

-- Function to get a player's skill
function PLAYERS.GetSkill(playerId)
    for _, player in ipairs(PLAYERS.List) do
        if player.id == playerId then
            return player.skill
        end
    end
end

-- Function to update a player's skill
function PLAYERS.UpdateSkill(playerId, newSkill)
    for _, player in ipairs(PLAYERS.List) do
        if player.id == playerId then
            player.skill = newSkill
            return
        end
    end
end

-- Replace the previous GetPlayerSkill function with this one that uses the PLAYERS API
function GetPlayerSkill(player)
    return PLAYERS.GetSkill(player)
end

-- Example usage of the PLAYERS API
PLAYERS.Add(1, 1, 1000)
PLAYERS.Add(2, 2, 1100)
PLAYERS.Add(3, 3, 1200)

print("Player 1's skill: " .. PLAYERS.GetSkill(1))
PLAYERS.UpdateSkill(1, 1300)
print("Player 1's updated skill: " .. PLAYERS.GetSkill(1))
PLAYERS.Remove(1)