local core = {}

GameObject = {}

function GameObject:new()
	local ps = {}
	setmetatable(ps, self)
	self.__index = self
	self.remove = false -- true = cull from world
	self.x = 0
	self.y = 0
	self.prevCoord = {x=0, y=0}
	self.width = 0
	self.height = 0
	self.direction = 0
	self.vel = 0
	self.controller = nil
	self.renderer = nil
	return ps
end


function GameObject:update(dt)
	self.controller:update(dt)
end

function GameObject:draw(alpha)
	if (self.renderer~= nil) then
		self.renderer:draw(alpha)
	end
end

core.GameObject = GameObject

return core 