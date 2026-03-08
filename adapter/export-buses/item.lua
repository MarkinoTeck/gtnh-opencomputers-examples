local component = require('component')
local exportbus = component.me_exportbus
local database  = component.database

local NUM_SLOTS = 9

-- 1. detect side

local busSide = nil
for side = 0, 5 do
  local raw, err = exportbus.getExportConfiguration(side, 1)
  if err ~= "no export bus" and err ~= "no matching part" then
    busSide = side
    break
  end
end
if not busSide then error("No export bus found on any side.") end
print(string.format("Bus found on side %d", busSide))

-- 2. read current config

local config = {}
for slot = 1, NUM_SLOTS do
  local raw, err = exportbus.getExportConfiguration(busSide, slot)
  if raw and not err then
    config[slot] = {
      label      = raw.label,
      itemName   = raw.itemName,
      itemDamage = raw.itemDamage,
    }
    print(string.format("[READ] Slot %d -> %s  (%s @ %d)",
      slot, raw.label, raw.itemName, raw.itemDamage))
  else
    config[slot] = nil
    print(string.format("[READ] Slot %d -> (empty)", slot))
  end
end

-- 3. populate database + re-apply

print(string.rep("-", 40))

for slot = 1, NUM_SLOTS do
  local cfg = config[slot]
  if cfg then
    local ok, err = database.set(slot, cfg.itemName, cfg.itemDamage)
    if not ok then
      print(string.format("[WARN] Slot %d -> database.set failed: %s", slot, tostring(err)))
    end

    local ok2, err2 = exportbus.setExportConfiguration(
      busSide, slot, database.address, slot
    )
    if ok2 then
      print(string.format("[SET]  Slot %d -> %s  OK", slot, cfg.label))
    else
      print(string.format("[SET]  Slot %d -> %s  FAILED: %s", slot, cfg.label, tostring(err2)))
    end
  else
    print(string.format("[SKIP] Slot %d -> (empty)", slot))
  end
end

print("Done.")
