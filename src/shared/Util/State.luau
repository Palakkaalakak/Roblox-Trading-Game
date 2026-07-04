--!strict
-- Mini reactive state layer (hand-rolled Fusion substitute; zero deps).
-- State.Value(x): get/set container with Changed signal.
-- State.Computed(fn, ...deps): re-derives when any dep changes.
-- State.Observe(value, fn): connect + fire immediately with current value.
-- Explicit dependencies (no auto-tracking) — predictable, easy to debug.

local Signal = require(script.Parent.Signal)

export type Value<T> = {
	get: (self: Value<T>) -> T,
	set: (self: Value<T>, newValue: T, force: boolean?) -> (),
	Changed: any, -- Signal<T>
}

local State = {}

function State.Value<T>(initial: T): Value<T>
	local self = {
		_value = initial,
		Changed = Signal.new(),
	}

	function self.get(s): T
		return s._value
	end

	function self.set(s, newValue: T, force: boolean?)
		if s._value ~= newValue or force then
			s._value = newValue
			s.Changed:Fire(newValue)
		end
	end

	return (self :: any) :: Value<T>
end

-- Computed re-evaluates fn() whenever any dep fires Changed. fn reads deps itself.
function State.Computed<T>(fn: () -> T, deps: { any }): Value<T>
	local out = State.Value(fn())
	for _, dep in deps do
		dep.Changed:Connect(function()
			out:set(fn(), true)
		end)
	end
	return out
end

-- Observe: run fn now with current value, and on every change. Returns connection.
function State.Observe<T>(value: Value<T>, fn: (T) -> ())
	fn(value:get())
	return value.Changed:Connect(fn)
end

return State
