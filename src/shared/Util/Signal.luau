--!strict
-- Minimal signal (GoodSignal pattern, trimmed). Connect/Once/Fire/Wait/Destroy.

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	Destroy: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} :: { [number]: (...any) -> () } }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	local handlers = self._handlers
	local id = #handlers + 1
	-- find a free slot (holes left by disconnects)
	while handlers[id] ~= nil do
		id += 1
	end
	handlers[id] = fn

	local conn = { Connected = true }
	function conn.Disconnect(c)
		if c.Connected then
			c.Connected = false
			handlers[id] = nil
		end
	end
	return conn
end

function Signal:Once(fn: (...any) -> ())
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Fire(...)
	for _, fn in self._handlers do
		task.spawn(fn, ...)
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Destroy()
	table.clear(self._handlers)
end

return Signal
