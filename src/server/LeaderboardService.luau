--!strict
-- Tracks each player's best wave reached across sessions via an
-- OrderedDataStore, for the lobby leaderboard. Falls back to in-memory
-- storage when DataStore isn't available (local Studio testing).
local LeaderboardService = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local storeOk, store = pcall(function()
	return DataStoreService:GetOrderedDataStore("LuminaDefense_BestWave")
end)

local memoryStore: {[string]: number} = {}

function LeaderboardService.reportWave(wave: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local key = tostring(player.UserId)
		if storeOk then
			task.spawn(function()
				pcall(function()
					store:UpdateAsync(key, function(old)
						return math.max(old or 0, wave)
					end)
				end)
			end)
		else
			memoryStore[key] = math.max(memoryStore[key] or 0, wave)
		end
	end
end

function LeaderboardService.getTop(count: number): {{name: string, wave: number}}
	local results = {}
	local raw: {{key: string, wave: number}} = {}

	if storeOk then
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, count)
		end)
		if ok then
			local page = pages:GetCurrentPage()
			for _, entry in ipairs(page) do
				table.insert(raw, {key = entry.key, wave = entry.value})
			end
		end
	else
		for key, wave in pairs(memoryStore) do
			table.insert(raw, {key = key, wave = wave})
		end
		table.sort(raw, function(a, b) return a.wave > b.wave end)
		if #raw > count then
			for i = #raw, count + 1, -1 do raw[i] = nil end
		end
	end

	for _, entry in ipairs(raw) do
		local name = "Player" .. entry.key
		if storeOk then
			pcall(function()
				name = Players:GetNameFromUserIdAsync(tonumber(entry.key))
			end)
		end
		table.insert(results, {name = name, wave = entry.wave})
	end
	return results
end

return LeaderboardService
