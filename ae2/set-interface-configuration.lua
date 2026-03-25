-- this script uses an adapter connected to a fluid interface to get all bees in network
-- to than set all the bees with nbt* in the interface filters

-- * nbt is ignored if operation fails

local component = require("component")
local interface = component.me_interface
local db = component.database

-- clear db
for i = 1, 64 do
  db.clear(i)
end

-- store Forestry:bee*
local foundBees = {}
for item in interface.allItems() do
  if string.find(item.name, "^Forestry:bee") then
    table.insert(foundBees, item)
  end
end

if #foundBees == 0 then
  print("no Forestry:bee*")
  return
end

print("found " .. #foundBees .. " bee type/s:")
for _, item in ipairs(foundBees) do
  print("-> [" .. item.name .. "] dmg=" .. tostring(item.damage) .. " label=" .. tostring(item.label))
end

local configured = 0
for slot, item in ipairs(foundBees) do
  if slot > 64 then
    break
  end

  print("now at slot " .. slot .. ": " .. tostring(item.label) .. " [" .. item.name .. "] dmg=" .. tostring(item.damage))

  -- try 1: store item descriptor
  local ok, err = pcall(function()
    interface.store(item, db.address, slot)
  end)
  print("  store attempt 1: ok=" .. tostring(ok) .. (err and (" err=" .. tostring(err)) or ""))

  -- try 2 using name+damage only
  if not ok or not db.get(slot) then
    local ok2, err2 = pcall(function()
      interface.store({name = item.name, damage = item.damage or 0}, db.address, slot)
    end)
    print("  store attempt 2: ok=" .. tostring(ok2) .. (err2 and (" err=" .. tostring(err2)) or ""))
  end

  local stored = db.get(slot)
  print("  db.get(" .. slot .. "): " .. tostring(stored))

  if stored then
    local result = interface.setInterfaceConfiguration(slot, db.address, slot, 1)
    print("  interface slot " .. slot .. " configured: " .. tostring(result))
    configured = configured + 1
  else
    print("  slot " .. slot .. " FAILED: db slot empty after both store attempts")
  end

  print()
end

print("Done, " .. configured .. " bee type/s")
