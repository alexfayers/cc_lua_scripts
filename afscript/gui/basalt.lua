-- load basalt if it's not already loaded
local basaltPath = "basalt.lua"

if not(fs.exists(basaltPath))then
    shell.run("pastebin run ESs1mg7P packed true "..basaltPath:gsub(".lua", ""))
end

-- load basalt
local basalt = require(basaltPath:gsub(".lua", ""))

return basalt
