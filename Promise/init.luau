--!strict
--!native
--!optimize 2


--[[
Promise v2.0.0


WHY:
- To handle asynchronous operations, like fetching data from a server, without freezing the main thread
 	by providing a placeholder object for a value that will arrive in the future.
	(https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise)


NOTES:
- Promise has generic types so when using function autofill, it can help with variable names and types.
	Deferred general types does not auto infer but IntelliSense helps if types are manually mentioned.
- Promise will keep its status and value even after competition (immutable after first change)
	Resetting a promise or deferred keeps its previous waiters still waiting (if any) and lets the promise resolve or reject again
- Deferred is a wrapper over Promise that provides the resolver and rejecter for external competition
- Deferred does not take or execute any function, user is supposed to run any task they want to, on their own


TESTS:
[PASSED] Checked for memory leaks
	Callbacks are cleared after promise ends, while values and status stay, they are open to GC cleanup as soon as promise gets dereferenced


UPDATES:
- 07-09-2026
	Minor changes and rearrangements for use in external editors
- 21-11-2026
	Ditched setmetatable and now used simple tables, this way doesn't expose internal variables
	Changed promise to resolve or reject to a single value instead of a tuple
	Await, AndThen and Catch are not field based functions instead of earlier method calls,
		i.e. they are now invoked using (.) instead of (:)
	Promise now has reset option
]]


local Thread = require(script.Parent:WaitForChild("Thread"))


-- Promise type
export type Promise<ResT=any, RejT=any> = {
	AndThen: (onResolve: ((ResT) -> ())?, onReject: ((RejT) -> ())?) -> (),
	Catch: (onReject: (RejT) -> ()) -> (),
	Await: () -> (boolean, ResT & RejT),
	Reset: () -> (),
}

-- Deferred type
export type Deferred<ResT, RejT> = {
	Promise: Promise<ResT, RejT>,
	Resolve: (ResT) -> (),
	Reject: (RejT) -> (),
	Reset: () -> (),
}


-- Creates a new promise with an executor as parameter
-- The executor can resolve the promise using the resolve callback or reject the promise with either reject callback, or throwing an error in which case the error will be used as the result
-- NOTE: Executor function must not complete before its resolver or rejecter is called, in that case promise will be instantly resolved with the result "Promise executor completed without calling resolve or reject"
-- To avoid this case (if the resolve or reject call is in a new thread) wait for the thread to end at the end of the executor function
local function CreatePromise<ResT, RejT>(executor: (resolve: (ResT) -> (), reject: (RejT) -> ()) -> ()): Promise<ResT, RejT>


-- Completion states containing result and waiters and completed flag
	local succeeded: boolean? = nil
	local waiters: {(boolean, ResT|RejT)->()} = {}
	local completionResult: ResT|RejT


	-- Function responsible for completing the promise
	local function markComplete(s: boolean, r: ResT|RejT)


		--If the promise has already resolved or rejected, ignore further attempts to resolve or reject it
		if succeeded ~= nil then return end


		-- Set the new state
		succeeded = s
		completionResult = r


		-- Spawn all waiting threads and clear the table
		for _, callback in waiters do Thread.Spawn(callback, s, r) end
		table.clear(waiters)
	end


	-- Start the executor function in a new thread (automatically safe, but it absorbs all errors)
	Thread.Spawn(function()


		-- Start the executor function in a pcall to retrieve errors
		local success, reason = pcall(executor,
			function(r: ResT|RejT) markComplete(true, r) end,
			function(r: ResT|RejT) markComplete(false, r) end
		)


		-- In case promise did not have a resolving or rejecting call, automatically
		markComplete(success, reason or "Promise executor completed without calling resolve or reject")
	end)


	-- AndThen attaches 2 optional callbacks that are called when the promise resolves or rejects respectively
	-- Unlike JavaScript promises, AndThen does not return a chained promise
	local function AndThen(onResolve: ((ResT)->())?, onReject: ((RejT)->())?)


		-- Function that checks for passed functions and executes based on success
		local function onComplete(successful: boolean, res: ResT|RejT)
			if successful == true then
				if onResolve ~= nil then onResolve(res :: ResT) end
			else
				if onReject ~= nil then onReject(res :: RejT) end
			end
		end


		-- If promise has already complete, execute directly else add to waiters
		if succeeded == nil then table.insert(waiters, onComplete)
		else onComplete(succeeded, completionResult)
		end
	end


	-- Catch, similar to AndThen takes only one function (onReject) as argument
	-- Unlike JavaScript promises, Catch does not return a chained promise
	local function Catch(onReject: (RejT)->())
		AndThen(nil, onReject)
	end


	-- Await returns the success and result if promise is already complete
	-- else halts current thread till the promise completes and then returns the success and result
	local function Await(): (boolean, ResT|RejT)


		-- Return if promise already completed
		if succeeded ~= nil then return succeeded, completionResult end


		-- Collect current thread (coroutine)
		local currentThread = coroutine.running()


		-- Insert a callback that resumes current thread with the success and result
		table.insert(waiters,
			function(s: boolean, r:ResT|RejT)
				task.spawn(currentThread, s, r)
			end)


		-- Yield the current thread
		return coroutine.yield()
	end


	local function Reset()
		succeeded = nil
	end


	-- Return the methods
	return {AndThen = AndThen, Catch = Catch, Await = Await, Reset = Reset}
end


-- Dummy promise object that allows resolving and rejecting externally
local function CreateDeferred<ResT, RejT>(): Deferred<ResT, RejT>


	-- Store the resolver and rejecter
	local resolver: (ResT)->()
	local rejecter: (RejT)->()


	-- Dummy promise
	local promise = CreatePromise(function(resolve: (ResT)->(), reject: (RejT)->())
		resolver = resolve
		rejecter = reject
	end)


	-- Return the methods
	return {Promise = promise, Resolve = resolver, Reject = rejecter, Reset = promise.Reset}
end


-- Takes a function and its parameter and returns a promise that resolves with the function's return or rejects with any error caused
local function Promisify<ParaT, ResT>(func: (ParaT)->ResT, parameter: ParaT)


	-- Defer is used instead of a promise because of luau's type inference issues
	local deferred = CreateDeferred() :: Deferred<ResT, any>


	-- Execute function in a new thread and resolve or reject accordingly
	Thread.Spawn(function()
		local success, result = pcall(func, parameter)
		if success then deferred.Resolve(result)
		else deferred.Reject(result)
		end
	end)


	-- Return the deferred promise
	return deferred.Promise
end


-- Takes an iterable of promises as input and returns a single Promise. This returned promise fulfills when all of the input's promises fulfill
local function All(iterable: {Promise})
	return CreatePromise(function(resolve: (any)->(), reject)


		-- Pre count the number of promises passed
		local count = #iterable


		-- If empty iterable, resolve with empty list immediately
		if count == 0 then
			resolve({})
			return
		end


		-- Create result table and count completed
		local results = table.create(count)
		local completed = 0


		-- For each promise passed, save the result in correct order of receiving
		for index, promise in iterable do
			promise.AndThen(function(value)
				results[index] = value
				completed += 1


				-- If all completed, resolve with the final results list
				if completed == count then resolve(results) end
			end, function(reason)


				-- If any promise rejects, reject entirely
				reject(reason)
			end)
		end
	end)
end


-- Takes an iterable of promises as input and returns a single Promise. This returned promise fulfills when all of the input's promises settle
local function AllSettled(iterable: {Promise})
	return CreatePromise(function(resolve:({{success: boolean, value: any} | {success: boolean, reason: any}})->())


		-- Pre count the number of promises passed
		local count = #iterable


		-- If empty iterable, resolve with empty list immediately
		if count == 0 then
			resolve({})
			return
		end


		-- Create result table and count completed
		local results = table.create(count) :: {{success: boolean, value: any} | {success: boolean, reason: any}}
		local completed = 0


		-- For each promise passed, save the result and reason in correct order of receiving and resolve when all promises are complete
		for index, promise in iterable do
			promise.AndThen(function(value)
				results[index] = {success = true, value = value}
				completed += 1
				if completed == count then resolve(results) end
			end, function(reason)
				results[index] = {success = false, reason = reason}
				completed += 1
				if completed == count then resolve(results) end
			end)
		end
	end)
end


-- Takes an iterable of promises as input and returns a single Promise. This returned promise settles with the eventual state of the first promise that settles.
local function Race(iterable: {Promise})
	return CreatePromise(function(resolve: (any) -> (), reject: (any) -> ())
		for _, promise in iterable do
			promise.AndThen(resolve, reject)
		end
	end)
end


-- Takes an iterable of promises as input and returns a single Promise. This returned promise fulfills when any of the input's promises fulfills, with this first fulfillment value. It rejects when all of the input's promises reject
local function Any(iterable: {Promise})
	return CreatePromise(function(resolve, reject: ({any})->())


		-- Pre count the number of promises passed
		local count = #iterable
		if count == 0 then
			reject({})
			return
		end


		-- Store errors in case everyone rejects
		local errors = table.create(count)
		local rejected = 0


		-- For each promise passed, save the reason in correct order of receiving and reject when all promises are complete or resolve on first promise fulfill
		for index, promise in iterable do
			promise.AndThen(resolve, function(reason)
				errors[index] = reason
				rejected += 1


				-- If everyone rejected, reject the entire promise with al the errors
				if rejected == count then reject(errors) end
			end)
		end
	end)
end


-- Return all promise constructor methods
return table.freeze({
	Promise = CreatePromise,
	Deferred = CreateDeferred,
	Promisify = Promisify,
	All = All,
	AllSettled = AllSettled,
	Race = Race,
	Any = Any
})
