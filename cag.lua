local bump = require 'bump'
local math = require 'math'

startscreen = require('startscreen')
require('player')
require('playerstatus')
require('gameover')
require('level')
require('enemy')
dave = require('dave')


-- Set game width and height. Y axis is flipped wrt to LOVE standard: 0 is bottom border 
local WIDTH, HEIGHT = 480, 360

players={}

TIMESTEP = 0.02
JOYSTICK_THRESHOLD=0.15
POWERUP_SPEED_BONUS = 1.15

--Button constant declarations
BUTTON_FIRE='fire'
BUTTON_COIN='coin'
BUTTON_SPAWN='spawn'


music = nil

demomode = false

totalVideoTime = 0

keyboardControls = {
{up='up', down='down' , left = 'left', right = 'right', fire = 'space', spawn='1', coin='m'},
{up='w', down='s' , left = 'a', right = 'd', fire = 'f', spawn='2', coin='c'},
}

joypadButtonMapping = {
  {[BUTTON_FIRE]=1, [BUTTON_COIN]=2, [BUTTON_SPAWN]=3},
  {[BUTTON_FIRE]=1, [BUTTON_COIN]=2, [BUTTON_SPAWN]=3}
}

credits = 10

-- used for recording and playing back the game
gameRecordFile = nil
tick = 0




camera = {x=0,y=0, width = WIDTH, height = HEIGHT-50, vel=30, ox=0, oy=50}

sfondo = {img = nil}
bullets = {nextId=1 , img = nil, all={}, vel=500}
enemyBullets = {img = nil, all= {}, vel = 120}
enemies = {img = nil, all= {}, vel = 100, spawnCooldown = 1.5, spawnElapsed = 0}

powerups = {img=nil, all= {}}
effects = {all={}}

joystick = nil
joysticks = {}

firing = false

bulletsFired = 0

local game = dave.newGame()

-- function that tells the bump library how to react to object collisions
local playerFilter = function(item, other)
  return 'cross' 
end



-- The game has 3 screens: startscreen, levelrunning, game over 
levelrunning = {}
levelrunning.game = game




function levelrunning.enter()
	levelrunning.game.currentScreen = levelrunning
	levelrunning.engine = levelrunning.game.engine
	
	tick = 0 
	userinput.setupUserInput(joypadButtonMapping)
		
	-- creates a new bump world
	world = bump.newWorld(50)
	
	
	players[1] = Player:new(1)
	players[2] = Player:new(2)
	
	players[1].state = players[1].statuses.spawn
	players[1].state:enter()
	
	players[2].state = players[2].statuses.insertCoin
	players[2].state:enter()
	
	
	bullets.all = {}
	enemies.all= {}
	enemyBullets.all = {}
	enemies.spawnElapsed = 0
	curlevel = level.Level:new()
	curlevel.game = game
	curlevel.engine = game.engine
	
	curlevel:enter()
	music:play()
	

end


function fireEnemyBullet(dt,enemy)
	local spawnBullets = {}
	local startPos = { x = enemy.x + enemies.width/2 - enemyBullets.img:getWidth()/2 , y = enemy.y }
	if (enemy.enemyType==1) then 
		local xDir = love.math.random(-1,1)/5 -- random angle
		local yDir = -1
		local length = math.sqrt(xDir*xDir + yDir*yDir)
		local dir = {x = xDir / length, y = yDir / length}
		local enemyBullet = {x = startPos.x, y = startPos.y, direction = dir, vel = enemyBullets.vel, itemType="enemyBullet", width = enemyBullets.img:getWidth(), height = enemyBullets.img:getHeight(), state="fly"}
		table.insert(spawnBullets,enemyBullet)
	else
		-- spawn 3 bullets
		-- TODO refactor 
		local xDirs = {-0.2,0,0.2}
		local yDir = -1
		for kx,bx in pairs(xDirs) do
			local length = math.sqrt(bx*bx + yDir*yDir)
			local dir = {x = bx, y = yDir }
			local enemyBullet = {x = startPos.x, y = startPos.y, direction = dir, vel = enemyBullets.vel, itemType="enemyBullet", width = enemyBullets.img:getWidth(), height = enemyBullets.img:getHeight(), state="fly"}
			table.insert(spawnBullets,enemyBullet)
		end
	end 
	for k,v in pairs(spawnBullets) do
		table.insert(enemyBullets.all,v)
		world:add(v, v.x, v.y, v.width, v.height)
		bulletsFired = bulletsFired + 1 
	end
	
end

function enemyBulletCollision(item, other)
	return "cross"
end


function updateEnemyBullets(dt)
	local newList = {}
	for k,v in ipairs(enemyBullets.all) do
		v.x,v.y, cols, colLen=world:move(v, v.x + v.direction.x * v.vel *  dt, v.y + v.direction.y * v.vel * dt,enemyBulletCollision)
		if colLen>0 then
			for ck,cv in ipairs(cols) do
				if cv.other.itemType == "playerPlane" and not cv.other.invincible then 
					cv.other:destroyPlayerPlane()
					v.state="boom"
					world:remove(v)
				end
			end
		end
	end
	
	for k,v in ipairs(enemyBullets.all) do
		if v.state=="fly" and v.y + v.height > camera.y then
			table.insert(newList,v)
		end
	end
	
	enemyBullets.all = newList
	
end

function checkFireEnemyBullet(dt,enemy) 
	if enemy.fireElapsed > enemy.fireCoolDown then
		enemy.fireElapsed = 0
		if enemy.fireProbability > love.math.random(100) then
			fireEnemyBullet(dt,enemy)
		end
	end
	enemy.fireElapsed = enemy.fireElapsed + dt
end




function bulletCollision(item,other)
 return "cross"
end

function enemyPlaneCollision(item,other)
 return "cross"
end


function updateEnemyPlanes(dt)

	local newAll = {}
	local cols = nil
	local colLen = nil
	local destroySelf = false
	for k,v in ipairs(enemies.all) do
		if (v.enemyType==1 or v.enemyType==2)  then 
			destroySelf = false
			if (v.state=="fly") then
				-- TODO refactor
				v.hitCooldown = v.hitCooldown - dt
				checkFireEnemyBullet(dt,v)
				v.prevCoord.x, v.prevCoord.y = v.x, v.y
				v.x,v.y, cols, colLen=world:move(v,v.x + v.vel*math.cos(v.direction)*dt,v.y + v.vel*math.sin(v.direction)*dt,enemyPlaneCollision)
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
			elseif (v.state=="exploding") then
				v.explodingCountDown = v.explodingCountDown - dt
				for e,ee in pairs(v.explosions) do
					ee:update(dt)
				end
				if (v.explodingCountDown <= 0) then
					v.state="boom"
				end 
			end
			if destroySelf then
				v.state="exploding"
				v.explodingCountDown = 2
				local explosion = animation.Animation:forData(enemies.animations['explosion'])
				table.insert(v.explosions,explosion)
				checkSpawnPowerup(dt,v)
				local expS = enemies.explosionSound:clone()
				expS:play()
			end
		else
			-- plane types > 2 currently have custom behaviour
			v.controller:update(dt)
		end
		
		
	end
	
	
	
	for k,v in ipairs(enemies.all) do
		if (v.state=="fly" or v.state=="exploding") and v.y + v.height > camera.y then 
			table.insert(newAll,v)
		else 
			world:remove(v)
			curlevel:enemyPlaneDestroyed(v)
		end
	end
	
	enemies.all = newAll

end

function updateBullets(dt)

	local newAll = {}
	
	for k,v in ipairs(bullets.all) do
		v.x,v.y=world:move(v,v.x,v.y+bullets.vel*dt,bulletCollision)
		if v.y > camera.y + camera.height or v.active == false then
			v.state="boom"
			world:remove(v)
		end
	end
	
	
	for k,v in ipairs(bullets.all) do
		if v.state=="fly" then
			table.insert(newAll,v)
		end
	end
	
	bullets.all = newAll
	
end

function checkSpawnPowerup(dt,enemypos) 
	local test = love.math.random(0,10)	
	if (test>9) then
		spawnPowerup(dt,enemypos)
	end
end

function applyPowerUpWeaponSpeed(plane) 
	plane.weapon.coolDown = math.max(plane.weapon.coolDown / POWERUP_SPEED_BONUS, plane.weapon.minCoolDown ) 	
end

function applyPowerUpWeaponPower(plane)
	if plane.weapon.power < plane.weapon.maxPower then
		plane.weapon.power = plane.weapon.power + 1 
	end 
end


function spawnPowerup(dt,enemypos)
	local startPos = { x = enemypos.x + enemypos.width/2 , y = enemypos.y }
	local xDir = love.math.random(-0.2,0.2) -- random angle
	local yDir = -1
	local length = math.sqrt(xDir*xDir + yDir*yDir)
	local dir = {x = xDir / length, y = yDir / length}
	local xDir = love.math.random(-0.2,0.2) -- random angle
	local powerup = {x = startPos.x, y = startPos.y, direction = dir, vel = 10, itemType="powerup", width = powerups.width, height = powerups.height, state="fly", active=true }
	if love.math.random()> 0.5 then
		powerup.powerupType = "weaponSpeed"
		powerup.pFunction = applyPowerUpWeaponSpeed
		powerup.img = powerups.imgWeaponSpeed
	else 
		powerup.powerupType = "weaponPower"
		powerup.pFunction = applyPowerUpWeaponPower
		powerup.img = powerups.imgWeaponPower
	end
	world:add(powerup, powerup.x, powerup.y, powerup.width, powerup.height)
	table.insert(powerups.all,powerup)
end

function updatePowerups(dt)

	local newAll = {}
	
	for k,v in ipairs(powerups.all) do
		v.x,v.y, cols, colLen =world:move(v,v.x + v.direction.x * v.vel *  dt, v.y + v.direction.y * v.vel * dt,bulletCollision)
		if colLen>0 then
			for ck,cv in ipairs(cols) do
				if cv.other.itemType == "playerPlane" then
					v.pFunction(cv.other)
					v.active=false
					-- assign the bonus just to one player
					break
				end
			end
		end
		if v.y > camera.y + camera.height or v.active == false then
			world:remove(v)
		end
	end
	
	
	for k,v in ipairs(powerups.all) do
		if v.active==true then
			table.insert(newAll,v)
		end
	end
	
	powerups.all = newAll
	
end



function drawEffects(objectList,alpha)
-- standard draw. TODO decide whether to use single spritebatch for all
	for k,v in ipairs(objectList) do
    v:draw(alpha)
	end
end

function updateEffects(dt)

	local newAll = {}
	
	for k,v in ipairs(effects.all) do
		v:update(dt)
	end
	for k,v in ipairs(effects.all) do
		if v.remove==false then
			table.insert(newAll,v)
		end
	end
	
	effects.all = newAll
	
end




function keepWithinBoundaries(p)
--keep within boundaries
	minx = camera.x
	maxx = camera.x + camera.width - p.width
	
	miny = camera.y 
	maxy = camera.y + camera.height - p.height
	
	-- y boundaries
	if p.y < miny then  
		p.y = miny 
		world:update(p,p.x,miny)
	elseif p.y > maxy then
		p.y = maxy 
		world:update(p,p.x,maxy)
	end
		
	-- x boundaries
	if p.x < minx then  
		p.x = minx
		world:update(p,minx,p.y)
	elseif p.x > maxx then
		p.x = maxx 
		world:update(p,maxx,p.y)
	end
end


function levelrunning.update(dt) 
	
	

	camera.y = camera.y + camera.vel*dt
	
	for k,v in ipairs(players) do
		v.state:update(dt)
	end
	
	
	updateBullets(dt)
	updateEnemyPlanes(dt)
	updateEnemyBullets(dt)
	updatePowerups(dt)
	updateEffects(dt)
	curlevel:update(dt)
	
	inPlay = false
	for k,v in ipairs(players) do
		if v.state ~= v.statuses.insertCoin then
			inPlay = true
		end
	end
	
	if not inPlay then
		game_over.game = game
		game_over.enter()
	end
end

function drawBullets(alpha)
	for k,v in ipairs(bullets.all) do
		love.graphics.draw(bullets.texture, bullets.imgPower[v.power], getCameraCoords(v.x, v.y + v.height))
	end
end

-- Generic function
function drawSpriteList(spritelist, alpha)
	local sb = spritelist.spriteBatch
	sb:clear()
	for k,v in ipairs(spritelist.all) do
		sb:add(v.img, getCameraCoords(v.x, v.y + v.height) )
	end
	love.graphics.draw(sb)
end
	
function drawEnemyImage(ix,iy,enemy,texture,image)
		local imgX,  imgY,  imgW,  imgH = image:getViewport()
		local drawX, drawY = getCameraCoords(ix, iy + enemies.height)
		-- TODO: understand why setting the origin to imgW/2, imgH/2 does not yield correct result, while setting it to imgW, imgH seems to work
		-- There might be a bug in my code with mapping to camera coordinates
		-- looks like so, looking at the behaviour of the plane when it Uturns (it moves to the right, it means it's not centered ).
		-- After restoring "correct" rotation, it flips correctly, but world coordinates are probably off by w/2
		-- ok, solution is: changing the origin also applies to offset, so it must be compensated
		-- Note: rotation is in opposite direction
		love.graphics.draw(texture, image, drawX + imgW/2, drawY + imgH/2,-math.rad(math.deg(enemy.direction) -90 ),1,1, imgW/2, imgH/2)
end

function drawEnemies(alpha)
	for k,v in ipairs(enemies.all) do
		-- use interpolated coords, without interpolation there is visible stuttering
		local ix, iy = interpolateCoords(v.x,v.y,v.prevCoord.x,v.prevCoord.y,alpha)
		local r,g,b,a = love.graphics.getColor()
		if v.hitCooldown > 0 then
			love.graphics.setColor(255,100,100,255)
		end
		if (v.state=="fly") then 
			drawEnemyImage(ix,iy,v,enemies.texture, enemies.images[v.enemyType])
		end
		love.graphics.setColor(r,g,b,a)
		
		if (v.state=="exploding" and v.enemyType ~= 4 ) then
			-- draw explosions
			for kk,explo in pairs(v.explosions) do
				local img = explo:getFrame(alpha)
				drawEnemyImage(ix,iy,v,explo.data.texture, img)
			end
		end
		
	end
end


function drawEnemyBullets(alpha) 
	local sb = enemyBullets.spriteBatch
	sb:clear()
	for k,v in ipairs(enemyBullets.all) do
		sb:add(getCameraCoords(v.x, v.y + sb:getTexture():getHeight()) )
	end
	love.graphics.draw(sb)
end



function levelrunning.drawHud(alpha,player)

	
	love.graphics.setColor( 255, 255, 255, 255 )
	
	
	local totalSpaceRequired = 3 * ((player.width)) + 20
	xOffset = (WIDTH - totalSpaceRequired) * (player.index-1) -- only for p2
	
	if (player.state == player.statuses.dead) then
		-- draw countDown
		love.graphics.print("CONTINUE?: ".. math.ceil(player.continueTimeout), 0 + xOffset*1.25, 0)
	elseif (player.state == player.statuses.insertCoin) then
		love.graphics.print("INSERT COIN", 0+xOffset*1.25, 0)
	else 
		love.graphics.print("SCORE:" .. tostring(player.score), 0+xOffset*1.25, 0)
		-- draw planes
		for i=1,player.lives,1 do
			love.graphics.draw(Player.texture,player.img,xOffset+(Player.width + 10)*(i-1),20, 0, 0.5,0.5)
		end
	end
	
	love.graphics.printf("CREDITS: ".. tostring(credits),0,0,WIDTH,"center") 
	
	
	
end

function levelrunning.draw(alpha)

	-- disegna lo sfondo: replica la tile N volte
	numtimesw = WIDTH/sfondo.img:getWidth()
	numtimesh = HEIGHT/sfondo.img:getHeight()
	
	local sb = sfondo.spriteBatch
	sb:clear()
	for i=0,numtimesw+1,1 do
		for j=-1, numtimesh+1,1 do -- draw "higher" than the upper border
			sb:add(i*sfondo.img:getWidth(), j*sfondo.img:getHeight() + camera.y%sfondo.img:getHeight())
		end
	end
	love.graphics.draw(sb)
	
	
	-- pressing d on keyboard shows fps
	if love.keyboard.isDown('p') then
		fps = tostring(love.timer.getFPS())
		love.graphics.print("FPS: "..fps, 0, HEIGHT-30)
		love.graphics.print("BulletsFired: "..tostring(bulletsFired), 0, HEIGHT-60)
		love.graphics.print("PlayerPos: "..tostring(players[1].x) .. ",".. tostring(players[1].y), 0, HEIGHT-80)
	end
	
	for i=1,#players,1 do
		players[i].state:draw(alpha)
	end
	
	drawBullets(alpha)
	drawEnemies(alpha)
	drawEnemyBullets(alpha)
	drawSpriteList(powerups,alpha)
	drawEffects(effects.all,alpha)
	
	love.graphics.setColor( 0, 0 ,0 , 255 )
	love.graphics.rectangle( "fill", 0,0, WIDTH, 50 )
	
	for i=1,#players,1 do
		levelrunning.drawHud(alpha,players[i])
	end
	
	curlevel:draw(alpha)
end

local function loadGameImages(arg)
	
	-- Load all images
	logoImg = love.graphics.newImage('res/images/Logo.png')
	local spritesheet = love.graphics.newImage('res/images/spritesheet.png')
	Player.imgs = {}
	Player.imgs[1] = love.graphics.newQuad(0, 0, 53, 48, spritesheet:getDimensions())
	Player.imgs[2] = love.graphics.newQuad(110, 0, 53, 48, spritesheet:getDimensions())
	Player.animations = {}
	Player.animations['explosion'] = {}
	Player.animations['explosion'].images = {}
	Player.animations['explosion'].images[1] = love.graphics.newQuad(1, 186, 62, 62, spritesheet:getDimensions())
	Player.animations['explosion'].images[2] = love.graphics.newQuad(65, 186, 62, 62, spritesheet:getDimensions())
	Player.animations['explosion'].images[3] = love.graphics.newQuad(129, 186, 62, 62, spritesheet:getDimensions())
	Player.animations['explosion'].images[4] = love.graphics.newQuad(193, 186, 62, 62, spritesheet:getDimensions())
	Player.animations['explosion'].images[5] = love.graphics.newQuad(257, 186, 62, 62, spritesheet:getDimensions())
	Player.animations['explosion'].images[6] = love.graphics.newQuad(321, 186, 62, 62, spritesheet:getDimensions())
	Player.animations['explosion'].images[7] = love.graphics.newQuad(385, 186, 62, 62, spritesheet:getDimensions())
	Player.animations['explosion'].frameDuration = {0.07,0.07,0.07,0.07,0.1,0.1,5}
	Player.animations['explosion'].texture = spritesheet
	enemies.animations = {}
	enemies.animations['explosion'] = Player.animations['explosion']
	Player.width, Player.height = 53, 48
	Player.texture = spritesheet
	sfondo.img = love.graphics.newImage('res/images/grass.png')
	sfondo.spriteBatch = love.graphics.newSpriteBatch( sfondo.img, 1000 )
	bullets.texture = spritesheet
	bullets.img =  love.graphics.newQuad(0, 73, 53, 14, bullets.texture:getDimensions())
	bullets.imgPower = {}
	table.insert(bullets.imgPower, love.graphics.newQuad(0, 73, 51, 14, bullets.texture:getDimensions()))
	table.insert(bullets.imgPower, love.graphics.newQuad(66, 67, 51, 17, bullets.texture:getDimensions()))
	table.insert(bullets.imgPower, love.graphics.newQuad(0, 96, 51, 17, bullets.texture:getDimensions()))
	
	enemies.img = love.graphics.newQuad(54, 0, 54, 48, spritesheet:getDimensions())
	enemies.images = {}
	enemies.images[1] = enemies.img
	enemies.images[2] = love.graphics.newQuad(0, 116, 56, 51, spritesheet:getDimensions())
	enemies.images[3] = love.graphics.newQuad(0, 248, 40, 44, spritesheet:getDimensions())
	enemies.images[4] = love.graphics.newQuad(164, 0, 75, 67, spritesheet:getDimensions())
	enemies.width , enemies.height = 54,48
	enemies.texture = spritesheet
	enemyBullets.img = love.graphics.newImage('res/images/enemy_bullet.png')
	enemyBullets.spriteBatch = love.graphics.newSpriteBatch( enemyBullets.img, 1000 )
	
	
	
	powerups.texture = spritesheet
	powerups.imgWeaponSpeed = love.graphics.newQuad(3, 51, 11, 13, spritesheet:getDimensions())
	powerups.imgWeaponPower = love.graphics.newQuad(21, 51, 11, 13, spritesheet:getDimensions())
	powerups.width = 11
	powerups.height = 13
	
	powerups.spriteBatch = love.graphics.newSpriteBatch(powerups.texture,100)
end

local function loadGameSounds(arg)
	bullets.sound = love.audio.newSource("res/sound/explosion04.wav", "static")
	enemies.explosionSound = love.audio.newSource("res/sound/explosion07.wav", "static")
end

local function loadGameMusic(arg)
	music = love.audio.newSource ("res/music/bgm_action_3.mp3")
	music:setVolume(0.3)
	music:setLooping("true")
end


	
local function load(arg)
		if arg[#arg] == "-debug" then require("mobdebug").start() end
	
	game.engine.screen.width = WIDTH
	game.engine.screen.height = HEIGHT
	
	loadGameImages(arg)
	loadGameSounds(arg)
	loadGameMusic(arg)
	
	
	
	-- Set fullscreen mode
	love.window.setMode(love.graphics.getWidth(), love.graphics.getHeight(), {fullscreen= false})
	
	-- check for joysticks
	if love.joystick.getJoystickCount() > 0 then
		joysticks = love.joystick.getJoysticks( )
		--joystick = joysticks[1]
	end
	
	userinput.setupUserInput(joypadButtonMapping)
	
	--TODO changeme
	demomode = false
	if demomode == true then
		gameRecordFile = love.filesystem.newFile("CAGgamerecord.dat","r")
	end
	
	-- at game start, go to "start screen"
	startscreen.game = game
	startscreen.enter()
	
end

game.load = load
game.update = update
game.draw = draw

return game


