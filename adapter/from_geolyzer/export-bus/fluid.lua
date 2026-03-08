-- fluid_export_copy.lua
-- Reads fluid filter config from a SOURCE bus via geolyzer scan,
-- then writes it into the TARGET bus connected to the OC adapter.
--
-- Setup:
--   - Geolyzer must face the SOURCE cable bus (the one with filters already set).
--     Change SCAN_SIDE below to match which face of the computer points at it.
--   - Adapter must be connected to the TARGET cable bus (the one to configure).
--   - A Database upgrade must be accessible as component.database.

local component = require("component")
local sides     = require("sides")

-- ── config ──────────────────────────────────────────────────────────────────
-- Face of the computer/geolyzer that points at the SOURCE bus block.
local SCAN_SIDE = sides.bottom   -- change to sides.north / .east / etc. as needed
local NUM_SLOTS = 9
-- ────────────────────────────────────────────────────────────────────────────

local function printTable(tbl, indent)
  indent = indent or ""
  for k, v in pairs(tbl) do
    if type(v) == "table" then
      print(indent .. tostring(k) .. " = {")
      printTable(v, indent .. "  ")
      print(indent .. "}")
    else
      print(indent .. tostring(k) .. " = " .. tostring(v))
    end
  end
end

-- ── guard: required components ───────────────────────────────────────────────
assert(component.isAvailable("geolyzer"),           "geolyzer not available")
assert(component.isAvailable("me_fluid_exportbus"), "me_fluid_exportbus not available")
assert(component.isAvailable("database"),           "database not available")

local gz        = component.geolyzer
local exportbus = component.me_fluid_exportbus
local database  = component.database

-- ── 1. geolyzer scan of the SOURCE bus ───────────────────────────────────────
print("=== Geolyzer scan ===")
local ok, geoData = pcall(function() return gz.analyze(SCAN_SIDE) end)
assert(ok, "analyze() failed: " .. tostring(geoData))
printTable(geoData)
print(string.rep("-", 44))

-- ── 2. extract filter table from scan ────────────────────────────────────────
-- ae2fcSides is keyed by ForgeDirection name ("east", "west", …).
-- Each side has a .filter array (1-based) with entries:
--   { name, displayName, amount, itemName?, itemDamage? }
-- We take the first side that is a PartFluidExportBus.

local sourceFilters = nil

if type(geoData.ae2fcSides) == "table" then
  for dirName, partData in pairs(geoData.ae2fcSides) do
    if type(partData) == "table"
    and (partData.type == "PartFluidExportBus"
      or (type(partData.class) == "string"
          and partData.class:find("PartFluidExportBus"))) then
      if type(partData.filter) == "table" then
        sourceFilters = partData.filter
        print(string.format("[SOURCE] PartFluidExportBus on face '%s' — %d filter entries.",
          dirName, #sourceFilters))
      else
        print(string.format("[SOURCE] PartFluidExportBus on face '%s' — filter is empty.", dirName))
        sourceFilters = {}
      end
      break
    end
  end
end

assert(sourceFilters ~= nil,
  "No PartFluidExportBus found in geolyzer scan.\n" ..
  "Check SCAN_SIDE and that EventHandlerAe2Fc.scala is patched.")

-- ── 3. detect TARGET bus side on the adapter ─────────────────────────────────
-- ForgeDirection ordinals: DOWN=0 UP=1 EAST=2 WEST=3 NORTH=4 SOUTH=5
print("=== Detecting target bus side ===")
local targetSide = nil
for s = 0, 5 do
  local raw, err = exportbus.getFluidExportConfiguration(s, 1)
  if err ~= "no fluid export bus" and err ~= "no matching part" and err ~= "no export bus" then
    targetSide = s
    print(string.format("[TARGET] Fluid Export Bus on ForgeDirection side %d", s))
    break
  end
end
assert(targetSide ~= nil,
  "No Fluid Export Bus found on adapter. Check adapter is placed against the target cable bus.")
print(string.rep("-", 44))

-- ── 4. apply source filters to target bus ────────────────────────────────────
print("=== Applying filters ===")

for slot = 1, NUM_SLOTS do
  local f = sourceFilters[slot]

  if f == nil then
    print(string.format("  [%d] (empty) — skipping", slot))

  elseif type(f) == "table" then
    local fluidName   = f.name        or "?"
    local displayName = f.displayName or fluidName
    local itemName    = f.itemName
    local itemDamage  = f.itemDamage or 0

    if itemName then
      -- Store the container item in the OC database at this slot
      local setOk, setErr = database.set(slot, itemName, itemDamage)
      if not setOk then
        print(string.format("  [%d] WARN  database.set failed for '%s': %s",
          slot, displayName, tostring(setErr)))
      end
      -- Write the filter onto the target export bus
      local applyOk, applyErr = exportbus.setFluidExportConfiguration(
        targetSide, slot, database.address, slot
      )
      if applyOk then
        print(string.format("  [%d] OK    %-28s (%s)", slot, displayName, fluidName))
      else
        print(string.format("  [%d] FAIL  %s — %s", slot, displayName, tostring(applyErr)))
      end
    else
      -- No registered fluid container (no bucket/cell in FluidContainerRegistry for this fluid)
      print(string.format("  [%d] SKIP  %-28s no container registered for '%s'",
        slot, displayName, fluidName))
      print(string.format("             Fix: put its filled bucket/cell in database slot %d, then:", slot))
      print(string.format("             exportbus.setFluidExportConfiguration(%d,%d,db.address,%d)",
        targetSide, slot, slot))
    end
  else
    print(string.format("  [%d] unexpected type: %s", slot, type(f)))
  end
end

print(string.rep("-", 44))
print("Done.")
