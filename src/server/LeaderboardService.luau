--!strict
-- Tracks each player's best wave reached across sessions via an
-- OrderedDataStore, for the lobby leaderboard. Best-effort: if DataStore API
-- access isn't enabled (common in local Studio testing unless turned on in
-- Game Settings > Security), this silently no-ops instead of erroring.
local LeaderboardService = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local storeOk, store = pcall(function()
	return DataStoreService:GetOrderedDataStore("LuminaDefense_BestWave")
end)

function LeaderboardService.reportWave(wave: number)
	if not storeOk then return end
	for _, player in ipairs(Players:GetPlayers()) do
		local key = tostring(player.UserId)
		task.spawn(function()
			pcall(function()
				store:UpdateAsync(key, function(old)
					return math.max(old or 0, wave)
				end)
			end)
		end)
	end
end

-- Returns up to `count` entries: {{name=string, wave=number}, ...}, sorted highest first.
function LeaderboardService.getTop(count: number): {{name: string, wave: number}}
	if not storeOk then return {} end

	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, count)
	end)
	if not ok then return {} end

	local page = pages:GetCurrentPage()
	local results = {}
	for _, entry in ipairs(page) do
		local name = "Player" .. entry.key
		pcall(function()
			name = Players:GetNameFromUserIdAsync(tonumber(entry.key))
		end)
		table.insert(results, {name = name, wave = entry.value})
	end
	return results
end

return LeaderboardService
