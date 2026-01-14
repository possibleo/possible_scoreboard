lib.locale()

local config = require('shared.config')
local Framework = require('shared.bridge')

---Checks if a player has any of the configured staff ace permissions
---@param playerId string The player server ID as a string
---@return boolean True if player has staff permissions
local function isPlayerStaff(playerId)
    for _, ace in ipairs(config.StaffAces) do
        if IsPlayerAceAllowed(playerId, ace) then
            return true
        end
    end
    return false
end

lib.callback.register('possible_scoreboard:server:getPlayers', function(source)
    local players = {}
    local allPlayers = GetPlayers()

    for _, playerId in ipairs(allPlayers) do
        local src = tonumber(playerId)
        if src then
            local rpName = Framework.getPlayerName(src)
            local steamName = GetPlayerName(src) or 'Unknown'
            local playerJob = Framework.getPlayerJob(src)
            local ping = GetPlayerPing(src)
            local staff = isPlayerStaff(tostring(src))

            players[#players + 1] = {
                id = src,
                name = rpName,
                steamName = steamName,
                ping = ping,
                job = playerJob,
                isStaff = staff
            }
        end
    end

    table.sort(players, function(a, b)
        return a.id < b.id
    end)

    return players
end)

lib.callback.register('possible_scoreboard:server:getConfig', function(source)
    return {
        showServices = true,
        theme = config.Theme,
        jobs = config.Jobs,
        staffAces = config.StaffAces,
        isViewerStaff = isPlayerStaff(tostring(source)),
        localPlayerId = source
    }
end)

lib.callback.register('possible_scoreboard:server:getPlayerDetails', function(source, targetPlayerId)
    if not isPlayerStaff(tostring(source)) then
        return nil
    end

    local targetPed = GetPlayerPed(targetPlayerId)
    if not targetPed or targetPed == 0 then
        return nil
    end

    local identifiers = GetPlayerIdentifiers(targetPlayerId)
    local parsed = {}
    for _, id in ipairs(identifiers) do
        local prefix, value = id:match('^([^:]+):(.+)$')
        if prefix and value and prefix ~= 'ip' then
            parsed[prefix] = value
        end
    end

    return {
        id = targetPlayerId,
        name = Framework.getPlayerName(targetPlayerId),
        steamName = GetPlayerName(targetPlayerId) or 'Unknown',
        ping = GetPlayerPing(targetPlayerId),
        job = Framework.getPlayerJob(targetPlayerId),
        isStaff = isPlayerStaff(tostring(targetPlayerId)),
        identifiers = parsed
    }
end)

lib.callback.register('possible_scoreboard:server:staffAction', function(source, action, targetPlayerId)
    if not isPlayerStaff(tostring(source)) then
        return { success = false, message = locale('unauthorized') }
    end

    local targetPed = GetPlayerPed(targetPlayerId)
    if not targetPed or targetPed == 0 then
        return { success = false, message = locale('player_not_found') }
    end

    local targetCoords = GetEntityCoords(targetPed)
    local sourcePed = GetPlayerPed(source)
    local sourceCoords = GetEntityCoords(sourcePed)

    if action == 'teleport' then
        TriggerClientEvent('possible_scoreboard:client:teleportTo', source, {
            x = targetCoords.x,
            y = targetCoords.y,
            z = targetCoords.z
        })
        return { success = true }

    elseif action == 'bring' then
        TriggerClientEvent('possible_scoreboard:client:teleportTo', targetPlayerId, {
            x = sourceCoords.x,
            y = sourceCoords.y,
            z = sourceCoords.z
        })
        return { success = true }

    elseif action == 'freeze' then
        local isFrozen = Player(targetPlayerId).state['possible_scoreboard:frozen'] or false
        Player(targetPlayerId).state:set('possible_scoreboard:frozen', not isFrozen, true)
        TriggerClientEvent('possible_scoreboard:client:setFreeze', targetPlayerId, not isFrozen)
        return { success = true, frozen = not isFrozen }

    elseif action == 'spectate' then
        local targetName = Framework.getPlayerName(targetPlayerId)
        TriggerClientEvent('possible_scoreboard:client:spectate', source, targetPlayerId, targetName)
        return { success = true }
    end

    return { success = false, message = locale('unknown_action') }
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src and Player(src).state['possible_scoreboard:frozen'] then
            Player(src).state:set('possible_scoreboard:frozen', false, true)
            TriggerClientEvent('possible_scoreboard:client:setFreeze', src, false)
        end
    end
end)
