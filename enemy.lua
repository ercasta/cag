require('core')
require('math')
require('animation')

local enemy = {}

enemy.types = {}


EnemyController = {}

-- Enemy explosions following enemy. They are independent objects. They do not interact with anything else. They move relatively to their base object.
-- They actually start at at a given offset from the base object and keep close to it.



EnemyExplosionController = {}

function EnemyExplosionController:new()
	local ps = {}
	setmetatable(ps, self)
	self.__index = self
	return ps
end

function EnemyExplosionController:attachTo(o)
	self.controlledObject = o
	local explosion = animation.Animation:forData(enemies.animations['explosion'])
	o.animation = explosion
end

function EnemyExplosionController:forEnemy(e,offset)
	self.enemy = e
	o = self.controlledObject
	o.x, o.y = e.x, e.y
	self.offset = offset
end

function EnemyExplosionController:update(dt)
	local o = self.controlledObject
	local enemy = self.enemy
	o.prevCoord.x , o.prevCoord.y = o.x, o.y
	o.x, o.y, o.direction, o.vel = enemy.x + self.offset.x, enemy.y + self.offset.y, enemy.direction, enemy.vel
	--o.x, o.y, o.direction, o.vel = enemy.x, enemy.y , enemy.direction, enemy.vel
	o.animation:update(dt)
  if o.animation:isFinished() then
    o.remove = True
    if (self.spawner ~= nil) then
        self.spawner:explosionFinished(self)
    end
  end
end

-- TODO move this to renderer
function EnemyExplosionController:draw(alpha)
	local o = self.controlledObject
	local enemy = self.enemy
	-- use interpolated coords, without interpolation there is visible stuttering
	local ix, iy = interpolateCoords(o.x,o.y,o.prevCoord.x,o.prevCoord.y,alpha)
	local img = o.animation:getFrame(alpha)
	local imgX,  imgY,  imgW,  imgH = img:getViewport()
	love.graphics.draw(o.animation.data.texture, img, getCameraCoords(ix, iy + imgH))
end


-- spawns multiple explosions, for example for a boss, with a given interval and offset
MultiExplosionSpawner = {}

function MultiExplosionSpawner:new()
	local ps = {}
	setmetatable(ps, self)
	self.__index = self
	ps.interval = 0
	ps.counter = 0
	ps.explosionInterval = 0.3
	ps.explosionCounter = 7
  ps.explosions = {}
  ps.phase = "starting"
	return ps
end

function MultiExplosionSpawner:spawnNewEnemyExplosion(enemy,offset)
	local explosion = GameObject:new()
	explosion.refEnemy = enemy
	explosion.controller = EnemyExplosionController:new()
	explosion.controller:attachTo(explosion)
  explosion.spawner = self
	explosion.controller:forEnemy(enemy,offset)
	explosion.renderer = explosion.controller -- ugly, object with multiple responsibilities
	local expS = enemies.explosionSound:clone()
	table.insert(effects.all,explosion) -- global effects table
    table.insert(self.explosions, explosion) -- table managed by the explosion spawner
	expS:play()
	return explosion
end

function MultiExplosionSpawner:explosionFinished(explosion)
  local i = nil
    for k,v in ipairs(self.explosions) do
      if v==explosion then
        i = k
        break
      end
    end
    table.remove(self.explosions,i)
end

function MultiExplosionSpawner:isFinished() 
  return self.phase=="stopping" and #self.explosions==0
end

function MultiExplosionSpawner:forEnemy(enemy)
	self.enemy = enemy
end

function MultiExplosionSpawner:startExplosions()
	self.interval = 0
	self.counter = 0
end

function MultiExplosionSpawner:getOffset(dt)
	--TODO improve positioning
	return {x=((self.counter%3)*(self.enemy.width/6)), y=((self.counter%3)*(self.enemy.height/6))}
--	return {x=0,y=0}
end

function MultiExplosionSpawner:update(dt)
	self.interval = self.interval + dt
	while (self.interval >= self.explosionInterval and self.counter < self.explosionCounter) do
		self.interval = self.interval - self.explosionInterval
		-- spawn an explosion 
		self:spawnNewEnemyExplosion(self.enemy, self:getOffset(dt))
		self.counter = self.counter  + 1
	end
  if (self.counter == self.explosionCounter) then
      self.phase = "stopping"
  end
end

function EnemyController:new()
	local ps = {}
	setmetatable(ps, self)
	self.__index = self
	return ps
end

function EnemyController:forEnemy(enemy)
	local ps = {}
	setmetatable(ps, self)
	self.__index = self
	ps.enemy = enemy
	enemy.doTurn = false
	ps.game = enemy.game
	ps.engine = enemy.engine
	return ps
end

function EnemyController.draw(alpha)
	-- Empty implementation
end

function EnemyController.update(dt)
	-- Empty implementation
end


-- Actual Types

EnemyControllerUTurn = EnemyController:new()

function EnemyControllerUTurn:controlDirection(dt) 
	local v = self.enemy
end

function EnemyControllerUTurn:update(dt)
	local v = self.enemy
	local screen = self.engine.screen
	-- TODO deduplicate from standard behaviour
	destroySelf = false
	v.hitCooldown = v.hitCooldown - dt
	
	--checkFireEnemyBullet(dt,v)
	
	v.prevCoord.x, v.prevCoord.y = v.x, v.y
	-- decide direction. This plane makes a U turn when it gets to a given point (80% from camera upper bound)
	
	v.x,v.y, cols, colLen=world:move(v,v.x + v.vel*math.cos(v.direction)*dt,v.y + v.vel*math.sin(v.direction)*dt,enemyPlaneCollision)
	
	if (v.y - camera.y < screen.height*0.2 and v.doTurn == false) then
		v.doTurn = true
		v.oldVel = v.vel
	end
	if (v.doTurn) then
		v.direction = math.rad(math.deg(v.direction) - 180*dt/2)
		v.vel = 50
		if (v.direction <= math.rad(90)) then
			v.vel = v.oldVel
			v.direction = math.rad(90)
		end
	end 
	
	if (v.doTurn and v.y > camera.y + screen.height)  then
		v.state = "offscreen"
	end
	
	if colLen>0 then
		for ck,cv in ipairs(cols) do
			if cv.other.itemType == "playerBullet" then 
				if v.hitCooldown < -0.1 then
            v.hitCooldown = 0.1
        end
				cv.other.active = false
				v.energy = v.energy - cv.other.baseDamage*(0.5+cv.other.power*0.5)
				if (v.energy <=0) then
					destroySelf = true
					cv.other.plane.score = cv.other.plane.score + 100
				end
			elseif cv.other.itemType == "playerPlane" and not cv.other.invincible == true then
				destroySelf = true 
				cv.other:destroyPlayerPlane()
			end
		end
	end
	if destroySelf then
		v.state="boom"
		checkSpawnPowerup(dt,v)
		local expS = enemies.explosionSound:clone()
		expS:play()
	end
	
end

function EnemyControllerUTurn:draw(dt)
	
end

-- This controller (WIP) controls boss behaviour for boss 1. This behaviour follows a sequence of states:
-- Enter screen: move slowly forward without firing
-- Move: moves from left to right and back, firing 3-way shots
EnemyControllerBossOne = EnemyController:new()

function EnemyControllerBossOne:forEnemy(enemy)
	--local ps = EnemyController:forEnemy(enemy)
	local ps = {}
	setmetatable(ps, self)
	self.__index = self
	ps.game = enemy.game
	ps.engine = enemy.engine
	ps.enemy = enemy
	enemy.doTurn = false
	enemy.fireCoolDown = 3
	enemy.fireIntervalSingle = 0.3
	enemy.strafeDirection = 0
	enemy.fireCoolDownCurrent = enemy.fireCoolDown
	enemy.fireIntervalCurrent = 0
	enemy.fireCounter = 0
	enemy.bossState = "entering"
	enemy.firingSpree = false
	enemy.explodingTime = 4 --duration of final multi explosion
	enemy.explosionInterval = 0.3
	enemy.explosionTotal = 15 -- more than 4 seconds
	return ps
end

function EnemyControllerBossOne:fire(dt)
	local enemy = self.enemy
	local spawnBullets = {}
	local startPos = { x = enemy.x + enemies.width/2 - enemyBullets.img:getWidth()/2 , y = enemy.y }
	
	if (enemy.state=="fly" and enemy.fireCoolDownCurrent <= 0 and enemy.fireIntervalCurrent <= 0 and enemy.fireCounter < 3 ) then
		enemy.fireIntervalCurrent = enemy.fireIntervalSingle
		-- spawn 3 bullets
		local xDirs = {-0.2,0,0.2}
		local yDir = -1
		for kx,bx in pairs(xDirs) do
			local length = math.sqrt(bx*bx + yDir*yDir)
			local dir = {x = bx, y = yDir }
			local enemyBullet = {x = startPos.x, y = startPos.y, direction = dir, vel = enemyBullets.vel, itemType="enemyBullet", width = enemyBullets.img:getWidth(), height = enemyBullets.img:getHeight(), state="fly"}
			table.insert(spawnBullets,enemyBullet)
		end

		for k,v in pairs(spawnBullets) do
			table.insert(enemyBullets.all,v)
			world:add(v, v.x, v.y, v.width, v.height)
		end
		
		enemy.fireCounter = enemy.fireCounter + 1
	end
	
	if (enemy.fireCounter == 3) then
		-- done firing 3 times, reset timer
		enemy.fireCounter = 0 
		enemy.fireCoolDownCurrent = enemy.fireCoolDown
	end 
	
end

function EnemyControllerBossOne:strafe(dt)
	local v = self.enemy
	local screen = self.engine.screen
	v.x,v.y, cols, colLen=world:move(v,v.x + v.vel*math.cos(v.strafeDirection)*dt,v.y + v.vel*dt,enemyPlaneCollision)
	keepWithinBoundaries(v)
	-- flip when touching border
	if (v.strafeDirection == 0 and v.x + v.width >= screen.width) then
		v.strafeDirection = math.rad(180)
	elseif (v.x==0 and v.strafeDirection == math.rad(180)) then
		v.strafeDirection = 0
	end
end

function EnemyControllerBossOne:explode(dt)
  local mes = self.multiExplosionSpawner 
  local v = self.enemy
  if (v.state~="exploding") then
    v.state="exploding"
    v.bossState = "exploding"
    mes = MultiExplosionSpawner:new()
    mes:forEnemy(v)
    mes:startExplosions()
    self.multiExplosionSpawner = mes
  elseif (v.state=="exploding" and mes:isFinished()) then
    v.state="boom"
  elseif (v.state=="exploding" and not mes:isFinished()) then
    mes:update(dt)
    -- update explosions (animations)
--    local v = self.enemy
--    for k,e in pairs(v.explosions) do
--      e:update(dt)
--    end
  end
end

function EnemyControllerBossOne:update(dt)
	--TODO deduplicate, implement multi explosions
	local v = self.enemy

	v.prevCoord.x, v.prevCoord.y = v.x, v.y
	

	v.hitCooldown = v.hitCooldown - dt
	v.fireCoolDownCurrent = v.fireCoolDownCurrent - dt
	v.fireIntervalCurrent = v.fireIntervalCurrent - dt
	
	destroySelf = false
	
	if v.bossState == "entering" then
		v.direction = math.rad(270)
		v.x,v.y, cols, colLen=world:move(v,v.x,v.y + v.vel*math.sin(v.direction)*dt,enemyPlaneCollision)
		if (v.y + v.height < camera.y + camera.height) then 
			v.bossState = "strafe"
			v.strafeDirection = math.rad(180)
		end
	elseif v.bossState == "strafe" then
		self:strafe(dt)
		self:fire(dt)
	elseif v.bossState == "exploding"  then
		v.explodingTime = v.explodingTime - dt
		self:strafe(dt)
		self:explode(dt)
	end

	
	
	-- TODO deduplicate from standard behaviour. Must handle exploding time
	if (v.state=="fly") then
		if colLen>0 then
			for ck,cv in ipairs(cols) do
				if cv.other.itemType == "playerBullet" then 
					if v.hitCooldown < 0 then
            v.hitCooldown = 0.1
          end
					cv.other.active = false
					v.energy = v.energy - cv.other.baseDamage*(0.5+cv.other.power*0.5)
					if (v.energy <=0) then
						destroySelf = true
						cv.other.plane.score = cv.other.plane.score + 1000
					end
				elseif cv.other.itemType == "playerPlane" and not cv.other.invincible == true then
					cv.other:destroyPlayerPlane()
				end
			end
		end
		if destroySelf then
			self:explode()
			checkSpawnPowerup(dt,v)
		end
	end
	
	
end

function EnemyControllerBossOne:draw(dt)
	
end

return enemy