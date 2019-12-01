# Design


## Levels

Levels have a start phase, a run phase, and an end phase.

### Start Phase
During start phase, planes enter the scene, and a message appears in the center (Level X... Start!) for 5 seconds

### Run phase
After this, the run phase starts. Upon entering the run phase, the message disappears, planes enter fly mode, and enemies start spawning.

The run phase ends upon completion criteria (e.g. total run time). 

### Closing phase 
This phase completes when there are no more planes on the screen. During this phase, no more planes spawn

### End phase
During end phase, planes fly away from the screen, and level score is shown

## Waves

Enemies are spawn in waves. Each wave starts after a given amount of time after the previous one has finished. A wave has

* A lead time (time before it's spawn, after previous waves)
* A sequence of enemies to spawn, each with a given spawn time and individual characteristics


Spawning is defined by a Spawn Controller

The spawn controller is managed by a level controller


## Demo mode
To implement demo mode, determinism is needed. To get determinism, we use a fixed update loop timestep. Moreover, we record user input, together with initial random seed value. To save space, a user input entry is saved at every update loop only when input state changes. See `userinput` module. Random seed and user input are saved to a file named `CAGgamerecord.dat`

### UserInput structure
The userinput structure keeps track of user input, real or recorded, and random seed numbers.
The structure is:

```
	userinput = root
		joysticks = table of current user input, made of joystick entries
		history = table of entries
			tick = current time counter
			virtualJoysticks = table of entries 
				joystick entry = (2 axes, 4 buttons)
				
```

in demo mode, input is read using the `readUserInputFromFile` function in `userinput` module

## Explosions

Explosions appear when either the player plane, or enemy planes, are destroyed. Some enemies spawn multiple explosions.

### Single explosions

Single explosions are attached to enemy planes, and updated as part of enemy plane updates, but only for plane types 1 or 2 (which currently do not have custom controllers):

```
			elseif (v.state=="exploding") then
				v.explodingCountDown = v.explodingCountDown - dt
				for e,ee in pairs(v.explosions) do
					ee:update(dt)
				end
				if (v.explodingCountDown <= 0) then
					v.state="boom"
				end 
			end
```

Explosions attached to enemy planes are drawn as part of enemy plane drawing, except for planes of type 4:

```
if (v.state=="exploding" and v.enemyType ~= 4 ) then
			-- draw explosions
			for kk,explo in pairs(v.explosions) do
				local img = explo:getFrame(alpha)
				drawEnemyImage(ix,iy,v,explo.data.texture, img)
			end
		end
```
### Global Effects

Some explosions are managed as global effects, and updated in a dedicated function:

```
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

```

In this case, drawing too is managed as a separate function:

```
function drawEffects(objectList,alpha)
-- standard draw. TODO decide whether to use single spritebatch for all
	for k,v in ipairs(objectList) do
    v:draw(alpha)
	end
end
```