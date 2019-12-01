local animation = {}

-- Animations represent predefined sequence of images. They can be used instead of a static image to draw an entity
-- are represented with animationData structures:
-- animationData.images = {}
-- animationData.images = {}
-- animationData.texture = texture
-- animationData.images[1] = love.graphics.newQuad(1, 186, 62, 62, spritesheet:getDimensions())
-- animationData.images[2] = love.graphics.newQuad(65, 186, 62, 62, spritesheet:getDimensions())
-- animationData.images[3] = love.graphics.newQuad(129, 186, 62, 62, spritesheet:getDimensions())
-- animationData.images[4] = love.graphics.newQuad(193, 186, 62, 62, spritesheet:getDimensions())
-- animationData.images[5] = love.graphics.newQuad(257, 186, 62, 62, spritesheet:getDimensions())
-- animationData.images[6] = love.graphics.newQuad(321, 186, 62, 62, spritesheet:getDimensions())
-- animationData.images[7] = love.graphics.newQuad(385, 186, 62, 62, spritesheet:getDimensions())
-- animationData.frameDuration = {0.07,0.07,0.07,0.07,0.1,0.1,5}
-- 
-- animationData can be shared between different objects
-- Every time an animation is used, an animation structure must be created
-- animation = {}
-- animation.animTime = 0 -- time since animation started
-- animation.animationAccrued = 0 -- time accumulated
-- animation.animationIndex = 1 -- current image index in animation data
-- animation.data = animationData

local Animation = {}


function Animation:forData(animData)
	local ps = {}
	setmetatable(ps, self)
	self.__index = self
	ps.data = animData
	ps.animTime = 0 -- time since animation started
	ps.animationAccrued = 0 -- time accumulated
	ps.animationIndex = 1 -- current image index in animation data
	return ps
end

function Animation:update(dt)
	self.animTime = self.animTime + dt
end

function Animation:isFinished()
  local anim = self
  local totalTime = 0
  for k,v in ipairs(anim.data.frameDuration) do
        totalTime = totalTime + v
  end
  return anim.animTime >= totalTime
end

function Animation:getFrame(alpha)
	--Alpha value represents time for interpolation. This can be used to calculate the correct frame and avoid irregular animations.
	local anim = self
	local curTime = anim.animTime + alpha * TIMESTEP
	local animData = anim.data
	while ( (curTime > anim.animationAccrued + animData.frameDuration[anim.animationIndex]) and anim.animationIndex < #animData.frameDuration) do
		-- go to next frame, if there is one 
		-- TODO support looping
		anim.animationAccrued = anim.animationAccrued + animData.frameDuration[anim.animationIndex]
		anim.animationIndex = anim.animationIndex + 1
	end
	local img = animData.images[anim.animationIndex]
	return img
end

animation.Animation = Animation

return animation