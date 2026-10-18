--!strict
--!native
--!optimize 2


--[[
Promise v1.0.0


WHY:
- To handle asynchronous operations, like fetching data from a server, without freezing the main thread
 	by providing a placeholder object for a value that will arrive in the future.
	(https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise)


NOTES:
- Promise has generic types so when using function autofill, it can help with variable names and types.
- Promise will keep its status and value even after competition (immutable after first change)
- AndThen and Catch(a wrapper over AndThen) will return a chained Promise
- AndThen and Catch will not provide resolve or reject callbacks,
	instead the return or errors thrown in the AndThen or Catch executor will be used as resolve or reject parameters for the chained promise,
	with the exception when no return or error is caused, in that case the parent's resolve or reject values are passed down.
- Deferred is a wrapper over Promise that provides the resolver and rejecter for external competition
- Deferred does not take or execute any function, user is supposed to run the function on their own


TESTS:
[PASSED] Checked for memory leaks
	Callbacks are cleared after promise ends, while values and status stay, they are open to GC cleanup as soon as promise gets dereferenced


UPDATES:
- 07-09-2026
	Minor changes and rearrangements for use in external editors
]]


-- Depends on my Thread Module
-- Replace usage with task.spawn and task.defer if thread module is not desired
local Thread = require(script.Parent:WaitForChild("Thread"))


-- Promise allows a function to execute and return a result in the future using yielding or callback based methods 
local Promise = {} :: Promise
Promise.__index = Promise


-- Promise type
export type Promise<ResolveT... = ...any, RejectT... = ...any> = {
	AndThen: (self: Promise<ResolveT..., RejectT...>, onResolve: ((ResolveT...) -> ())?, onReject: ((RejectT...) -> ())?) -> Promise<ResolveT..., RejectT...>,
	Catch: (self: Promise<ResolveT..., RejectT...>, onReject: (RejectT...) -> ()) -> Promise<ResolveT..., RejectT...>,
	Await: (self: Promise<ResolveT..., RejectT...>) -> (boolean, any),
	_result: {any},
	_waiters: {(boolean, ...any)->()},
	_completed: boolean,
	_success: boolean,
	__index: Promise<ResolveT..., RejectT...>
}


-- AndThen requires 2 callbacks, one for when the promise resolves and one optional for when it rejects
-- Returns a new chained promise
-- The chained promise can not have its own resolve and reject, instead the value(s) or error returned will act as the resolve and reject values
-- If no callbacks are provided for the chained promise, the parent's results will be reused as the chained promise's results
-- A chained promise might resolve even if its parent rejects, if callbacks return no errors
function Promise:AndThen(onResolve, onReject)


	-- Create and return the new chained promise
	return NewPromise(function(resolve, reject)


		-- Function to process current promise if parent gets rejected
		local function handleParentCompletion(successful: boolean, ...)


			-- Switch based on success
			local passedCallback = if successful then onResolve else onReject
			local chainCallback = if successful then resolve else reject


			-- If a onReject callback was not provided, reject with parent's reason thrown values
			if not passedCallback then
				return chainCallback(...)
			end


			-- Call onReject safely
			local result = {pcall(passedCallback, ...)}


			-- Parse the return values
			local success = table.remove(result, 1)
			result = table.unpack(result)


			-- Resolve or reject the chained promise based on onReject's return or thrown errors
			if success then
				resolve(result) else
				reject(result)
			end
		end


		-- If parent promise already completed, simply execute the new promise's resolve/reject, else add them to current promise's callback list
		if self._completed then
			Thread.Spawn(handleParentCompletion, self._success, table.unpack(self._result))
			return
		end


		table.insert(self._waiters, handleParentCompletion)
	end)
end


-- Catch is a wrapper over AndThen
-- Attaches a callback as the reject parameter of a promise
-- Gets executed ONLY AND ONLY if the promise gets rejected
-- Returns a new Promise as a chain just like AndThen
function Promise:Catch(onReject)
	return self:AndThen(nil, onReject)
end


-- Returns a boolean with a value if resolved or a reason if the promise was rejected
-- Yields the caller until the promise completes
function Promise:Await()


	-- If promise was already complete, simply return the already completed values with the success flag
	if self._completed then
		return self._success, table.unpack(self._result)
	end


	-- Fetch the current thread
	local currentThread = coroutine.running()


	-- Add the thread to the waiter list with a resume callback
	table.insert(self._waiters, function(success: boolean, ...) task.spawn(currentThread, success, ...) end)


	-- Yield the caller thread until promise completes
	return coroutine.yield()
end


-- Deferred is a wrapper over Promise that allows external competition signaling for the internal promise
local Deferred = {} :: Deferred
Deferred.__index = Deferred


-- Deferred type
export type Deferred<ResolveT... = (), RejectT... = ()> = {
	Promise: Promise<ResolveT..., RejectT...>,
	Resolve: (self: Deferred<ResolveT..., RejectT...>, ResolveT...) -> (),
	Reject: (self: Deferred<ResolveT..., RejectT...>, RejectT...) -> (),
	Reset: (self: Deferred<ResolveT..., RejectT...>) -> (),
	_resolver: (ResolveT...) -> (),
	_rejecter: (RejectT...) -> (),
	__index: Deferred<ResolveT..., RejectT...>
}


-- Resolve a deferred promise
function Deferred:Resolve(...)
	self._resolver(...)
end


-- Reject a deferred promise
function Deferred:Reject(...)
	self._rejecter(...)
end


-- Reset a deferred promise so it can be reused
function Deferred:Reset()
	self.Promise._completed = false
	self.Promise._success = false
end


-- Creates a new promise with a onResolve and onReject
-- The executor can resolve the promise using the resolve callback or reject the promise with either reject callback, or throwing an error in which case the error will be used as the result 
function NewPromise<ResolveT..., RejectT...>(executor: (resolve: (ResolveT...) -> (), reject: (RejectT...) -> ()) -> ())


	-- Create a fresh promise
	local promise = setmetatable({_waiters = {}}, Promise) :: Promise<ResolveT..., RejectT...>


	local function markCompleted(success: boolean, ...)


		-- Skip if promise was already resolved or rejected
		if promise._completed then
			return
		end


		-- Set the resolved status and values
		promise._completed = true
		promise._success = success
		promise._result = table.pack(...)


		-- Execute all callbacks in different threads
		for _, callback in promise._waiters do
			Thread.Spawn(callback, success, ...)
		end


		-- Dereference all callbacks
		table.clear(promise._waiters)
	end


	-- Run the executor in a new thread
	Thread.Spawn(function()


		-- Pcall is used for safe execution, so executor errors are caught and passed as rejected promise
		local success, reason = pcall(executor,
			function(...) markCompleted(true, ...) end,
			function(...) markCompleted(false, ...) end
		)


		-- If caller errors, simply reject the promise
		if not success then
			markCompleted(false, reason)
		end
	end)


	return promise
end


-- Creates a promise with the onReject and onResolve returned for external completion
-- Deferred has no way of executing a function, so any function that needs to execute should be run by the caller separately, and the defer's resolve and reject should be called by the caller
function NewDeferred<ResolveT..., RejectT...>()


	-- Create a deferred object that will store all the methods and the promise itself
	local deferred = setmetatable({}, Deferred) :: Deferred<ResolveT..., RejectT...>


	-- Create a fake promise that saves the signaling functions
	deferred.Promise = NewPromise(function(resolve, reject)
		deferred._resolver = resolve
		deferred._rejecter = reject
	end)


	return deferred
end


-- Return a table with the constructor functions 
return table.freeze({
	New = NewPromise,
	Deferred = NewDeferred
})
