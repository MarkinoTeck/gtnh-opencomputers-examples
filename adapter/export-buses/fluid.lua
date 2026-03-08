local component = require('component')
local exportbus = component.me_fluid_exportbus
local database  = component.database

local NUM_SLOTS = 9

-- 1. detect side

local busSide = nil
for side = 0, 5 do
  local raw, err = exportbus.getFluidExportConfiguration(side, 1)
  if err ~= "no fluid export bus" and err ~= "no matching part" then
    busSide = side
    break
  end
end
if not busSide then error("No fluid export bus found on any side.") end
print(string.format("Bus found on side %d", busSide))

-- 2. read current config

local config = {}
for slot = 1, NUM_SLOTS do
  local raw, err = exportbus.getFluidExportConfiguration(busSide, slot)
  if raw and not err then
    config[slot] = {
      name       = raw.name,
      label      = raw.displayName,
      itemName   = raw.itemName,
      itemDamage = raw.itemDamage,
    }
    if raw.itemName then
      print(string.format("[READ] Slot %d -> %s  (container: %s @ %d)",
        slot, raw.displayName, raw.itemName, raw.itemDamage))
    else
      print(string.format("[READ] Slot %d -> %s  (WARNING: no container in FluidContainerRegistry)",
        slot, raw.displayName))
    end
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
    if cfg.itemName then
      -- Write the container item into database slot (same index as bus slot)
      local ok, err = database.set(slot, cfg.itemName, cfg.itemDamage)
      if not ok then
        print(string.format("[WARN] Slot %d -> database.set failed: %s", slot, tostring(err)))
      end

      -- Apply to export bus filter
      local ok2, err2 = exportbus.setFluidExportConfiguration(
        busSide, slot, database.address, slot
      )
      if ok2 then
        print(string.format("[SET]  Slot %d -> %s  OK", slot, cfg.label))
      else
        print(string.format("[SET]  Slot %d -> %s  FAILED: %s", slot, cfg.label, tostring(err2)))
      end
    else
      print(string.format("[SKIP] Slot %d -> %s  (no container — add to fluidToItem manually)", slot, cfg.label))
    end
  else
    print(string.format("[SKIP] Slot %d -> (empty)", slot))
  end
end

print("Done.")
