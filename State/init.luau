--!strict
--!native
--!optimize 2


--[[
State v1.0.0


WHY:
- It's hard to keep track and update every dependent everytime the value changes,
	so it's better to have a callback for each dependent and let them update independently every time the "state" changes
	(https://react.dev/reference/react/useState)


NOTES:
- State has generic type, so autofill will be a great help
- Works somewhat similar to UseState in React.js where a change in the state causes a re-render
- Sends both new and old value to the listeners on every update
- Works even if new and old value are identical, so the listeners must be aware


TESTS:


UPDATES:
- 07-09-2026
	Minor changes and rearrangements for use in external editors
- 14-10-2026
	Major change, now sends old as well as new value to the listeners.
	Listeners now receive the fire even if new value is identical to old one
]]


-- Depends on my Signal Module
local Signal = require(script.Parent:WaitForChild("Signal"))


-- The actual State object
local State = {} :: State
State.__index = State


-- State type
export type State<T = any> = {
	Current: T,
	ChangeSignal: Signal.Signal<T, T>,
	LastModified: number,
	Update: (self: State<T>, newValue: T) -> (),
	
	__index: State<T>,
}


-- Instead of updating the value directly, this function should be used for updating the value
function State:Update(newValue)


	-- Save current time and new value
	local oldValue = self.Current
	self.Current = newValue
	self.LastModified = os.clock()


	-- Fire the signal with the old and new value so all listeners receive it
	self.ChangeSignal:Fire(oldValue, newValue)
end


-- Create a new State object
-- Initial value is required to set the type of the state
return function<T>(initial: T): State<T>


	-- Create the state object
	local state = setmetatable(
		{
			Current = initial,
			LastModified = os.clock(),
		}, State) :: State<T>


	-- Set other initial values
	state.ChangeSignal = Signal()


	return state
end