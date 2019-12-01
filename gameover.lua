game_over = {}

function game_over.enter(dt)
	game_over.game.currentScreen = game_over
	game_over.engine = game_over.game.engine
	game_over.elapsed = 0
end


function game_over.update(dt) 

	-- controlla se uscire dal gioco
	if love.keyboard.isDown('escape') then
		love.event.push('quit')
	end
	
	game_over.elapsed = game_over.elapsed + dt
	
	if game_over.elapsed > 3 then
		-- check if we have to go back to main screen
		if love.keyboard.isDown('r') then
			startscreen.enter()
		end
		
		-- controlla anche il joystick
		for k,joystick in ipairs(joysticks) do 
			for i=1,joystick:getButtonCount(),1 do
				if joystick:isDown(i) then
					startscreen.enter()
				end
			end
		end
		
		-- e il touch
		if touchPressed then
			startscreen.enter()
		end
	end 
end

function game_over.draw(alpha)
	local screen = game_over.engine.screen
	love.graphics.clear()
	
	love.graphics.setColor(255, 255, 255)

	for k,v in ipairs(players) do
		xOffset = 200 * (v.index-1)
		love.graphics.print("SCORE:" .. tostring(v.score), 0+xOffset*1.25, 0)
	end
	
	love.graphics.printf("GAME OVER",0,screen.height/2,screen.width,"center") 

end 