--!strict
-- Accepted values are separate from requests. No renderer or native state is owned.
type Reference<T> = { current: T }
export type React = {
	read useRef: <T>(T) -> Reference<T>,
	read useState: <T>(T) -> (T, (T | ((T) -> T)) -> ()),
	read useLayoutEffect: (() -> (() -> ())?, { any }?) -> (),
}
export type Details = { isCanceled: boolean }
export type Options = { value: any?, defaultValue: any, onChange: ((any, any) -> ())?, getAccepted: (() -> any)? }

local ValueState = {}

-- copy validates and owns the value representation. It must not create resources.
function ValueState.create(react: React, name: string, copy: (any) -> any)
	return function(options: Options): (any, (any, any) -> boolean, () -> any)
		local controlled = react.useRef(options.value ~= nil)
		assert(controlled.current == (options.value ~= nil), `{name} cannot switch value ownership while mounted`)
		assert(
			options.getAccepted == nil or controlled.current,
			"An accepted-value provider requires controlled ownership"
		)
		local initial = react.useRef(nil :: { value: any }?)
		if not initial.current then
			initial.current = { value = copy(if controlled.current then options.value else options.defaultValue) }
		end
		local localValue, setValue = react.useState(assert(initial.current).value)
		local value = if controlled.current then copy(options.value) else localValue
		local accepted = react.useRef(value)
		local latest = react.useRef(options)
		local mounted = react.useRef(false)
		local request = react.useRef(nil :: ((any, any) -> boolean)?)
		local current = react.useRef(nil :: (() -> any)?)
		if not request.current then
			request.current = function(proposed: any, details: any): boolean
				if not mounted.current then
					return false
				end
				local nextValue = copy(proposed)
				local callback = latest.current.onChange
				if callback then
					callback(copy(nextValue), details)
				end
				if details.isCanceled or not mounted.current then
					return false
				end
				if not controlled.current then
					accepted.current = copy(nextValue)
					local owned = accepted.current
					setValue(function()
						return owned
					end)
				end
				return true
			end
			current.current = function()
				local provider = latest.current.getAccepted
				return copy(if provider then provider() else accepted.current)
			end
		end
		react.useLayoutEffect(function()
			latest.current = options
			accepted.current = value
			return nil
		end)
		react.useLayoutEffect(function()
			mounted.current = true
			return function()
				mounted.current = false
			end
		end, {})
		return value, assert(request.current), assert(current.current)
	end
end

return ValueState
