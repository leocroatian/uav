fx_version 'cerulean'

game 'gta5'

author 'leocroatian'
description 'UAV Script'
version '1.0.0'

lua54 'yes'

client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'html/index.html'
}