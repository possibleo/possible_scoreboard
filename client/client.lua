lib.locale()

local config = require('shared.config')
local Framework = require('shared.bridge')

local isScoreboardOpen = false
local isSpectating = false
local spectateTarget = nil
local textConfig = config.Text3D

---@param x number World X coordinate
---@param y number World Y coordinate
---@param z number World Z coordinate
---@param text string Text to display
---@param size number|nil Optional text size override
local function draw3DText(x, y, z, text, size)
    local onScreen, screenX, screenY = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    size = size or textConfig.maxSize

    SetTextScale(size, size)
    SetTextFont(textConfig.font)
    SetTextProportional(true)
    SetTextColour(table.unpack(textConfig.color))
    SetTextDropshadow(table.unpack(textConfig.dropShadow))
    SetTextEdge(table.unpack(textConfig.edge))
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(screenX, screenY)
end

---@param distance number Distance from the viewer
---@return number Calculated text size based on distance
local function getScaledTextSize(distance)
    local scale = 1.0 - (distance / textConfig.maxDistance)
    return math.max(textConfig.minSize, textConfig.maxSize * scale)
end

local function openScoreboard()
    if isScoreboardOpen then return end
    isScoreboardOpen = true

    LocalPlayer.state:set('possible_scoreboard:open', true, true)
    SetNuiFocus(true, true)
    SendAngularMessage('setVisible', true)

    if config.ShowPlayerIDs then
        CreateThread(function()
            while isScoreboardOpen do
                local players = GetActivePlayers()
                local myPed = PlayerPedId()
                local myCoords = GetEntityCoords(myPed)

                for _, playerId in ipairs(players) do
                    local ped = GetPlayerPed(playerId)
                    if DoesEntityExist(ped) then
                        local coords = GetEntityCoords(ped)
                        local distance = #(myCoords - coords)

                        if distance <= textConfig.maxDistance then
                            local serverId = GetPlayerServerId(playerId)
                            local textSize = getScaledTextSize(distance)
                            draw3DText(coords.x, coords.y, coords.z + textConfig.heightOffset, tostring(serverId), textSize)
                        end
                    end
                end

                Wait(0)
            end
        end)
    end
end

local function closeScoreboard()
    if not isScoreboardOpen then return end
    isScoreboardOpen = false

    LocalPlayer.state:set('possible_scoreboard:open', false, true)
    SetNuiFocus(false, false)
    SendAngularMessage('setVisible', false)
end

---Stops spectating the current target player
---@return nil
local function stopSpectating()
    if not isSpectating then return end

    NetworkSetInSpectatorMode(false, PlayerPedId())
    isSpectating = false
    spectateTarget = nil

    SendAngularMessage('setSpectating', { active = false })
    Framework.notify({ description = locale('stopped_spectating'), type = 'info' })
end

---Starts spectating a target player
---@param targetServerId number The server ID of the player to spectate
---@param targetName string|nil The name of the player to spectate
---@return nil
local function startSpectating(targetServerId, targetName)
    if isSpectating then
        NetworkSetInSpectatorMode(false, PlayerPedId())
    end

    local targetPlayer = GetPlayerFromServerId(targetServerId)
    if targetPlayer == -1 then
        Framework.notify({ description = locale('player_not_found'), type = 'error' })
        return
    end

    local targetPed = GetPlayerPed(targetPlayer)
    if not DoesEntityExist(targetPed) then
        Framework.notify({ description = locale('player_not_found'), type = 'error' })
        return
    end

    NetworkSetInSpectatorMode(true, targetPed)
    isSpectating = true
    spectateTarget = targetServerId

    SendAngularMessage('setSpectating', {
        active = true,
        playerId = targetServerId,
        playerName = targetName or ('Player ' .. targetServerId)
    })
    Framework.notify({ description = locale('now_spectating', targetServerId), type = 'info' })
end

RegisterCommand('scoreboard:toggle', function()
    if isScoreboardOpen then
        closeScoreboard()
    else
        openScoreboard()
    end
end, false)

if config.Keybind then
    RegisterKeyMapping('scoreboard:toggle', locale('open_scoreboard'), 'keyboard', config.Keybind)
end

if config.OpenCommand then
    RegisterCommand(config.OpenCommand, function()
        if isScoreboardOpen then
            closeScoreboard()
        else
            openScoreboard()
        end
    end, false)
end

RegisterNUICallback('hideFrame', function(_, cb)
    closeScoreboard()
    cb({})
end)

RegisterNUICallback('getPlayers', function(_, cb)
    local result = lib.callback.await('possible_scoreboard:server:getPlayers', false)
    cb(result or {})
end)

RegisterNUICallback('getServices', function(_, cb)
    local result = lib.callback.await('possible_scoreboard:server:getServices', false)
    cb(result or {})
end)

RegisterNUICallback('getConfig', function(_, cb)
    local result = lib.callback.await('possible_scoreboard:server:getConfig', false)
    cb(result or {})
end)

RegisterNUICallback('getLocales', function(_, cb)
    cb({
        players_online = locale('players_online'),
        no_players = locale('no_players'),
        player_details = locale('player_details'),
        teleport_to_player = locale('teleport_to_player'),
        bring_player = locale('bring_player'),
        freeze_player = locale('freeze_player'),
        unfreeze_player = locale('unfreeze_player'),
        spectate_player = locale('spectate_player'),
        stop_spectating = locale('stop_spectating'),
        view_details = locale('view_details'),
        player_frozen = locale('player_frozen'),
        spectating_player = locale('spectating_player'),
        close = locale('close'),
        scroll_view_more = locale('scroll_view_more'),
        spectating = locale('spectating'),
        loading = locale('loading'),
        identifiers = locale('identifiers'),
        col_id = locale('col_id'),
        col_name = locale('col_name'),
        col_ping = locale('col_ping'),
        col_job = locale('col_job'),
        not_available = locale('not_available'),
        staff = locale('staff'),
        steam_name = locale('steam_name'),
        rp_name = locale('rp_name')
    })
end)

RegisterNUICallback('getPlayerDetails', function(data, cb)
    local result = lib.callback.await('possible_scoreboard:server:getPlayerDetails', false, data.targetPlayerId)
    cb(result or {})
end)

RegisterNUICallback('staffAction', function(data, cb)
    local result = lib.callback.await('possible_scoreboard:server:staffAction', false, data.action, data.targetPlayerId)
    cb(result or { success = false })
end)

RegisterNUICallback('stopSpectating', function(_, cb)
    stopSpectating()
    cb({})
end)

RegisterKeyMapping('scoreboard_stop_spectate', locale('stop_spectating'), 'keyboard', 'BACK')
RegisterCommand('scoreboard_stop_spectate', function()
    if isSpectating then
        stopSpectating()
    end
end, false)

RegisterNetEvent('possible_scoreboard:client:teleportTo', function(coords)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
end)

RegisterNetEvent('possible_scoreboard:client:setFreeze', function(frozen)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, frozen)

    if frozen then
        Framework.notify({ description = locale('frozen_by_staff'), type = 'warning' })
    else
        Framework.notify({ description = locale('unfrozen'), type = 'success' })
    end
end)

RegisterNetEvent('possible_scoreboard:client:spectate', function(targetServerId, targetName)
    if isSpectating and spectateTarget == targetServerId then
        stopSpectating()
    else
        startSpectating(targetServerId, targetName)
    end
end)

AddStateBagChangeHandler('possible_scoreboard:open', nil, function(bagName, _, value)
    if not config.ShowPeersBehindCurtain then return end

    local serverId = tonumber(bagName:match('player:(%d+)'))
    if not serverId then return end

    local playerId = GetPlayerFromServerId(serverId)
    if playerId == -1 or playerId == PlayerId() then return end

    if not value then return end

    CreateThread(function()
        local myPed = PlayerPedId()
        local ped = GetPlayerPed(playerId)
        local peerText = locale('peers_behind_curtain')

        while Player(serverId).state['possible_scoreboard:open'] do
            if not DoesEntityExist(ped) then
                ped = GetPlayerPed(playerId)
            end

            if DoesEntityExist(ped) then
                local myCoords = GetEntityCoords(myPed)
                local coords = GetEntityCoords(ped)
                local distance = #(myCoords - coords)

                if distance <= textConfig.maxDistance then
                    local textSize = getScaledTextSize(distance)
                    draw3DText(coords.x, coords.y, coords.z + textConfig.heightOffset + 0.1, peerText, textSize)
                end
            end

            Wait(0)
        end
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if isSpectating then
        NetworkSetInSpectatorMode(false, PlayerPedId())
    end

    FreezeEntityPosition(PlayerPedId(), false)
end)

exports('openScoreboard', openScoreboard)
exports('closeScoreboard', closeScoreboard)
