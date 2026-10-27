--!strict
-- Unmapped strict arguments are ordinary descriptor-backed objects. They never
-- expose the compiler's private logical argument array as a JavaScript Array.
local Arrays = require(script.Parent.Arrays)
local Symbols = require(script.Parent.SourceSymbols)
local Arguments = {}

function Arguments.create(ops: any, packet: any, strict: boolean?, poison: any?): any
	assert(strict ~= false, "Mapped sloppy arguments are not implemented")
	assert(Arrays.owns(packet), "Arguments require a logical invocation packet")
	local value = ops.object()
	local size = Arrays.length(packet)
	for at = 1, size do
		ops.defineDataProperty(value, tostring(at - 1), packet[at], true, true, true)
	end
	ops.defineDataProperty(value, "length", size, true, false, true)
	local thrower = poison
	if thrower == nil then
		-- Standalone operations have no realm's TypeError constructor. Production
		-- SourceRuntime supplies its canonical intrinsic poison function instead.
		thrower = ops.functionValue(function(): never
			error("Strict arguments poison access requires a source Error realm", 2)
		end, "", 0, "method")
	end
	ops.defineAccessor(value, "callee", thrower, thrower, false, false)
	local values = ops.get(Arrays.adopt({}, 0), "values")
	ops.defineDataProperty(value, Symbols.Symbol.iterator, values, true, false, true)
	ops.setIntrinsicTag(value, "Arguments")
	return value
end

return Arguments
