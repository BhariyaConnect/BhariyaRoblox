--!strict
--!native
--!optimize 2


--[[
WHY:
- Threads are expensive to create but cheaper to store in memory
- Reduce CPU load caused by new thread creation


NOTES:
- The last thread is always removed from the pool reducing the number of ops
- Only allows functions to be run, externally created threads cant be used


TESTS:
[PASSED] Checked equivalence with task functions


UPDATES:
- 06-09-2026
	Minor changes and rearrangements for use in external editors
	Make the function call safe using pcall
- 11-10-2026
	Added generic types to methods
]]


-- Pool of idle threads
local _pool: {thread} = {}


-- Execute the function with the parameters passed and return the thread back to pool
local function executeAndSave(func, ...)
	pcall(func, ...)
	table.insert(_pool, coroutine.running())
end


-- Return a never ending infinite yielding thread that expects a function and its parameters when resumed
local function infiniteThread()
	while true do
		executeAndSave(coroutine.yield())
	end
end


-- Spawn a new thread that runs the infinite function
local function createThread()
	return task.spawn(infiniteThread)
end


-- Fetch an old thread from the pool or create a new one
local function fetchThread()
	return table.remove(_pool) or createThread()
end


-- Threads is a constructor that offers methods to create new threads
local Threads = {}


-- Run a function immediately
function Threads.Spawn<T...>(func: (T...)->(), ...: T...)
	return task.spawn(fetchThread(), func, ...)
end


-- Run a function after current frame
function Threads.Defer<T...>(func: (T...)->(), ...: T...)
	return task.defer(fetchThread(), func, ...)
end


-- Run a delayed function
function Threads.Delay<T...>(duration: number, func: (T...)->(), ...: T...)
	return task.delay(duration, fetchThread(), func, ...)
end


-- Return the table
return table.freeze(Threads)