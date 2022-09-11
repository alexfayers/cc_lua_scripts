-- Bootloader type script to fetch library files from github

---Update an arbitrary script from the repo
---@param script_name string The name of the script to update
---@param options table|nil The options table
---@return boolean _ True if the script was updated successfully
local function _update_file(script_name, options)
    assert(type(script_name) == "string", "script_name must be a string")
    assert(type(options) == "nil" or type(options) == "table", "options must be a table when specified")

    if options == nil then
        options = {}
    end

    if options.auto_extension == nil then
        options.auto_extension = true
    end

    if options.verbose == nil then
        options.verbose = true
    end

    if options.auto_extension == true then
        -- if the script doesn't end with .lua, add it
        if not script_name:match(".*lua$") then
            script_name = script_name .. ".lua"
        end
    end

    local script_url = "https://raw.githubusercontent.com/alexfayers/cc_lua_scripts/main/" .. script_name
    local script_contents = http.get(script_url).readAll()

    if script_contents == nil then
        print("Error: Could not fetch script '" .. script_name .. "'")
        return false
    end

    -- if the file already exists, check if it's different
    if fs.exists(script_name) then
        local local_file = fs.open(script_name, "r")
        local local_contents = local_file.readAll()
        local_file.close()

        if local_contents == script_contents then
            if options.verbose then
                print("Updater: '" .. script_name .. "' is already up to date")
            end
            return false
        end

        -- if the file is different, make a backup and update it
        fs.move(script_name, script_name .. ".bak")
    end

    local file = fs.open(script_name, "w")
    file.write(script_contents)
    file.close()    

    if options.verbose then
        print("Updater: Updated '" .. script_name .. "'")
    end

    return true
end

---Fetch the latest afscript library files from github
---@param options table|nil The options table
local function _update_library(options)
    assert(type(options) == "nil" or type(options) == "table", "options must be a table when specified")

    if options == nil then
        options = {}
    end

    local submodules = options.submodules or {
        "core",
        "meta",
        "turtle"
    }

    local tree_url = "https://api.github.com/repos/alexfayers/cc_lua_scripts/git/trees/main?recursive=1"
    local tree = http.get(tree_url).readAll()
    local tree_json = textutils.unserialiseJSON(tree)

    for submodule_i = 1, #submodules do
        print("Updater: Checking for updates from submodule '" .. submodules[submodule_i] .. "'...")
        local did_update = false
        for _, file in ipairs(tree_json.tree) do
            if file.path:match("^afscript/" .. submodules[submodule_i] .. "/.+") then
                local did_update_file = _update_file(file.path, {
                    auto_extension = false,
                    verbose = false
                })

                if did_update_file then
                    did_update = true
                end
            end
        end

        if not did_update then
            print("Updater: Submodule '" .. submodules[submodule_i] .. "' is already up to date")
        end
    end
    print("Updater: Done!")
end

return {
    update_library = _update_library,
    update_file = _update_file
}
