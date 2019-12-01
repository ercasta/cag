ok = false

function love.load(arg)
	line l = "a#LEVELpippo"
	for x in l:gmatch("%a+#LEVEL%a+") do
		ok = true
	end
	

end

function love.update(dt)
end

function love.draw()
	love.graphics.clear()
	
	-- colore bianco
	love.graphics.setColor(255, 255, 255)

	if (ok) then
		love.graphics.printf("OK",0,200/2,WIDTH,"center") 
end
