require('misc')

Player = {
		img = nil, 
		x = 40, y=0, 
		vel=250, 
		direction = {x=0,y=0},
		itemType = "playerPlane",
		visible=true,
		invincible=false,
		state = nil,
		respawnTime = 5,
		respawnElapsed =0,
		--statuses = {},
		continueTimeout = 0,
		lives = 0,
		prevCoord = {}
}


function Player:new(index)
	local p = {}   
	setmetatable(p, self)
	self.__index = self

	local machineGun = {coolDown = 0.15, elapsed = 0, baseCoolDown = 0.15, minCoolDown = 0.02, basePower = 1, maxPower= 3, power = 1, baseDamage = 40}
	p.weapon = machineGun

	p.name = 'player' .. tostring(index)
	p.index = index
	p.img = Player.imgs[index]
	p.statuses = {}
	p.statuses.fly = PlayerStatusFly:forPlane(p) 
	p.statuses.exploding = PlayerStatusExploding:forPlane(p)
	p.statuses.exploding.animation = Player.animations['explosion']
	p.statuses.exploding.parentStatus = p.statuses.fly -- point to new fly status (avoid state sharing)
	p.statuses.respawn = PlayerStatusRespawn:forPlane(p)  
	p.statuses.respawn.parentStatus = p.statuses.fly -- point to new fly status
	p.statuses.dead = PlayerStatusDead:forPlane(p)
	p.statuses.insertCoin = PlayerStatusInsertCoin:forPlane(p)
	p.statuses.insertCoin.parentStatus = p.statuses.dead
	p.statuses.spawn = PlayerStatusSpawn:forPlane(p)
	p.spawn = false 
	p.score = 0
	
	p.joystick = userinput.joysticks[index]
	p.keyboard = keyboardControls[index]
	p.prevCoord = {x=p.x,y=p.y}
	p.interpCoord = {}
	
	
	return p
end


function Player:destroyPlayerPlane()
	self.state = self.statuses.exploding
	self.state:enter()
end


function Player:handleWeaponFire(dt)
	local joystick = self.joystick
	if (love.keyboard.isDown(self.keyboard.fire) or  (joystick~= nil and joystick.buttons[BUTTON_FIRE]>0) or firing) and self.weapon.elapsed>=self.weapon.coolDown then 
		self.weapon.elapsed=0
		self:fireWeapon()
	end
	
	self.weapon.elapsed = self.weapon.elapsed + dt
end



function Player:handlePlaneMovement(dt)
	local vect = {x=0,y=0}
	local keyboard = self.keyboard
	local joystick = self.joystick
	--TODO check why userinput is not used on the keyboard (it's used on the joystick)
	if (love.keyboard.isDown(keyboard.up) or (joystick~= nil and joystick.axes[2]<0)) then
		vect.y = 1
	elseif (love.keyboard.isDown(keyboard.down) or (joystick~= nil and joystick.axes[2]>0)) then
		vect.y = -1 
	end
	
	if (love.keyboard.isDown(keyboard.right) or (joystick~= nil and joystick.axes[1]>0)) then
		vect.x = 1
	elseif (love.keyboard.isDown(keyboard.left) or (joystick~= nil and joystick.axes[1]<0)) then
		vect.x = -1 
	end
	
	self.direction = vect
end


function Player:movePlaneAccordingToSpeed(dt)
	local p = self
	local vect = p.direction
	
	p.prevCoord.x, p.prevCoord.y = p.x, p.y
	-- move it
	p.x,p.y = world:move(p,p.x+(p.vel*dt)*vect.x,p.y+vect.y*(p.vel*dt),function(a,b) return "cross" end)
	
	keepWithinBoundaries(p)
end

function Player:fireWeapon()
	-- fire a bullet
	local newBullet = {id=bullets.nextId, x=self.x, y=self.y + self.height, state="fly", itemType="playerBullet", width=53, height=14, img=bullets.img, texture = bullets.texture, power = self.weapon.power, baseDamage = self.weapon.baseDamage }
	newBullet.active = true
	newBullet.plane = self
	world:add(newBullet,newBullet.x,newBullet.y,newBullet.width,newBullet.height)
	table.insert(bullets.all,newBullet)
	bullets.nextId = bullets.nextId + 1
	local fireSound = bullets.sound:clone()
	fireSound:play()
	
end
