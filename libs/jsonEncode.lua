local jsonEncode = {}

local function escape_str(s)
    local result = s
        :gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")

    result = result:gsub("[%c]", function(c)
        local byte = string.byte(c)
        if byte < 32 then
            return string.format("\\u%04x", byte)
        end
        return c
    end)

    return result
end

local function is_array(t)
	local i = 1
	for k, _ in pairs(t) do
		if k ~= i then
			return false
		end
		i = i + 1
	end
	return true
end

local function encode_value(v)
	local tv = type(v)
	if tv == "nil" then
		return "null"
	elseif tv == "number" then
		return tostring(v)
	elseif tv == "boolean" then
		return v and "true" or "false"
	elseif tv == "string" then
		return '"' .. escape_str(v) .. '"'
	elseif tv == "table" then
		if is_array(v) then
			local items = {}
			for i = 1, #v do
				items[#items + 1] = encode_value(v[i])
			end
			return "[" .. table.concat(items, ",") .. "]"
		else
			local items = {}
			for k, val in pairs(v) do
				items[#items + 1] =
					'"' .. escape_str(tostring(k)) .. '":' .. encode_value(val)
			end
			return "{" .. table.concat(items, ",") .. "}"
		end
	else
		error("unsupported type: " .. tv)
	end
end

function jsonEncode.encode(t)
	return encode_value(t)
end

return jsonEncode
