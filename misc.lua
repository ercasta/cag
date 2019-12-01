

function interpolateCoords(newX,newY,oldX,oldY,alpha)
	local ix, iy = oldX + alpha * (newX-oldX), oldY + alpha * (newY-oldY)
	return ix, iy
end

function love.touchmoved( id, x, y, dx, dy, pressure )
	if dy > 20 then
		players[1].spawn=true
	end
end


function getCameraCoords(x,y)
	-- y axis is flipped
	return  camera.ox - camera.x + x , camera.height + camera.oy - (y - camera.y)
end
