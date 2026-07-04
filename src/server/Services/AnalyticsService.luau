--!strict
-- AnalyticsService: structured event log. Print-based sink now (searchable in
-- console + ring buffer for tooling); external sink can hook later.

local HttpService = game:GetService("HttpService")

local AnalyticsService = {}

local RING_SIZE = 512
local ring: { any } = {}
local ringIndex = 0

function AnalyticsService.Init() end
function AnalyticsService.Start() end

function AnalyticsService.log(category: string, data: { [string]: any }?)
	local event = {
		t = os.time(),
		cat = category,
		data = data or {},
	}
	ringIndex = (ringIndex % RING_SIZE) + 1
	ring[ringIndex] = event

	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, event.data)
	print(("[Analytics] %s %s"):format(category, ok and encoded or "<unencodable>"))
end

function AnalyticsService.recent(n: number?): { any }
	local out = {}
	local count = math.min(n or 50, RING_SIZE)
	for i = 0, count - 1 do
		local idx = ((ringIndex - 1 - i) % RING_SIZE) + 1
		if ring[idx] then
			table.insert(out, ring[idx])
		end
	end
	return out
end

return AnalyticsService
