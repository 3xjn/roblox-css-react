--!strict
local Error = {}
function Error.new(message: string?)
	local text = message or ""
	return table.freeze(setmetatable({ name = "Error", message = text, stack = debug.traceback(text, 2) }, {
		__tostring = function()
			return if text == "" then "Error" else "Error: " .. text
		end,
	}))
end
return {
	Error = table.freeze(setmetatable(Error, {
		__call = function(_self, message: string?)
			return Error.new(message)
		end,
	})),
}
