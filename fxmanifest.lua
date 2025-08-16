fx_version 'cerulean'
game 'gta5'

author 'takenncs'
description 'takenncs Boosting'

ui_page 'web/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

files {
    'web/**'
}

lua54 'yes'