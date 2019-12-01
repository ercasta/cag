local startscreen = {}

userinput = require('userinput')

local function enter()
	startscreen.game.currentScreen = startscreen
	startscreen.game.currentScreen.startTime=totalVideoTime
	startscreen.engine = startscreen.game.engine
end

local function update(dt)

	--userinput.readUserInput(dt)
	
	--FIXME handle different keys
	if (love.keyboard.isDown('1') and credits > 0 ) then
		credits = credits - 1
		levelrunning.enter()
	end
end

local function draw(alpha)
	love.graphics.clear()
	
	-- colore bianco
	love.graphics.setColor(255, 255, 255)


	local screenTime = totalVideoTime - startscreen.startTime
	local engine = startscreen.engine
	local scrollTime = 1 --sec
	
	
	local logoFinalPos = 90
	local logoStartPos = -86
	local logoPos = logoStartPos + (logoFinalPos-logoStartPos)*(screenTime/scrollTime)
	
	if logoPos > logoFinalPos then
		logoPos = logoFinalPos
	end
	love.graphics.draw(logoImg, (engine.screen.width/2)-(logoImg:getWidth()/2), logoPos)
	
	
	if math.floor((totalVideoTime*1000)%2000) < 1600 then
		
		if (credits>0) then
			love.graphics.printf("PRESS START",0,engine.screen.height/2,engine.screen.width,"center") 
		else
			love.graphics.printf("INSERT COIN",0,engine.screen.height/2,engine.screen.width,"center") 
		end
	end
	
end

startscreen.enter = enter
startscreen.draw = draw
startscreen.update = update

return startscreen