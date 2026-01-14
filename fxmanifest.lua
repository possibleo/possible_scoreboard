fx_version 'cerulean'
games { 'gta5', 'rdr3' }
lua54 'yes'

description 'Possible Scoreboard - A scoreboard nui for QBOX, QBCORE or ESX'
author 'Possible'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/*.lua',
}

client_scripts {
    'client/util.lua',
    'client/client.lua',
}

server_scripts {
    'server/server.lua',
}

ui_page 'web/dist/browser/index.html'

files {
    'locales/*.json',
    'web/dist/browser/index.html',
    'web/dist/browser/**/*',
}