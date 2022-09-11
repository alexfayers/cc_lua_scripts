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

-- Handle CLI args

if #arg == 0 then
    help()
else
    if arg[1] == "update" then
        if arg[2] == "library" then
            update.update_library()
        elseif arg[2] == "script" then
            if arg[3] == nil then
                print("Error: No script name provided")
                help()
            else
                for i = 3, #arg do
                    update.update_file(arg[i])
                end
            end
        else
            print("Error: '" .. arg[2] .."' is not a valid option for 'update'")
            help()
        end
    else
        print("Error: No command provided")
        help()
    end
end

-- Set the autocomplete
shell.setCompletionFunction("afscriptman", complete)
