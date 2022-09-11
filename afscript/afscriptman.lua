-- imports

local completion = require "cc.completion"

-- Update the updater script
local file_url = "https://raw.githubusercontent.com/alexfayers/cc_lua_scripts/main/afscript/meta/update.lua"
local file_contents = http.get(file_url).readAll()
local file = fs.open("afscript/meta/update.lua", "w")
file.write(file_contents)
file.close()

local update = require("afscript.meta.update")

-- Define autocomplete for the updater

function complete(shell, index, argument, previous)
    if index == 1 then
        return completion.choice(argument, {"update"}, true)
    elseif index == 2 then
        if previous[#previous] == "update" then
            return completion.choice(argument, {"library", "script"}, true)
        end
    end
end

-- Help menu for the updater

local function help()
    print("Usage: " .. arg[0] .. " <command> [options]")
    print("Commands:")
    print(" update library")
    print(" update script <script_name> [<script_name_2>, etc.]")
end

-- Handle updates
local args = {...}

if #args == 0 then
    help()
else
    if args[1] == "update" then
        if args[2] == "library" then
            update.update_library()
        elseif args[2] == "script" then
            if args[3] == nil then
                help()
            else
                for i = 3, #args do
                    update.update_file(args[i])
                end
            end
        else
            help()
        end
    else
        help()
    end
end

-- Set the autocomplete
shell.setCompletionFunction("afscript", complete)
