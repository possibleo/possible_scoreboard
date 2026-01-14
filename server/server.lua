lib.locale()

local config = require('shared.config')
local Framework = require('shared.bridge')

-- Webhook URL for logging (server-side only for security - clients cannot access this)
local WebhookUrl = ''

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

---Logs an event to the configured logging service
---@param src number The player server ID who performed the action
---@param message string The log message
local function logEvent(src, message)
    if not config.Logging or not config.Logging.enabled then return end

    local playerName = Framework.getPlayerName(src)
    local logMessage = string.format("Player %s (%d): %s", playerName, src, message)

    local service = config.Logging.service

    if service == 'oxlib' or service == 'both' then
        lib.logger(src, 'Scoreboard', logMessage)
    end

    if service == 'webhook' or service == 'both' then
        if WebhookUrl and WebhookUrl ~= '' then
            local embed = {
                {
                    ["color"] = 3447003,
                    ["title"] = "**Possible Scoreboard Logs**",
                    ["description"] = logMessage,
                    ["footer"] = {
                        ["text"] = os.date("%Y-%m-%d %H:%M:%S"),
                    },
                }
            }
            PerformHttpRequest(WebhookUrl, function(err, text, headers) end, 'POST', json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
        end
    end
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

    local targetName = Framework.getPlayerName(targetPlayerId)
    logEvent(source, string.format("Viewed details of %s (%d)", targetName, targetPlayerId))

    return {
        id = targetPlayerId,
        name = targetName,
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
    local targetName = Framework.getPlayerName(targetPlayerId)

    if action == 'teleport' then
        TriggerClientEvent('possible_scoreboard:client:teleportTo', source, {
            x = targetCoords.x,
            y = targetCoords.y,
            z = targetCoords.z
        })
        logEvent(source, string.format("Teleported to %s (%d)", targetName, targetPlayerId))
        return { success = true }

    elseif action == 'bring' then
        TriggerClientEvent('possible_scoreboard:client:teleportTo', targetPlayerId, {
            x = sourceCoords.x,
            y = sourceCoords.y,
            z = sourceCoords.z
        })
        logEvent(source, string.format("Brought %s (%d) to their location", targetName, targetPlayerId))
        return { success = true }

    elseif action == 'freeze' then
        local isFrozen = Player(targetPlayerId).state['possible_scoreboard:frozen'] or false
        Player(targetPlayerId).state:set('possible_scoreboard:frozen', not isFrozen, true)
        TriggerClientEvent('possible_scoreboard:client:setFreeze', targetPlayerId, not isFrozen)
        local freezeAction = not isFrozen and "Froze" or "Unfroze"
        logEvent(source, string.format("%s %s (%d)", freezeAction, targetName, targetPlayerId))
        return { success = true, frozen = not isFrozen }

    elseif action == 'spectate' then
        TriggerClientEvent('possible_scoreboard:client:spectate', source, targetPlayerId, targetName)
        logEvent(source, string.format("Started spectating %s (%d)", targetName, targetPlayerId))
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
