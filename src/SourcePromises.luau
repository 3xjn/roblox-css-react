--!strict
local Arrays = require(script.Parent.Arrays)
local SourcePromises = {}
export type Native = {
	read new: any,
	read resolve: (any) -> any,
	read reject: (any) -> any,
	read all: ({ any }) -> any,
}
-- Reuse the application's native promises. The collection boundary preserves
-- source-array length and explicit undefined results, including sparse inputs.
function SourcePromises.create(native: Native)
	return table.freeze({
		new = native.new,
		resolve = native.resolve,
		reject = native.reject,
		all = function(values: any): any
			local length = if Arrays.owns(values) then Arrays.length(values) else #values
			local promises = table.create(length)
			for index = 1, length do
				promises[index] = native.resolve(rawget(values, index))
			end
			return native.all(promises):andThen(function(results: any)
				return Arrays.adopt(results, length)
			end)
		end,
	})
end
return SourcePromises
