animation = require('animation')

PlayerStatus = {}

function PlayerStatus:new(parentStatus)
	local ps = {}
	setmetatable(ps, self)
	self.__index = self
--	ps.parentStatus = parentStatus
	return ps
end

-- player state machine
-- initial state (at level start, or insert coin): spawn 
-- spawn -> fly
-- fly -> exploding
-- exploding -> respawn (if still has lives) 
-- exploding -> dead (if no more lives)
-- dead -> respawn (if player continues)
-- dead -> insert coin (if player does not continue)
-- respawn -> fly
-- 
--
--
--

-- manage player statuses. It's a hierarchical state machine, however due to Lua not having real classes, hierarchy must be rebuilt for each plane 
-- otherwise statuses are shared (o_o)
PlayerStatusFly = PlayerStatus:new() 
PlayerStatusRespawn = PlayerStatus:new(PlayerStatusFly)
PlayerStatusDead = PlayerStatus:new(PlayerStatusFly)
PlayerStatusInsertCoin = PlayerStatus:new(PlayerStatusDead)
PlayerStatusSpawn = PlayerStatus:new(PlayerStatusFly)
PlayerStatusExploding = PlayerStatus:new(PlayerStatusFly)

function PlayerStatusSpawn:enter(dt)
	local p = self.plane
	world:add(p,p.x,p.y,p.width,p.height)
	p.state = p.statuses.fly
	p.lives = 3 
	p.state:enter()
end

function PlayerStatusSpawn:draw(alpha)
	-- do nothing
end

function PlayerStatusSpawn:update(dt)
	-- do nothing
end

function PlayerStatusExploding:enter(dt)
	local p = self.plane
	--world:remove(p)
	self.plane.invincible = true
	self.anim =  animation.Animation:forData(Player.animations['explosion'])
	self.anim.animTime = 0
	p.lives = p.lives - 1
	local expS = enemies.explosionSound:clone()
	expS:play()
	
end

function PlayerStatusExploding:draw(alpha)
	self.parentStatus:drawWithImage(alpha,self.anim:getFrame(alpha))
end

function PlayerStatusExploding:update(dt)
	-- just keep moving according to speed
	local p = self.plane
	p:movePlaneAccordingToSpeed(dt)
	self.anim:update(dt)
	
	-- After 2 seconds, check the next state (dead or respawn)
	if (self.anim.animTime>2) then 
		if (p.lives > 0) then
			p.state=p.statuses.respawn
		elseif(p.lives <= 0 ) then	
			p.state = p.statuses.dead
		end
		p.state:enter()
	end
end

function PlayerStatusRespawn:update(dt)
	-- hierarchical FSM
	self.parentStatus:update(dt)
	local p = self.plane
	p.respawnElapsed = p.respawnElapsed + dt
	if p.respawnElapsed > p.respawnTime then
		p.state = p.statuses.fly
		p.state:enter()
	end
end

function PlayerStatusInsertCoin:draw(alpha)
	-- do nothing
end

function PlayerStatusInsertCoin:enter(dt)
	-- do nothing
end

function PlayerStatusInsertCoin:update(dt)
	self.parentStatus:checkPlayerStartGame(dt)
end


function PlayerStatusRespawn:draw(alpha)
	local p = self.plane
	if math.floor(p.respawnElapsed*1000) % 100 > 50 then
		self.parentStatus:draw(alpha)
	end
end

function PlayerStatusDead:draw(alpha)
	-- do nothing
end

function PlayerStatusDead:checkPlayerStartGame(dt) 
	local p = self.plane
	local joystick = p.joystick
	if (love.keyboard.isDown(self.plane.keyboard.spawn) or p.spawn==true or (joystick~= nil and joystick.buttons[BUTTON_SPAWN]>0)) and credits > 0 then
		p.spawn = false
		credits = credits - 1 
		p.lives = 3
		world:add(p,p.x,p.y,p.width,p.height)
		p.state = p.statuses.respawn
		if (p.status==p.statuses.insertCoin) then
			-- we didn't continue, reset score
			p.score = 0
		end
		p.state:enter()
	end
end

function PlayerStatus:forPlane(plane)
	local ps = {}
	setmetatable(ps, self)
	self.__index = self
	ps.plane = plane
	return ps
end


function PlayerStatusRespawn:enter()
	local p = self.plane
	self.plane.invincible = true
	self.plane.weapon.coolDown = self.plane.weapon.baseCoolDown
	self.plane.weapon.power = 1
	--world:add(p,p.x,p.y,p.width,p.height)
	self.plane.respawnElapsed=0
end

function PlayerStatusDead:enter()
	world:remove(self.plane)
	self.plane.continueTimeout=10
	self.plane.spawn=false
end


function PlayerStatusDead:update(dt)
	self.plane.continueTimeout = self.plane.continueTimeout - dt 
	self:checkPlayerStartGame(dt)
	if (self.plane.continueTimeout <= 0 ) then
		self.plane.continueTimeout = 0
		self.plane.state = self.plane.statuses.insertCoin
		self.plane.state:enter()
	end
end

function PlayerStatusFly:enter()
	self.plane.invincible = false
end


function PlayerStatusFly:update(dt)
	local p = self.plane
	
	p:handlePlaneMovement(dt)
	p:handleWeaponFire(dt)
	p:movePlaneAccordingToSpeed(dt)
	
	
end

function PlayerStatusFly:draw(alpha)
	local p = self.plane
	self:drawWithImage(alpha,p.img)
end

-- Specifing the image allows external image selection within animation
function PlayerStatusFly:drawWithImage(alpha,img)
	local p = self.plane
	local ix, iy = interpolateCoords(p.x,p.y,p.prevCoord.x,p.prevCoord.y,alpha)
	love.graphics.draw(p.texture, img, getCameraCoords(ix, iy +  p.height))
end