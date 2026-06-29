local BossConfig = {}

local BOSS_INTERVAL = 5
local BOSS_SCALE = 2.5

function BossConfig.isBossWave(waveNum: number): boolean
	return waveNum > 0 and waveNum % BOSS_INTERVAL == 0
end

function BossConfig.getBossNumber(waveNum: number): number
	return waveNum / BOSS_INTERVAL
end

function BossConfig.getStats(bossNum: number): {hp: number, damage: number, speed: number, reward: number}
	return {
		hp = 400 + bossNum * 300,
		damage = 15 + bossNum * 5,
		speed = 8 + bossNum * 0.5,
		reward = 100 + bossNum * 50,
	}
end

function BossConfig.getEscortCount(totalTowers: number): number
	if totalTowers < 10 then return 0 end
	return 2 + math.floor((totalTowers - 10) / 4) * 2
end

function BossConfig.getBossScale(): number
	return BOSS_SCALE
end

return BossConfig
