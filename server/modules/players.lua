PLAYERS = {
    List = {}
}

-- Insert a new player or update an existing one
function PLAYERS.Set(playerId, level, skill)
    if PLAYERS.List[playerId] then
        PLAYERS.List[playerId].level = level
        PLAYERS.List[playerId].skill = skill
        MySQL.update.await('UPDATE player_data SET level = ?, skill = ? WHERE player_id = ?', {level, skill, playerId})
    else
        PLAYERS.List[playerId] = {
            id = playerId,
            level = level,
            skill = skill
        }
        MySQL.insert.await('INSERT INTO player_data (player_id, level, skill) VALUES (?, ?, ?)', {playerId, level, skill})
    end
end

-- Add player data to cache
function PLAYERS.Add(playerId)
    local result = MySQL.query.await('SELECT * FROM player_data WHERE player_id = ?', {playerId})
    if #result > 0 then
        local data = result[1]
        PLAYERS.List[playerId] = {
            id = playerId,
            level = data.level,
            skill = data.skill
        }
    end
end

-- Get the skill of a player
function PLAYERS.GetSkill(playerId)
    if PLAYERS.List[playerId] then
        return PLAYERS.List[playerId].skill
    end
    return nil
end

-- Get the level of a player
function PLAYERS.GetLevel(playerId)
    if PLAYERS.List[playerId] then
        return PLAYERS.List[playerId].level
    end
    return nil
end

-- Delete a player
function PLAYERS.Delete(playerId)
    if PLAYERS.List[playerId] then
        PLAYERS.List[playerId] = nil
        local affectedRows = MySQL.update.await('DELETE FROM player_data WHERE player_id = ?', {playerId})
        return affectedRows > 0
    end
    return false
end
