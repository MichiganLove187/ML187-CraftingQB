fx_version 'cerulean'
game 'gta5'

author 'ML187-SCRIPTS'
name "ml187-crafting"
description 'crafting system'
version '2.0.0'

client_scripts {
    'config.lua',
    'client/main.lua',
    'client/cl_bench.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/main.lua',
    'server/sv_bench.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

lua54 'yes'
