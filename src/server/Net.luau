--!strict
-- Net (server): creates the Remotes folder from the Enums registry and exposes
-- bind helpers. Single place where remotes come to exist — nothing else
-- Instance.new's a remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Enums)

local Net = {}

local folder: Folder

function Net.init()
	folder = Instance.new("Folder")
	folder.Name = "Remotes"

	for _, name in Enums.RemoteFunctions do
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = folder
	end
	for _, name in Enums.RemoteEvents do
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = folder
	end

	folder.Parent = ReplicatedStorage
end

-- Bind a RemoteFunction handler. Handler returns a table; any raised error is
-- swallowed into {ok=false, err="internal"} so clients can't fish stack traces.
function Net.bindFunction(name: string, handler: (player: Player, ...any) -> any)
	local rf = folder:FindFirstChild(name)
	assert(rf and rf:IsA("RemoteFunction"), "unknown RemoteFunction: " .. name)
	rf.OnServerInvoke = function(player, ...)
		local args = table.pack(...)
		local ok, result = pcall(function()
			return handler(player, table.unpack(args, 1, args.n))
		end)
		if not ok then
			warn("[Net] handler error in " .. name .. ": " .. tostring(result))
			return { ok = false, err = "internal" }
		end
		return result
	end
end

function Net.fireClient(name: string, player: Player, ...)
	local re = folder:FindFirstChild(name)
	if re and re:IsA("RemoteEvent") then
		re:FireClient(player, ...)
	end
end

function Net.fireAllClients(name: string, ...)
	local re = folder:FindFirstChild(name)
	if re and re:IsA("RemoteEvent") then
		re:FireAllClients(...)
	end
end

return Net
