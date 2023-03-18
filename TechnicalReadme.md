# Technical README: Matchmaking System for Game Modes (Theoretical Implementation)

This document provides a more in-depth overview of the theoretical matchmaking system implemented as a `Matchmaking` class in `matchmaking.lua`.

## Matchmaking Class

The `Matchmaking` class consists of the following methods:

### Constructor

- `Matchmaking.new()`: Initializes a new instance of the Matchmaking class with default values for matches, queues, parties, and average match durations.

### Party Management

- `Matchmaking:createParty(partyID, players)`: Creates a party with the given ID and players.

### Wait Time Estimation

- `Matchmaking:estimateWaitTime(mode)`: Estimates the wait time for a player in the given game mode.

### Queue Management

- `Matchmaking:addToQueue(partyID, mode)`: Adds a party to the queue for the specified game mode.
- `Matchmaking:removeDisconnectedPlayersFromQueue(mode)`: Removes disconnected players from the queue for the given game mode.
- `Matchmaking:addToPriorityQueue(partyID, mode)`: Adds a party to the priority queue for the specified game mode if they have been waiting longer than a predefined threshold.

### Match Creation and Management

- `Matchmaking:fillMatchWithParties(match, mode)`: Fills a match with parties from the queue for the given game mode.
- `Matchmaking:distributePlayersToTeams(match, mode)`: Distributes players evenly into two teams for the given match and game mode.
- `Matchmaking:createMatch(mode)`: Creates a new match for the given game mode.
- `Matchmaking:checkMatches(mode)`: Checks the status of ongoing matches for the given game mode.

### Matchmaking Loop

- `Matchmaking:matchmakingLoop(mode)`: Continuously checks matches and creates new matches as needed for the given game mode.

### Spectator Mode

- `Matchmaking:addSpectator(spectatorID, matchID)`: Adds a player as a spectator to the specified match.

### Custom Events

- `Matchmaking:onPlayerJoinedQueue(player, mode)`: Triggers when a player joins the queue for a game mode.
- `Matchmaking:onPlayerLeftQueue(player, mode)`: Triggers when a player leaves the queue for a game mode.
- `Matchmaking:onMatchStarted(mode, matchID)`: Triggers when a match starts for a game mode.
- `Matchmaking:onMatchEnded(mode, matchID)`: Triggers when a match ends for a game mode.

## Extending the System

To extend the system with additional game modes or functionalities, follow these steps:

1. Add a new game mode to the `queues` and `averageMatchDurations` tables with the desired maximum number of players and average match duration.
2. Modify the matchmaking loop (`matchmakingLoop`) and other methods as necessary to accommodate the new game mode.
3. Implement custom events or any additional logic required for the new game mode.

Please note that this code is **not intended to work as-is** but serves as a logical framework for implementing a matchmaking system.
