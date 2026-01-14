local config = require('shared.config')

local Framework = {}
local frameworkName = config.Framework
local core = nil

if frameworkName == 'auto' then
    if GetResourceState('qbx_core') == 'started' then
        frameworkName = 'qbx'
    elseif GetResourceState('qb-core') == 'started' then
        frameworkName = 'qb'
    elseif GetResourceState('es_extended') == 'started' then
        frameworkName = 'esx'
    else
        error('No supported framework found. This resource requires qbx_core, qb-core, or es_extended.')
    end
end

if frameworkName == 'qbx' then
    core = exports.qbx_core
elseif frameworkName == 'qb' then
    core = exports['qb-core']:GetCoreObject()
elseif frameworkName == 'esx' then
    core = exports['es_extended']:getSharedObject()
end

Framework.name = frameworkName
Framework.core = core

if IsDuplicityVersion() then

    ---@param src number Player server ID
    ---@return string|nil Player identifier
    function Framework.getIdentifier(src)
        if frameworkName == 'qbx' then
            local player = core:GetPlayer(src)
            if player then
                return player.PlayerData and player.PlayerData.citizenid or player.citizenid
            end
        elseif frameworkName == 'qb' then
            local player = core.Functions.GetPlayer(src)
            return player and player.PlayerData and player.PlayerData.citizenid
        elseif frameworkName == 'esx' then
            local player = core.GetPlayerFromId(src)
            return player and player.identifier
        end
        return nil
    end

    ---@param src number Player server ID
    ---@return string Player name
    function Framework.getPlayerName(src)
        if frameworkName == 'qbx' then
            local player = core:GetPlayer(src)
            if player then
                local charinfo = player.PlayerData and player.PlayerData.charinfo
                if charinfo and charinfo.firstname then
                    return charinfo.firstname .. ' ' .. charinfo.lastname
                end
            end
        elseif frameworkName == 'qb' then
            local player = core.Functions.GetPlayer(src)
            if player then
                local charinfo = player.PlayerData and player.PlayerData.charinfo
                if charinfo and charinfo.firstname then
                    return charinfo.firstname .. ' ' .. charinfo.lastname
                end
            end
        elseif frameworkName == 'esx' then
            local player = core.GetPlayerFromId(src)
            if player and player.getName then
                return player.getName()
            end
        end
        return GetPlayerName(src) or 'Unknown'
    end

    ---@param src number Player server ID
    ---@return table|nil Player data object (read-only)
    function Framework.getPlayer(src)
        if frameworkName == 'qbx' then
            return core:GetPlayer(src)
        elseif frameworkName == 'qb' then
            return core.Functions.GetPlayer(src)
        elseif frameworkName == 'esx' then
            return core.GetPlayerFromId(src)
        end
        return nil
    end

    ---@return table Array of all online players
    function Framework.getPlayers()
        if frameworkName == 'qbx' then
            return core:GetQBPlayers()
        elseif frameworkName == 'qb' then
            return core.Functions.GetQBPlayers()
        elseif frameworkName == 'esx' then
            return core.GetExtendedPlayers()
        end
        return {}
    end

    ---@param src number Player server ID
    ---@return string|nil Job name
    function Framework.getPlayerJob(src)
        if frameworkName == 'qbx' then
            local player = core:GetPlayer(src)
            if player then
                local job = player.PlayerData and player.PlayerData.job or player.job
                return job and job.name
            end
        elseif frameworkName == 'qb' then
            local player = core.Functions.GetPlayer(src)
            if player and player.PlayerData and player.PlayerData.job then
                return player.PlayerData.job.name
            end
        elseif frameworkName == 'esx' then
            local player = core.GetPlayerFromId(src)
            if player and player.job then
                return player.job.name
            end
        end
        return nil
    end

else
    ---@param data table Notification data (description, type, etc.)
    function Framework.notify(data)
        data.position = config.NotificationPosition
        lib.notify(data)
    end

    ---@return table|nil Local player data
    function Framework.getPlayerData()
        if frameworkName == 'qbx' then
            return QBX.PlayerData
        elseif frameworkName == 'qb' then
            return core.Functions.GetPlayerData()
        elseif frameworkName == 'esx' then
            return core.GetPlayerData()
        end
        return nil
    end

    ---@return string|nil Local player identifier
    function Framework.getIdentifier()
        if frameworkName == 'qbx' then
            return QBX.PlayerData and QBX.PlayerData.citizenid
        elseif frameworkName == 'qb' then
            local data = core.Functions.GetPlayerData()
            return data and data.citizenid
        elseif frameworkName == 'esx' then
            local data = core.GetPlayerData()
            return data and data.identifier
        end
        return nil
    end
end

return Framework
