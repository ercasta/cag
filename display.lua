
function setScreenZoomed(screen)
	
	local scalaY = love.graphics.getHeight()/screen.height
	local tx = (love.graphics.getWidth() - screen.width*scalaY)/2
	love.graphics.translate(tx, 0)
	love.graphics.scale(scalaY, scalaY)
	love.graphics.setScissor(tx, 0, screen.width*scalaY, love.graphics.getHeight())
	
end