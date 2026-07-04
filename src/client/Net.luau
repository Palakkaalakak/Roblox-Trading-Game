--!strict
-- Net (client): typed access to the server-created Remotes folder.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

-- Lazy: resolving at require time would infinite-yield in contexts where the
-- server hasn't created the folder (Edit-mode tooling, tests).
local folder: Folder? = nil
local function remotes(): Folder
	if folder == nil then
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	return folder :: Folder
end

-- Invoke a RemoteFunction; returns the server's {ok=..., ...} table, or a
-- client-side error table on transport failure.
function Net.invoke(name: string, ...): any
	local rf = remotes():WaitForChild(name)
	assert(rf:IsA("RemoteFunction"), name .. " is not a RemoteFunction")
	local args = table.pack(...)
	local ok, result = pcall(function()
		return rf:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok then
		return { ok = false, err = "transport" }
	end
	return result
end

function Net.on(name: string, fn: (...any) -> ())
	local re = remotes():WaitForChild(name)
	assert(re:IsA("RemoteEvent"), name .. " is not a RemoteEvent")
	return re.OnClientEvent:Connect(fn)
end

return Net
