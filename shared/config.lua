return {
    Debug = false,
    -- Framework: 'auto', 'qbx', 'qb', or 'esx'
    Framework = 'auto',
    -- Keybind to toggle scoreboard. See: https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/
    Keybind = 'HOME',
    OpenCommand = 'scoreboard', -- Command to open scoreboard (set to false to disable) - When using command, press ESC or Backspace to close
    NotificationPosition = 'top',
    -- These jobs will appear as filter tabs in the scoreboard
    Jobs = {
        { job = 'police', label = 'Police' },
        { job = 'ambulance', label = 'EMS' },
        { job = 'mechanic', label = 'Mechanic' },
    },
    -- Players with any of these ace permissions will be marked as staff and appear in the Staff tab
    StaffAces = {
        'admin',
        'mod',
        'support',
    },
    Logging = {
        enabled = false,
        service = 'oxlib', -- 'oxlib', 'webhook', or 'both'
        -- NOTE: Webhook URL is configured in server/server.lua for security
    },
    ShowPlayerIDs = true,
    ShowPeersBehindCurtain = true,
    Text3D = {
        maxDistance = 20.0,
        maxSize = 0.5,
        minSize = 0.25,
        font = 4,
        color = { 255, 255, 255, 215 },
        dropShadow = { 0, 0, 0, 255, 0.5 },
        edge = { 2, 0, 0, 0, 150 },
        heightOffset = 1.0,
    },
    -- Theme configuration (sent to NUI)
    -- NOTE: FiveM NUI uses an older Chromium that doesn't support backdrop-filter
    -- for glassmorphism effects. RGB values are used with rgba() in CSS as a workaround.
    -- RGB format (for transparency): 50, 400, 500, 700, 900, 950
    -- Hex format (solid colors): 100, 200, 300, 600, 800
    Theme = {
        primary = {
            [50] = '240, 249, 255',
            [100] = '#e0f2fe',
            [200] = '#bae6fd',
            [300] = '#7dd3fc',
            [400] = '56, 189, 248',
            [500] = '14, 165, 233',
            [600] = '#0284c7',
            [700] = '3, 105, 161',
            [800] = '#075985',
            [900] = '12, 74, 110',
            [950] = '8, 47, 73'
        }
    },
}
