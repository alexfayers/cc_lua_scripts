-- Bootloader type script to fetch library files from github


---Fetch the latest afscript library files from github
---@param options table|nil The options table
local function _update(options)
    assert(type(options) == "nil" or type(options) == "table", "options must be a table when specified")

    if options == nil then
        options = {}
    end

    local submodules = options.submodules or {
        "core",
        "turtle"
    }

    local tree_url = "https://api.github.com/repos/alexfayers/cc_lua_scripts/git/trees/main?recursive=1"
    local tree = http.get(tree_url).readAll()
    local tree_json = textutils.unserialiseJSON(tree)

    for _, file in ipairs(tree_json.tree) do
        for submodule_i = 1, #submodules do
            if file.path:match("^afscript/" .. submodules[submodule_i] .. "/.+") then
                local file_url = "https://raw.githubusercontent.com/alexfayers/cc_lua_scripts/main/" .. file.path
                local file_contents = http.get(file_url).readAll()

                local file = fs.open(file.path, "w")
                file.write(file_contents)
                file.close()
            end
        end
    end
end

return {
    update = _update
}
