--!strict
local EconomyManager = {}

local Players = game:GetService("Players")

-- Stores money for each player in a simple dictionary
local playerMoney: {[number]: number} = {}

function EconomyManager.initPlayer(player: Player)
	playerMoney[player.UserId] = 500 -- Starting money (increased for testing)
end

function EconomyManager.getMoney(player: Player): number
	return playerMoney[player.UserId] or 0
end

function EconomyManager.addMoney(player: Player, amount: number)
	if playerMoney[player.UserId] then
		playerMoney[player.UserId] += amount
		-- TODO: Fire a RemoteEvent to update the client's UI
	end
end

function EconomyManager.deductMoney(player: Player, amount: number): boolean
	if playerMoney[player.UserId] and playerMoney[player.UserId] >= amount then
		playerMoney[player.UserId] -= amount
		-- TODO: Fire a RemoteEvent to update the client's UI
		return true
	end
	return false
end

Players.PlayerAdded:Connect(EconomyManager.initPlayer)

return EconomyManager
