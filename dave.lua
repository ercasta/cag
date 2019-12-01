local bump = require 'bump'
local math = require 'math'

userinput = require('userinput')

require('animation')
require('display')
require('touch')
require('core')


local dave = {}

local Game = {}

local TIMESTEP = 0.02

function Game:new(index)
	local p = {}   
	setmetatable(p, self)
	self.__index = self
	p.currentScreen = nil
	return p
end

function Game:update(dt)
	self.currentScreen.update(dt) --convert later to "object"
end

function Game:draw(alpha)
	self.currentScreen.draw(alpha) --convert later to "object"
end

local function newGame()
	g = Game:new()
	return g
end

-- Load the game at startup
local function load(game,arg)
	dave.timeStep = TIMESTEP
	dave.accumulator = 0
	dave.alpha = 0
	dave.screen = {width=0, height=0}
	dave.game = game
	dave.tick = 0
	game.engine = dave
	game:load(arg)
end



local function draw(alpha)
	-- Save global draw settings
	love.graphics.push()
	-- set desired draw mode
	setScreenZoomed(dave.screen)
	
	dave.game:draw(dave.alpha)
	
	-- Reset previous draw settings
	love.graphics.pop()
	love.graphics.setScissor()
end
	

local function readUserInput(dt)
	userinput.readUserInput(dt,joypadButtonMapping)
	
	if love.keyboard.isDown('escape') then
		if (demomode==false)  then
			userinput.writeTableStateToFile()
		end 
		love.event.push('quit')
	end
end

-- Update game model, with fixed timestep. Delegates to screen
local function update(dt)
	totalVideoTime = totalVideoTime + dt
	dave.tick = dave.tick + 1 
	
	readUserInput(dt)
	
	dave.accumulator = dave.accumulator + dt
	while dave.accumulator > dave.timeStep do
		dave.game:update(dave.timeStep)
		dave.accumulator = dave.accumulator - dave.timeStep
	end
	dave.alpha = dave.accumulator/dave.timeStep
end 

dave.load = load 
dave.update = update
dave.draw = draw
dave.newGame = newGame



return dave