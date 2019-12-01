require('dave')
--load the actual game
game = require('cag')


-- Draw bg and sprites. Call the right update function based on screen
function love.draw()
	dave.draw()
end

function love.update(dt)
	dave.update(dt)
end

-- Load the game at startup
function love.load(arg)
	dave.load(game,arg)
end


