Player = {}
Player.__index = Player

function Player:new(playerId, level, skill)
    local self = setmetatable({}, Player)
    self.id = playerId
    self.level = level
    self.skill = skill
    return self
end

PlayerList = {
    players = {}
}

function PlayerList:set(player)
    if self.players[player.id] then
        self.players[player.id].level = player.level
        self.players[player.id].skill = player.skill
        MySQL.update.await('UPDATE player_data SET level = ?, skill = ? WHERE player_id = ?', {player.level, player.skill, player.id})
    else
        self.players[player.id] = player
        MySQL.insert.await('INSERT INTO player_data (player_id, level, skill) VALUES (?, ?, ?)', {player.id, player.level, player.skill})
    end
end

function PlayerList:add(playerId)
    local result = MySQL.query.await('SELECT * FROM player_data WHERE player_id = ?', {playerId})
    if #result > 0 then
        local data = result[1]
        self.players[playerId] = Player:new(playerId, data.level, data.skill)
    end
end

function PlayerList:getSkill(playerId)
    if self.players[playerId] then
        return self.players[playerId].skill
    end
    return nil
end

function PlayerList:getLevel(playerId)
    if self.players[playerId] then
        return self.players[playerId].level
    end
    return nil
end

function PlayerList:delete(playerId)
    if self.players[playerId] then
        self.players[playerId] = nil
        local affectedRows = MySQL.update.await('DELETE FROM player_data WHERE player_id = ?', {playerId})
        return affectedRows > 0
    end
    return false
end

players = PlayerList
