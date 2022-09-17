---Run this file in case of emergency to force a turtle to go to a specific position

local movement = require("afscript.turtle.movement")

local x, y, z = tonumber(arg[1]), tonumber(arg[2]), tonumber(arg[3])

if x == nil or y == nil or z == nil then
    print("Usage: emergency <x> <y> <z>")
    print("Current position: " .. movement.current_position.x .. ", " .. movement.current_position.y .. ", " .. movement.current_position.z)
    return
end

print("Going to " .. x .. ", " .. y .. ", " .. z)
movement.moveTo(x, y, z)
print("Arrived")
