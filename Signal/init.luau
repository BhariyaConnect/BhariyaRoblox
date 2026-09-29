--!strict
--!native
--!optimize 2


--[[ 
WHY:
- Pub-Sub functionality helps multiple functions or scripts to wait and get data at the same time.
	(https://en.wikipedia.org/wiki/Publish%E2%80%93subscribe_pattern)



NOTES:
- Based on New luau type solver
- Uses generics for IntelliSense and easy autofill
- Tiny module making the code easy to read by anyone
- Use variables and methods with Pascal naming scheme only, camel or snake cases are for internal work and should not be used unless you know exactly what you are doing
- Uses circular doubly linked list based approach to allow O(1) disconnects at abrupt indexes.
- All callers and waiters start as different threads at the same time (in order of their entrances), its upto the cpu scheduler to decide which one finishes first.
- All callbacks and waiters are wrapped in pcall adding error handling, so error in one call doesn't affect the others



UPDATES:
- 07-09-2026
	Minor changes and rearrangements for use in external editors
- 29-09-2026
	Fixed bug where the head connection disconnection
	Removed inter connection link nullifying on DisconnectAll, GC can clear connections as soon as they are dereferenced
]]


-- Depends on my Threads Module
-- Replace usage with task.spawn and task.defer if threads module is not desired
local Threads = require(script.Parent:WaitForChild("Threads"))


-- Connection type
export type Connection<T... = ...any> = {
	Connected: boolean,
	Disconnect: (self: Connection<T...>) -> (),
	_isOnce: boolean,
	_thread: thread?,
	_callback: ((T...) -> ())?,
	_previous: Connection<T...>|Signal<T...>|nil,
	_next: Connection<T...>|Signal<T...>|nil,
	__index: Connection<T...>
}


-- Signal type
export type Signal<T... = ...any> = {
	Fire: (self: Signal<T...>, T...) -> (),
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection<T...>,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection<T...>,
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
	_next: Connection<T...>?,
	_previous: Connection<T...>?,
	__index: Signal<T...>
}


-- Every callback and waiter is wrapped in a Connection object
local Connection = {} :: Connection
Connection.__index = Connection


-- Disconnects a connection so it doesn't receive any further fires
function Connection:Disconnect()


	-- Update the connection's Connected flag
	self.Connected = false


	-- If previous exist, set its next node to the current's next
	if self._previous then
		self._previous._next = self._next
	end


	-- If next exist, set its previous node to the current's previous
	if self._next then
		self._next._previous = self._previous
	end
end


-- Signal is the main object that listeners can attach callbacks to or wait for
local Signal = {} :: Signal
Signal.__index = Signal


-- Append a new connection to the signal
local function addNewConnection(signal: Signal, connection: Connection)


	connection.Connected = true


	-- Add connection to head if no head exist
	if not signal._next then
		signal._next = connection
		connection._previous = signal
	end


	-- If a tail exists, link that as self's previous
	if signal._previous then
		signal._previous._next = connection
		connection._previous = signal._previous
	end


	-- Set new connection as the new tail
	signal._previous = connection
	connection._next = signal
end


-- Attach a callback to the signal
function Signal:Connect(callback)


	-- Create a new connection
	-- False isOnce says the connection should stay until it's manually disconnected
	-- Save the provided callback to execute when a fire is received
	local connection = setmetatable({_callback = callback}, Connection) :: Connection


	-- Insert connection at the end of connection list
	addNewConnection(self, connection)


	-- Return the created connection
	return connection
end



function Signal:Once(callback)


	-- Create a new connection
	-- True isOnce says the connection should auto drop after it receives a fire
	-- Save the provided callback to execute when a fire is received
	local connection = setmetatable({_isOnce = true, _callback = callback}, Connection) :: Connection


	-- Insert connection at the end of connection list
	addNewConnection(self, connection)


	-- Return the created connection
	return connection
end


function Signal:Wait()


	-- Create a new connection
	-- True isOnce says the connection should auto drop after it receives a fire
	-- Save the current thread, for future resumption
	local connection = setmetatable({_isOnce=true, _thread = coroutine.running()}, Connection) :: Connection


	-- Insert connection at the end of connection list
	addNewConnection(self, connection)


	-- Yield the caller thread
	-- Fire will resume the thread with the parameters passed
	return coroutine.yield()
end


-- Fire values to the signal which in turn will be returned to the waiters and attached callbacks
function Signal:Fire(...)


	-- Fetch the first connection
	local connection = self._next


	-- Traverse the linked list
	while connection and connection ~= self do


		-- Store the next connection
		local nextConnection = connection._next


		-- If connection was a once type, disconnect from the linked list
		if connection._isOnce then
			connection:Disconnect()
		end


		-- If waiter is a yielded thread, execute it via task.spawn
		if connection._thread then
			pcall(task.spawn, connection._thread, ...)


		-- If waiter is a function, execute it via reusable threads
		elseif connection._callback then
			pcall(Threads.Spawn, connection._callback, ...)
		end


		-- Get the next connection
		connection = nextConnection
	end
end


-- Disconnect all connections from the signal
function Signal:DisconnectAll()


	-- Fetch the first connection
	local connection = self._next


	-- Nullify the first and last connection
	self._next = nil
	self._previous = nil


	-- Traverse the linked list and mark everyone as disconnected
	while connection and connection ~= self do
		connection.Connected = false
		connection = connection._next
	end
end


-- Create a new signal
return function<T...>() return setmetatable({}, Signal) :: Signal<T...> end