level = {}

Level = {}

LevelStatus = {}
LevelStatusStart = {}
LevelStatusRun = {}
LevelStatusWaveClosing = {}
LevelStatusClosing = {}
LevelStatusEnd = {}

-- Level state machine (currently endless, actually stops at level 100)
-- initial state: start
-- start -> run . Run status runs a wave
-- run -> waveclosing
-- waveclosing -> run
-- waveclosing -> closing
-- closing -> end
-- end -> run 

-- Levels are organized in waves. Each waves has a series of spawns. Between one wave and another there is a pause (all enemies must disappear from screen before the next wave can start)

-- running status 

-- structure
-- level (array):
---- waves (array):
------ spawns (array)

function readLevels() 
	local levelFile = love.filesystem.newFile("data/levels.dat","r")
	-- TODO check format version
	-- TODO sanitize input
	levels = {}
	local i = 1
	local level = {}
	local waves = {}
	local wave = {}
	local spawns = {}
	local mode = "NONE"
	for line in levelFile:lines() do
		if (line:match("#LEVEL")~=nil) then
			level = {}
			waves = {}
			level.waves = waves
			mode = "LEVEL"
			table.insert(levels,level)
		elseif (line:match("#WAVE")~=nil and mode=="LEVEL") then
			mode = "WAVE"
			wave = {}
			spawns = {}
			wave.spawns = spawns
			table.insert(waves,wave)
		elseif (mode=="WAVE") then
			local currspawn = {}
			local textSpawns = {}
			for item in line:gmatch("%d+%.?%d*") do
				table.insert(textSpawns,item)
			end
			
			if (#textSpawns>0) then
				currspawn.spawnTime= tonumber(textSpawns[1])
				currspawn.enemyType= tonumber(textSpawns[2])
				currspawn.pos = {tonumber(textSpawns[3]),tonumber(textSpawns[4])}
				table.insert(spawns,currspawn)
			end
		end
	end
end

readLevels()

currentLevel = 1


function Level:new()
	local l = {}
	setmetatable(l, self)
	self.__index = self
	return l
end

function LevelStatus:new() 
	local ls = {}
	setmetatable(ls, self)
	self.__index = self
	return ls
end

function LevelStatusStart:new() 
	local ls = {}
	setmetatable(ls, self)
	self.__index = self
	return ls
end

function LevelStatusRun:new() 
	local ls = {}
	setmetatable(ls, self)
	self.__index = self
	self.runTime=0
	return ls
end

function LevelStatusWaveClosing:new() 
	local ls = {}
	setmetatable(ls, self)
	self.__index = self
	return ls
end

function LevelStatusClosing:new() 
	local ls = {}
	setmetatable(ls, self)
	self.__index = self
	return ls
end

function LevelStatusEnd:new() 
	local ls = {}
	setmetatable(ls, self)
	self.__index = self
	return ls
end

function LevelStatusRun:update(dt) 	
	-- If there are no more spawns for this wave, go to wave closing
	local l = self.level
	if (self.waveSpawnIndex > #(l.currentWave.spawns)) then
		self.level.state = self.level.states.waveclosing
		self.level.state:enter()
	else
		self:spawnEnemies(dt)
	end
	
	
end

function LevelStatusStart:enter() 
	local l = self.level
	self.runTime = 0
	self.level.currentWaveIndex = 1
	self.level.state = self.level.states.run
	self.level.state:enter()
end

function LevelStatusRun:enter() 
	local l = self.level
	-- do nothing
	self.waveElapsedTime = 0
	self.waveSpawnIndex = 1
	self.waveSpawnAccruedTime = 0
	l.currentWave = levels[currentLevel].waves[l.currentWaveIndex]
end

function LevelStatusRun:draw(alpha) 
	-- do nothing
end

function LevelStatusClosing:enter() 
	self.waitCounter = 0
end

function LevelStatusClosing:update(dt) 
	local l = self.level
	self.waitCounter =  self.waitCounter + dt
	if (self.waitCounter > 5 and #(l.enemies) == 0 ) then
		l.state = l.states.endLevel
		l.state:enter()
	end
end

function LevelStatusWaveClosing:update(dt) 
	local l = self.level
	if (#(l.enemies) == 0 ) then
		if (l.currentWaveIndex < #(levels[currentLevel].waves)) then
			l.currentWaveIndex = l.currentWaveIndex + 1
			l.state = l.states.run
			l.state:enter()
		else 
			l.state = l.states.endLevel
			l.state:enter()
		end
	end
end

function LevelStatusWaveClosing:draw(alpha) 
	-- do nothing
end

function LevelStatusWaveClosing:enter() 
	-- do nothing
end

function LevelStatusClosing:draw(alpha) 
	-- do nothing
end

function LevelStatusEnd:enter() 
	self.waitCounter = 0
end

function LevelStatusEnd:update(dt) 
	local l = self.level
	self.waitCounter =  self.waitCounter + dt
	if (self.waitCounter > 5) then
		currentLevel = currentLevel + 1
		l.state = l.states.start
		l.state:enter()
	end
end

function LevelStatusEnd:draw(alpha)
	love.graphics.setColor(255, 255, 255)
	--TODO fixme
	local height = self.engine.screen.height
	local width = self.engine.screen.width
	love.graphics.printf("LEVEL CLEAR!",0,height/2,width,"center") 
end

function Level:enter()
	self.states = {}
	self.states.start = LevelStatusStart:new()
	self.states.run = LevelStatusRun:new()
	self.states.closing = LevelStatusClosing:new()
	self.states.waveclosing = LevelStatusWaveClosing:new()
	self.states.endLevel = LevelStatusEnd:new()
	
	
	for k,v in pairs(self.states) do
		v.level = self
		v.game = self.game
		v.engine = self.engine
	end 
	
	
	self.enemies = {}
	
	self.duration = 30

	self.state = self.states.start
	self.state:enter()
end

function Level:enemyPlaneDestroyed(plane)
	local i = nil
	for k,v in ipairs(self.enemies) do
		if v==plane then
			i = k
		end
	end
	table.remove(self.enemies,i)
end

function LevelStatusRun:spawnEnemy(spawn)
	-- spawn an Enemy
	local newEnemy = {x=spawn.pos[1], y=camera.y + camera.height + spawn.pos[2], state="fly", itemType="enemyPlane", vel = 150 , width = enemies.width, height = enemies.height, direction = math.rad(270) }
	newEnemy.game = self.game
	newEnemy.engine = self.engine
	newEnemy.energy = 100
	newEnemy.hitCooldown = 0
	newEnemy.prevCoord = {x = newEnemy.x, y = newEnemy.y}
	local l = self.level
	-- Manage bullet firing
	newEnemy.fireCoolDown = 1
	newEnemy.fireProbability = 60
	newEnemy.fireElapsed = 0
	newEnemy.enemyType = spawn.enemyType
	-- TODO standardize behaviour for types 1 and 2 
	--differentiate properties
	newEnemy.energy = newEnemy.energy * newEnemy.enemyType
	newEnemy.fireProbability = newEnemy.fireProbability / newEnemy.enemyType
	
	-- Explosions are used as a graphical fx when the enemy is killed
	newEnemy.explosions = {}
	
	if (newEnemy.enemyType == 2) then
		newEnemy.vel = newEnemy.vel / newEnemy.enemyType
	end
	if (newEnemy.enemyType == 3 ) then
		newEnemy.controller = EnemyControllerUTurn:forEnemy(newEnemy)
		newEnemy.vel = 250
	end 
	
	if (newEnemy.enemyType == 4) then
		newEnemy.controller = EnemyControllerBossOne:forEnemy(newEnemy)
		newEnemy.vel = 100
		newEnemy.energy = 1000
		newEnemy.width, newEnemy.height = 75, 67
	end

	
	world:add(newEnemy,newEnemy.x,newEnemy.y,newEnemy.width, newEnemy.height)
	table.insert(enemies.all,newEnemy)
	table.insert(l.enemies,newEnemy)
end

function LevelStatusRun:spawnEnemies(dt)

	local l = self.level
	self.waveElapsedTime = self.waveElapsedTime + dt
	while (self.waveSpawnIndex <= #(l.currentWave.spawns) and self.waveElapsedTime >= self.waveSpawnAccruedTime + l.currentWave.spawns[self.waveSpawnIndex].spawnTime ) do
		-- span current an move on
		self:spawnEnemy(l.currentWave.spawns[self.waveSpawnIndex])
		self.waveSpawnAccruedTime = self.waveSpawnAccruedTime + l.currentWave.spawns[self.waveSpawnIndex].spawnTime
		self.waveSpawnIndex = self.waveSpawnIndex + 1
		
	end
	--enemies.spawnElapsed = enemies.spawnElapsed + dt
end

function Level:update(dt)
	self.state:update(dt)
end

function Level:draw(alpha)
	self.state:draw(alpha)
end

level.Level = Level

return level