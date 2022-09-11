-- State functions

---Save a state table to disk
---@param state table The state table to save
---@param filename string The filename to save to
---@return boolean _ True if the state was saved successfully
local function _save(state, filename)
    assert(type(state) == "table", "state must be a table")
    assert(type(filename) == "string", "filename must be a string")

    local file = fs.open(filename, "w")
    if file == nil then
        return false
    else
        file.writeLine(textutils.serialize(state))
        file.close()
        return true
    end
end

---Load a state table from disk
---@param filename string The filename to load from
---@return table|nil _ The loaded state table
local function _load(filename)
    assert(type(filename) == "string", "filename must be a string")

    if fs.exists(filename) then
        local file = fs.open(filename, "r")
        local state = textutils.unserialize(file.readAll())
        file.close()
        return state
    else
        return nil
    end
end

return {
    save = _save,
    load = _load
}
