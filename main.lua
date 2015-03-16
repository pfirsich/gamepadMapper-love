identity = "MapperTest"
dbFilename = "custom_mappings.txt"

-- globals
border = 10
uiState = {}
states = {
	current = "chooseGamepad",
	chooseGamepad = {},
	viewGamepad = {},
	mapInput = {},
	setAll = {},
}
-- Important!:
-- having a, b, x, y first is a workaround for a bug in love 0.9.2 - https://bitbucket.org/rude/love/commits/1d5e31121fd6edc2ce6b34a64cad5e571ebb699d
virtualInput = {"a", "b", "x", "y", "leftx", "lefty", "rightx", "righty", "triggerleft", "triggerright",
				"back", "guide", "start", "leftstick", "rightstick", 
				"leftshoulder", "rightshoulder", "dpup", "dpdown", "dpleft", "dpright"}

function love.load()
	love.filesystem.setIdentity(identity)
	if love.filesystem.isFile(dbFilename) then love.joystick.loadGamepadMappings(dbFilename) end
	
	love.graphics.setFont(love.graphics.newFont(16))
	love.window.setTitle("Gamepad Mapper - " .. identity)
	love.window.setMode(1000, 600, {})
	
end

function love.draw()
	uiState.lastClick = uiState.click
	uiState.click = love.mouse.isDown("l")

	love.graphics.setColor(255, 255, 255, 255)
	local state = states[states.current]
	states[states.current].update(state, click, lastclick)
end

function button(text, yindex, cols, xindex)
	local buttonHeight = 35
	local mouseX, mouseY = love.mouse.getPosition()
	local w, h = (love.window.getWidth() - border * 2) / (cols or 1), buttonHeight
	local x, y = border + ((xindex or 1) - 1) * w, (border + buttonHeight) * yindex
	local ret = nil
	
	if mouseX >= x and mouseX <= x + w and mouseY >= y and mouseY <= y + h then
		love.graphics.setColor(180, 180, 255, 255)
		if uiState.click and not uiState.lastClick then ret = true end
	else
		love.graphics.setColor(255, 255, 255, 255)
	end
	
	love.graphics.rectangle("line", x, y, w, h)
	love.graphics.print(text, x + border, y + buttonHeight/2 - love.graphics.getFont():getHeight() / 2)
	
	return ret
end

function changeState(state, ...)
	states.current = state
	if states[state].enter then states[state].enter(states[state], ...) end
end

function states.chooseGamepad.update(state)
	love.graphics.print("Choose a gamepad to adjust mappings for", border, border)
		
	for i, joystick in ipairs(love.joystick.getJoysticks()) do
		if button(joystick:getName(), i) then 
			changeState("viewGamepad", joystick)
		end
	end
end

function states.viewGamepad.enter(state, chosenGamepad)
	if chosenGamepad then state.chosenGamepad = chosenGamepad end
	state.saveState = ""
end

function states.viewGamepad.update(state)
	love.graphics.print(state.chosenGamepad:getName() .. " - GUID: " .. state.chosenGamepad:getGUID(), border, border)
		
	if button("Back", 1) then changeState("chooseGamepad") end
	if button("Save Changes" .. (state.saveState or ""), 2) then love.joystick.saveGamepadMappings(dbFilename); state.saveState = " - Saved" end
	if button("Set all", 4) then changeState("setAll", state.chosenGamepad, true) end
	
	for i, v in pairs(virtualInput) do
		local inputType, inputIndex, hatDir = state.chosenGamepad:getGamepadMapping(v)
		local cols = 3
		local xindex = (i - 1) % cols + 1
		local yindex = 6 + math.floor((i - 1) / cols) 
		local str = v .. ": " .. ((inputType == nil or inputIndex == nil) and "none" or 
								inputType .. ", " .. tostring(inputIndex) .. (hatDir and ", " .. hatDir or ""))
		if button(str, yindex, cols, xindex) then
			changeState("mapInput", "viewGamepad", state.chosenGamepad, v)
		end
	end
end

function states.mapInput.enter(state, returnState, chosenGamepad, chosenInput)
	state.acceptInput = false
	state.returnState = returnState
	state.chosenGamepad = chosenGamepad
	state.chosenInput = chosenInput
end

function states.mapInput.update(state)
	love.graphics.print("Set input '" .. state.chosenInput .. "' - " .. state.chosenGamepad:getName(), border, border)
	love.graphics.print("Waiting for input... (Press buttons or push axis into positive direction)", border, border + 30)
	love.graphics.print("Press ESC to abort/skip.", border, border + 60)
	
	local inputType, inputIndex, hatDir = getInput(state.chosenGamepad)
	if inputType == nil then
		state.acceptInput = true
	else
		if state.acceptInput then
			love.joystick.setGamepadMapping(state.chosenGamepad:getGUID(), state.chosenInput, inputType, inputIndex, hatDir)
			changeState(state.returnState)
		end
	end
	
	local lastEsc = state.escKey
	state.escKey = love.keyboard.isDown("escape")
	if state.escKey and not lastEsc then
		changeState(state.returnState)
	end
end

function states.setAll.enter(state, chosenGamepad, start)
	if start then state.currentInputIndex = 0 end
	if chosenGamepad then state.chosenGamepad = chosenGamepad end
end

function states.setAll.update(state)
	state.currentInputIndex = state.currentInputIndex + 1
	if state.currentInputIndex > #virtualInput then
		changeState("viewGamepad")
	else
		changeState("mapInput", "setAll", state.chosenGamepad, virtualInput[state.currentInputIndex])
	end
end

function getInput(joystick)
	for button = 1, joystick:getButtonCount() do
		if joystick:isDown(button) then 
			return "button", button
		end
	end
	
	for axis = 1, joystick:getAxisCount() do
		if joystick:getAxis(axis) > 0.6 then
			return "axis", axis
		end
	end
	
	for hat = 1, joystick:getHatCount() do
		if joystick:getHat(hat) ~= "c" then
			return "hat", hat, joystick:getHat(hat)
		end
	end
end