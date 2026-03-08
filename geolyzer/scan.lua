local component = require("component")
local sides = require("sides")

if component.isAvailable("geolyzer") then
    local gz = component.geolyzer

        local success, data = pcall(function()
            return gz.analyze(sides.bottom)
        end)

        if success and data then
            print("--- BLOCK DATA ---")

            -- Stampa tutto ricorsivamente
            local function printData(tbl, indent)
                indent = indent or ""
                for k, v in pairs(tbl) do
                    if type(v) == "table" then
                        print(indent .. k .. " = {")
                        printData(v, indent .. "  ")
                        print(indent .. "}")
                    else
                        print(indent .. k .. " = " .. tostring(v))
                    end
                end
            end

            printData(data)

        else
            print("ERROR: " .. tostring(data))
        end

else
    print("Geolyzer not available!")
end

print("\n===========================================")
