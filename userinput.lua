local userinput = {}


-- This is a structure representing virtual user input. Virtual user input is needed to manage input in demo and record mode
userinput = {}
userinput.keyboard = {}
userinput.touch = {}
userinput.joysticks = {}

userinput.history = {}


local function copyPreviousState(virtualJoystick) 
	local copiedState = {}
	copiedState.axes = {}
	copiedState.buttons = {}
	for i=1,2 do
		copiedState.axes[i] = virtualJoystick.axes[i]
	end 
	for command,value in pairs(virtualJoystick.buttons) do
		copiedState.buttons[command] = value
	end 
	return copiedState
end

local function copyRecordedStateToCurrent(recordedState,currentState) 
	for i=1,2 do
		currentState.axes[i] = recordedState.axes[i]
	end 
	for command,value in pairs(recordedState.buttons) do
		currentState.buttons[command] = value
	end 
end

local function createJoystickState(singleJoypadButtonMapping) 
	local copiedState = {}
	copiedState.axes = {}
	copiedState.buttons = {}
	for i=1,2 do
		copiedState.axes[i] = 0
	end 
	for command, button in pairs(singleJoypadButtonMapping) do
		copiedState.buttons[command] = 0
	end 
	return copiedState
end

local function checkChanged(oldState,newState)
	local dirty = false
	for i=1,2 do
		if oldState.axes[i] ~= newState.axes[i] then
			dirty = true
		end 
	end 
	for command,value in pairs(newState.buttons) do
		if oldState.buttons[command] ~= value then
			dirty = true
		end 
	end 
	return dirty
end  

local function initNumJoysticks(numJoysticks,joypadButtonMapping)
	for k = 1,numJoysticks do
		local virtualJoystick = {}
		virtualJoystick.axes = {}
		virtualJoystick.buttons = {}
		virtualJoystick.axes[1] = 0
		virtualJoystick.axes[2] = 0
		for command,i in joypadButtonMapping[k] do
			virtualJoystick.buttons[command] = 0
		end
		userinput.joysticks[k]=virtualJoystick
	end
end

-- Write logged input
local function writeTableStateToFile(destfileparam)
	local destfile = destfileparam or "CAGgamerecord.dat"
	gameRecordFile = love.filesystem.newFile(destfile,"w")
	gameRecordFile:write(tostring(userinput.seedLow) .. "," .. tostring(userinput.seedHigh))
	gameRecordFile:write("\n")
	for k,v in ipairs(userinput.history) do
		gameRecordFile:write(tostring(v.tick) .. "," )
		for l,js in ipairs(v.virtualJoysticks) do
			gameRecordFile:write(tostring(js.axes[1]) .. ",")
			gameRecordFile:write(tostring(js.axes[2]) .. ",")
			gameRecordFile:write(tostring(js.buttons[1]) .. ",")
			gameRecordFile:write(tostring(js.buttons[2]) .. ",")
			gameRecordFile:write(tostring(js.buttons[3]) .. ",")
			gameRecordFile:write(tostring(js.buttons[4]) .. ",")
		end
		gameRecordFile:write("\n")
	end
	gameRecordFile:close()
end 


local function readUserInputFromFile(joypadButtonMapping)
	
	--initNumJoysticks(2)
	-- TODO sanitize input
	local i = 1
	for line in gameRecordFile:lines() do
		if (i==1) then
		-- first line, random seed values
			local seedType = 1 
			for substring in string.gmatch(line, "%d+") do
				if (seedType == 1) then
					--low Seed
					userinput.seedLow = tonumber(substring)
				else
					-- high Seed
					userinput.seedHigh = tonumber(substring)
				end 
				seedType = seedType + 1 
			end
		else
			-- joystick state info
			local inputStrings = {}
			for substring in string.gmatch(line, "[%-]?%d+") do
				table.insert(inputStrings,substring)
			end
			
			--following lines, inputs
			local h = {}
			table.insert(userinput.history, h)
			h.tick = tonumber(inputStrings[1])
			h.virtualJoysticks = {}
			table.insert(h.virtualJoysticks,createJoystickState(joypadButtonMapping[1]))
			numbuttons = #joypadButtonMapping
			local jj = h.virtualJoysticks[1]
			jj.axes[1] = tonumber(inputStrings[2])
			jj.axes[2] = tonumber(inputStrings[3])
			--TODO fixme buttons might not be ordered
			for buttonCommand,buttonNumber in pairs(joypadButtonMapping) do
				jj.buttons[buttonCommand] = tonumber(inputStrings[button+3])
			end
			if table.getn(inputStrings) > numbuttons+4 then 
				-- two joysticks
				table.insert(h.virtualJoystick,createJoystickState(joypadButtonMapping[2]))
				jj = h.virtualJoysticks[2]
				jj.axes[1] = tonumber(inputStrings[8])
				jj.axes[2] = tonumber(inputStrings[9])
				for buttonCommand,buttonNumber in pairs(joypadButtonMapping[2]) do
					jj.buttons[buttonCommand] = tonumber(inputStrings[button+9])
				end
			end 
			
		end
		i = i + 1
	end
	writeTableStateToFile("readFile")
end


local function readRecordedInputStatus(dt)

	
	while (userinput.currIndex <= table.getn(userinput.history) and userinput.history[userinput.currIndex].tick <= userinput.currTick) do
		local currState = userinput.history[userinput.currIndex]
		for k,v in ipairs(currState.virtualJoysticks) do
			copyRecordedStateToCurrent(v,userinput.joysticks[k])
		end
		userinput.currIndex = userinput.currIndex + 1
	end
	userinput.currTick = userinput.currTick + 1
	
end

local function readRealUserInput(dt,joypadButtonMapping)
	-- read from actual input
	local js = joysticks
	local dirty = false
	for k,v in ipairs(js) do
		
		local virtualJoystick = userinput.joysticks[k]
		local oldState = copyPreviousState(virtualJoystick)
		
		if (v:isGamepadDown("dpup") or v:getAxis(2)<-JOYSTICK_THRESHOLD or love.keyboard.isDown(keyboardControls[k].up)) then
			virtualJoystick.axes[2] = -1
		elseif (v:isGamepadDown("dpdown") or v:getAxis(2)>JOYSTICK_THRESHOLD or love.keyboard.isDown(keyboardControls[k].down)) then
			virtualJoystick.axes[2] = 1
		else
			virtualJoystick.axes[2] = 0
		end
		if (v:isGamepadDown("dpright") or v:getAxis(1)>JOYSTICK_THRESHOLD or love.keyboard.isDown(keyboardControls[k].right)) then
			virtualJoystick.axes[1] = 1
		elseif (v:isGamepadDown("dpleft") or v:getAxis(1)<-JOYSTICK_THRESHOLD or love.keyboard.isDown(keyboardControls[k].left)) then
			virtualJoystick.axes[1] = -1
		else
			virtualJoystick.axes[1] = 0
		end
		
		-- Use for test
		
		
		--reset all buttons to zero
		for command, button in pairs(joypadButtonMapping[k]) do
			virtualJoystick.buttons[command] = 0
		end
		for command,i in pairs(joypadButtonMapping[k]) do --only read configured buttons
			if (v:isDown(i) or ( i==1 and love.keyboard.isDown(keyboardControls[k].fire) ) or ( i==2 and love.keyboard.isDown(keyboardControls[k].spawn)) ) then
				virtualJoystick.buttons[command] = 1
			else 
				virtualJoystick.buttons[command] = 0
			end
		end
		
		
		dirty = dirty or checkChanged(oldState,virtualJoystick)
	end	
	
	
	if (dirty) then
		local h = {}
		table.insert(userinput.history, h)
		h.tick = tick
		h.virtualJoysticks = {}
		for k,v in ipairs(userinput.joysticks) do
			h.virtualJoysticks[k] = copyPreviousState(v)
		end
	end
end

-- Read all user input and save it in a data structure which is used by the update methods. This is needed for demo mode, where input is taken from a recorded file
local function readUserInput(dt,joypadButtonMapping)
	if demomode == true then 
		-- if demo mode is on, we will have to read input from recorded file
		readRecordedInputStatus(dt)
	else 
		readRealUserInput(dt,joypadButtonMapping)
	end 
	-- if record mode is on, we will have to save data
	-- TODO
end



local function setupUserInput(joypadButtonMapping)
	
	-- these are used for demo mode
	userinput.currTick = 1
	userinput.currIndex = 1
	
	-- setup base structure
	local js = joysticks
	for k,v in ipairs(js) do
		local virtualJoystick = {}
		virtualJoystick.axes = {}
		virtualJoystick.buttons = {}
		virtualJoystick.axes[1] = 0
		virtualJoystick.axes[2] = 0
		for command,button in pairs(joypadButtonMapping[k]) do
			virtualJoystick.buttons[command] = 0
		end
		userinput.joysticks[k]=virtualJoystick
	end
		
	if (demomode==true) then
	-- if demo mode is on, we  have to read input and random seeds from recorded file, 
		readUserInputFromFile()
		love.math.setRandomSeed(userinput.seedLow, userinput.seedHigh)
	else 
	-- if record mode or normal mode is on, we init random
		--love.math.random()
		userinput.seedLow, userinput.seedHigh = love.math.getRandomSeed( )
	end
end

userinput.setupUserInput = setupUserInput 
userinput.readUserInput = readUserInput
userinput.writeTableStateToFile = writeTableStateToFile

return userinput
