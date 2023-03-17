fx_version "cerulean"
game "gta5"
lua54 "yes"

client_scripts {
    "client/modules/**/*.lua",
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    "server/modules/**/*.lua",
}