--!strict
--!native
--!optimize 2

--[[
DataVault v0.3.0

]]


local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")


local FetchVaultsHolder = require(script:WaitForChild('VaultsHolder'))
local Signal = require(script.Parent:WaitForChild('Signal'))
local State = require(script.Parent:WaitForChild('State'))
local Thread = require(script.Parent:WaitForChild('Thread'))
local Types = require(script:WaitForChild('Types'))
local Utils = require(script:WaitForChild('Utils'))
local Constants = require(script:WaitForChild("Constants"))


local Vault = {} :: Types.Vault
Vault.__index = Vault


local VaultsCount = State(0)
local ServerShuttingDown = State(false)
local MemoryStoreWorking = State(true)
local DataStoreWorking = State(true)
const ServerSession = HttpService:GenerateGUID(false)


game:BindToClose(function()
	ServerShuttingDown:Update(true)
	while VaultsCount.Current ~= 0 do VaultsCount.ChangeSignal:Wait() end
end)


local function GetVault<DataT>(dsName: string, vaultName: string, hidden:boolean, template: DataT): Types.Vault<DataT>


	local VaultOpentime = DateTime.now().UnixTimestampMillis


	-- Fetch VaultsHolder
	local vaultHolder = FetchVaultsHolder(dsName)


	-- If vault already in server, return it blindly
	local oldVault: Types.Vault<DataT> = vaultHolder.Vaults[vaultName]
	if oldVault ~= nil then
		-- If vault is opened in Visible mode, convert old vault to visible
		if not hidden then oldVault.Hidden = hidden end
		return oldVault
	end


	-- Else create a new vault
	local vault = {Hidden=hidden} :: Types.Vault<DataT>
	vaultHolder.Vaults[vaultName] = vault
	VaultsCount:Update(VaultsCount.Current + 1)


	-- Vault parameters scoped to the function
	local VaultSession = HttpService:GenerateGUID(false) -- Unique ID to find and track the vault session (will be used by other servers to talk to current server)
	local VaultUsable = State(false) -- Vault starts with being unusable
	local VaultState = State(Constants.VaultState.CREATED) -- Initial state of the vault is CREATED
	local LockData: Types.LockData = {VaultSession = VaultSession, ServerSession = ServerSession, LockedAt = 0} -- Dummy lock value
	local DSData: Types.DataStoreData = {
		__PUBLIC={},
		__ACTIVITY={
			FirstLogIn = 0,
			LastLogIn = 0,
			LastLogOut = 0,
		}
	} -- Dummy DS data
	local NextReaderId = 0 -- Each reader gets its own ID
	local ActiveReaders: {number} = {} -- ALl the active readers
	local DataUpdatedSignal:Signal.Signal<{string|number}, any> = Signal() -- Fired when any data field changes
	--local VaultPrivateStateChanging = State(false) -- Sets when vault is ongoing cleanup or stasis convertion or reviving
	local VaultPrivateState: "REVIVE"|"STASIS"|"CLEANUP" = "REVIVE" -- Saves vault's private state


	local AcquiresData = {
		Sent = {ServerSession="", VaultSession="", At=0},
		Received = {ServerSession="", VaultSession="", At=0}
	} -- Saves all acquire related actions


	local MessagingResponsesTimestamp = {
		AcquireAck = 0,
		Released = 0
	} -- Saves all Acquire response actions


	local ReadyStates = {
		Messaging = false,
		Lock = false,
		InitialData = false,
		DataChanges = false,
	} -- Saves the ready states of all services


	local Requirements = {
		DataSaveLoop = true,
		LockRenewLoop = true,
	} -- Saves all Requirements for the vault


	local OngoingActions = {
		PrivateState = State(false),
		MessagingChannel = State(false),
		LockChange = State(false),
		DataChange = State(false),
		LockRenewLoop = false,
		DataSaveLoop = false
	}


	local LastAchievedStates = {
		Stasis = 0,

	}


	local LastActionCompletions = {
		DataChange = 0,
		DataSave = 0,
		LockSave = 0
	}


	local MessagingChannel: RBXScriptConnection? -- Channel to be used for messaging
	local LockAcquireThread: thread? -- Thread waiting for acquire response


	vault.Name = vaultName
	vault.Usable = VaultUsable
	vault.DataUpdatedSignal = DataUpdatedSignal
	vault.Session = VaultSession
	vault.Server = ServerSession
	vault.Locals = {}


	function vault:GetPublicData() return DSData.__PUBLIC end
	function vault:GetActivityData() return DSData.__ACTIVITY end


	-- The function to update any field in the data
	-- This also signals all update listeners about the change
	function vault:UpdateData(keys, value)


		-- Starting point for finding the exact spot where data has to be changed
		local pointer:{[string|number]:any} = DSData.__PUBLIC


		-- Iterate through the keys and update the current pointer
		for i, key in keys do


			-- Reached the last key, place value somehow
			if i == #keys then


				-- OPTIMISATION: If value is different, only then set the has changes flag
				if value ~= pointer[key] then


					-- Flag the vault as data changes ready
					ReadyStates.DataChanges = true
					pointer[key] = value
				end
			else


				-- Create empty table if it doesn't exist
				pointer[key] = pointer[key] or {}


				-- Move the pointer to the next key
				pointer = pointer[key]
			end
		end


		-- Fire the signal for data update listeners
		DataUpdatedSignal:Fire(keys, value)
	end


	-- Release the lock or upgrade it to the newest acquirer
	local function UpgradeOrReleaseLockAsync()
		print("UpgradeOrReleaseLockAsync")


		-- While another thread is modifying lock, wait
		while OngoingActions.LockChange.Current do OngoingActions.LockChange.ChangeSignal:Wait() end


		-- If vault went back to revived state while waiting, ignore the release call
		if VaultPrivateState == "REVIVE" then return end


		-- Prevent other threads from modifying lock
		OngoingActions.LockChange:Update(true)


		-- Will keep time for any action
		local now: number
		print("Releasing/Upgrading lock now")


		-- Execute as pcall to prevent errors
		local success = pcall(vaultHolder.LockMemoryStore.UpdateAsync, vaultHolder.LockMemoryStore, vaultName,
			function(current: Types.LockData?): Types.LockData?


				-- Mark action start time
				now = DateTime.now().UnixTimestampMillis


				-- If lock exists and owner is exactly current server and vault
				if current ~= nil and current.ServerSession == ServerSession and current.VaultSession == VaultSession then


					-- Update with new lock with the acquirer's session
					print("Lock released to:", AcquiresData.Received.ServerSession, AcquiresData.Received.VaultSession)
					LockData.LockedAt = now
					LockData.ServerSession = AcquiresData.Received.ServerSession
					LockData.VaultSession = AcquiresData.Received.VaultSession
					return LockData


				else -- For a different owner, mark lock as released, discard any unsaved changes and cleanup the vault (MIGHT LOSE DATA but impossible unless services are down)


					print("Lock already stolen or missing")
					ReadyStates.DataChanges = false
					ReadyStates.Lock = false
					return nil
				end
			end, Constants.MemoryStoreLockExpiryDelay / 1000)


		-- Flag MemoryStore service as working
		MemoryStoreWorking:Update(success)


		-- Mark when released will be sent
		now = DateTime.now().UnixTimestampMillis


		-- If lock upgrade/release was successful, send the release message
		if success then
			print("Released lock")


			-- Lock was upgraded
			if LockData.VaultSession ~= "" then


				-- Send message to acquirer
				local message: Types.InterVaultMessage = {ServerSession=ServerSession, VaultSession=VaultSession, SentAt=now, Reason=Constants.InterVaultMessageReason.RELEASED}
				pcall(MessagingService.PublishAsync, MessagingService, LockData.ServerSession..LockData.VaultSession, message)
				print("Sent released message")
			end


			-- Unlock lock modifications
			OngoingActions.LockChange:Update(false)


		else -- Upgrade/release failed


			-- Wait and retry
			warn("[Retrying 3]", "MemoryStore.UpdateAsync (upgrade or release lock)")
			task.wait(3)


			-- Unlock lock modifications
			OngoingActions.LockChange:Update(false)


			-- If failed and last updated is recent then retry
			if now - LastActionCompletions.LockSave < Constants.MSLockStaleDelay then UpgradeOrReleaseLockAsync() end
		end
	end


	-- Save data into datastore with the option to force save which forcefully saves ignoring last updated and last saved values
	local function SaveDataAsync(forceSave: boolean)
		print("SaveDataAsync")


		-- While another thread is modifying the state of the data, wait
		while OngoingActions.DataChange.Current do OngoingActions.DataChange.ChangeSignal:Wait() end


		-- Action Start time
		local now = DateTime.now().UnixTimestampMillis


		-- If no unsaved changes after waiting, or last change was too recent and last save isn't too old, skip. But forceSave skips the time based skipping
		if not ReadyStates.InitialData or not ReadyStates.DataChanges or ((not forceSave and now - LastActionCompletions.DataSave < 5000 and now - LastActionCompletions.DataSave < Constants.DSSaveLoopDelay)) then return end


		-- Prevent other thread from modifying data
		OngoingActions.DataChange:Update(true)


		print("Save started now")
		-- Count attempts for logging failure rates
		local attempt = 1


		-- Continue till there are changes yet to be saved
		while ReadyStates.DataChanges and VaultState.Current ~= Constants.VaultState.RELEASED do


		-- Mark action start time
			now = DateTime.now().UnixTimestampMillis


			-- Flag available data changes as false
			ReadyStates.DataChanges = false


			-- SetAsync clones the last value pf the DSData, so further modification while it is saving acts as new changes
			local success, result = pcall(vaultHolder.VaultDataStore.SetAsync, vaultHolder.VaultDataStore, vaultName, DSData)


			-- Flag DataStore service as working or not
			DataStoreWorking:Update(success)


			-- If save failed, retry after delay
			if not success then


			-- Re-attach the unsaved changes flag
				ReadyStates.DataChanges = true
				warn("[Retrying 5] Attempt:", attempt, "DataStore.SetAsync", result)
				attempt += 1
				task.wait(5)
				continue
			end


			-- Flag last save
			LastActionCompletions.DataSave = now


			-- Allow other threads to take over the data
			OngoingActions.DataChange:Update(false)
		end
	end


	-- Closes Messaging for the vault
	local function CloseMessagingAsync()
		print("CloseMessaging")


		-- While another thread is modifying the state of the messaging, wait
		while OngoingActions.MessagingChannel.Current do OngoingActions.MessagingChannel.ChangeSignal:Wait() end


		-- If vault went back to revived state while waiting, ignore the release call
		if VaultPrivateState == "REVIVE" then return end


		-- Prevent other thread from modifying messaging
		OngoingActions.MessagingChannel:Update(true)


		print("Closing messaging now")


		-- If Messaging channel exists, disconnect it
		if MessagingChannel ~= nil then
			MessagingChannel:Disconnect()
			MessagingChannel = nil
			ReadyStates.Messaging = false
			print("Closed messaging")
		end


		-- Release the lock for messaging change
		OngoingActions.MessagingChannel:Update(false)
	end


	-- Cleanup the vault from memory, leaving it totally unusable
	-- It can not be recovered once cleaned up
	local function CleanupAsync()
		print("CleanupAsync")
		VaultPrivateState = "CLEANUP"
		LastAchievedStates.Cleanup = DateTime.now().UnixTimestampMillis


		-- Set new state for the vault
		VaultState:Update(Constants.VaultState.RELEASING)


		-- De-reference the vault instantly so future vault queries will not return this vault
		vaultHolder.Vaults[vaultName] = nil
		VaultUsable:Update(false)


		-- Reset all requirements
		Requirements.DataSaveLoop = false
		Requirements.LockRenewLoop = false


		-- Wait while another instance of Revive, Stasis or Cleanup is ongoing
		-- NOTE: Do not add a check after wait in this case as post cleanup the vault should be unusable and not revertible
		while OngoingActions.PrivateState.Current do OngoingActions.PrivateState.ChangeSignal:Wait() end
		print("Cleaning up")


		-- Save one final time
		if ReadyStates.InitialData and ReadyStates.DataChanges then SaveDataAsync(true) end


		-- Release the lock safely (upgrade if required)
		if ReadyStates.Lock then UpgradeOrReleaseLockAsync() end


		-- Close messaging channel
		if ReadyStates.Messaging then CloseMessagingAsync() end


		-- Set new state for the vault
		VaultState:Update(Constants.VaultState.RELEASED)


		-- Send forget to the server who received current session's acquire
		local message: Types.InterVaultMessage = {ServerSession=ServerSession, VaultSession=VaultSession, SentAt=DateTime.now().UnixTimestampMillis, Reason=Constants.InterVaultMessageReason.FORGET}
		pcall(MessagingService.PublishAsync, MessagingService, AcquiresData.Sent.ServerSession..AcquiresData.Sent.VaultSession, message)


		-- Cleanup if lock acquire was still waiting
		local thread = LockAcquireThread
		LockAcquireThread = nil
		if thread ~= nil and coroutine.status(thread) == "suspended" then task.spawn(thread, false) end


		-- Reduce the number of active vaults (used to delay server shutdown)
		VaultsCount:Update(VaultsCount.Current - 1)
	end


	-- Performs operations based on messages received from another session or server
	local function MessagingLogic(Message: {Data:Types.InterVaultMessage, Sent:number})
		print("Message received", Message.Data.ServerSession, Message.Data.VaultSession, Message.Data.Reason, Message.Data.Extra)



		if Message.Data.Reason == Constants.InterVaultMessageReason.ACQUIRE then


			-- Save the server session id to upgrade lock in the future
			AcquiresData.Received.VaultSession = Message.Data.VaultSession
			AcquiresData.Received.ServerSession = Message.Data.ServerSession
			AcquiresData.Received.At = Message.Data.SentAt


			-- If vault was already in stasis mode, upgrade directly
			if VaultPrivateState == "STASIS" then CleanupAsync() end


		elseif Message.Data.Reason == Constants.InterVaultMessageReason.FORGET then


			-- Remove the last known acquirer if the same server sent Forget
			if Message.Data.ServerSession == AcquiresData.Received.ServerSession and
				Message.Data.VaultSession == AcquiresData.Received.VaultSession
			then
				AcquiresData.Received.ServerSession = ""
				AcquiresData.Received.VaultSession = ""
				AcquiresData.Received.At = 0
			end


		elseif Message.Data.Reason == Constants.InterVaultMessageReason.ACQUIRE_OK then


			-- Acknowledgement received for acquire
			if Message.Data.ServerSession == AcquiresData.Received.ServerSession and
				Message.Data.VaultSession == AcquiresData.Received.VaultSession
			then
				MessagingResponsesTimestamp.AcquireAck = Message.Data.SentAt
			end


		elseif Message.Data.Reason == Constants.InterVaultMessageReason.RELEASED then


			-- Other server released or upgraded the lock
			if Message.Data.ServerSession == AcquiresData.Received.ServerSession and
				Message.Data.VaultSession == AcquiresData.Received.VaultSession
			then
				MessagingResponsesTimestamp.Released = Message.Data.SentAt


				-- Activate the lock acquire suspended thread
				local thread = LockAcquireThread
				LockAcquireThread = nil
				LockData.LockedAt = Message.Data.SentAt
				if thread ~= nil and coroutine.status(thread) == "suspended" then task.spawn(thread, true) end
			end
		end
	end


	-- Starts preparation of Messaging service for the vault (skips if it is already prepared)
	local function PrepareMessagingAsync()
		print("PrepareMessagingAsync")


		-- While another thread is modifying the state of the messaging, wait
		while OngoingActions.MessagingChannel.Current do OngoingActions.MessagingChannel.ChangeSignal:Wait() end


		-- If vault changed state while waiting, ignore the call
		if VaultPrivateState ~= "REVIVE" then return end


		-- Prevent other thread from modifying messaging
		OngoingActions.MessagingChannel:Update(true)


		print("Messaging preparing now")


		-- Update the vault state
		VaultState:Update(Constants.VaultState.MESSAGEPREPARING)


		-- Count attempts for logging failure rates
		local attempt = 1


		-- While messaging is unusable and required, try making it usable
		while VaultPrivateState == "REVIVE" and not ReadyStates.Messaging do


			-- Try subscribing to the session
			local success, result = pcall(MessagingService.SubscribeAsync, MessagingService, ServerSession..VaultSession, MessagingLogic)


			-- If subscribe failed, retry after a delay
			if not success then
				warn("[Retrying 2] Attempt:", attempt, "MessagingService.SubscribeAsync", result)
				attempt += 1
				task.wait(2)
				continue
			end


			print("Messaging prepared")
			MessagingChannel = result
			ReadyStates.Messaging = true
			break
		end


		-- Release the lock for messaging change
		OngoingActions.MessagingChannel:Update(false)
	end


	-- Acquire lock
	local function AcquireLockAsync()
		print("AcquireLockAsync")


		-- While another thread is modifying the state of the lock, wait
		while OngoingActions.LockChange.Current do OngoingActions.LockChange.ChangeSignal:Wait() end


		-- Prevent other thread from modifying lock
		OngoingActions.LockChange:Update(true)


		print("Acquiring lock")


		-- Update the vault state
		VaultState:Update(Constants.VaultState.LOCKING)


		-- Count attempts for logging failure rates
		local attempt = 1


		-- If lock is unacquired, and it is required, try to acquire it
		while VaultPrivateState == "REVIVE" and not ReadyStates.Lock do


			-- Remembers if a retry is required
			local acquireRequired = false
			local currentLock: Types.LockData


			-- Call Update in pcall to prevent errors breaking the loop
			local success, result = pcall(vaultHolder.LockMemoryStore.UpdateAsync, vaultHolder.LockMemoryStore, vaultName,
				function(current: Types.LockData?): Types.LockData?


					-- Mark function start time
					local now = DateTime.now().UnixTimestampMillis


					if current == nil or (current.ServerSession == "" and current.VaultSession == "") then


						-- Lock non-existent, instantly acquire it
						print("Non existent lock", current)
						LockData.LockedAt = now
						return LockData


					elseif current.ServerSession == ServerSession and current.VaultSession == VaultSession then


						-- Current session owns it
						print("Lock already owned")


						-- Lock is stale, renew it
						if current.LockedAt + Constants.MSLockStaleDelay < now then
							print("Renewing stale lock")
							LockData.LockedAt = now
							return LockData
						end


						-- Ignore update if lock is fresh
						LockData = current
						return nil
					else


						-- Owned by another server
						print("Other server owns lock", current.ServerSession, current.VaultSession)
						print("Me", ServerSession, VaultSession)


						-- Lock is stale, and did not receive any response for 5 acquires, assume server dead
						if (now - current.LockedAt) > Constants.MSLockStaleDelay and (AcquiresData.Sent.At - MessagingResponsesTimestamp.AcquireAck) >= Constants.MessagingExpectedDelay * 5 then


							print("Server didnt respond for last 35 seconds and lock is older than 101 seconds... Stealing lock")
							LockData.LockedAt = now
							return LockData
						end


						-- Mark retry required
						acquireRequired = true
						currentLock = current
						return nil
					end
				end, Constants.MemoryStoreLockExpiryDelay)


			-- Update Failed, retry
			if not success then
				warn("[Retrying 3] Attempt:", attempt, "MemoryStore.UpdateAsync", result)
				attempt += 1
				task.wait(3)
				continue
			end


			-- Flag MemoryStore service as working
			MemoryStoreWorking:Update(success)


			-- Needs to send acquire
			if acquireRequired then


				-- Mark process start
				local now = DateTime.now().UnixTimestampMillis


				-- Acquire was never sent
				-- or Response is older than recent acquire
				-- or Response is older than Expected delay
				-- For sending acquire again
				if AcquiresData.Sent.VaultSession == "" or AcquiresData.Sent.At > MessagingResponsesTimestamp.AcquireAck or now - MessagingResponsesTimestamp.AcquireAck > Constants.MessagingExpectedDelay then


					-- If acquire was never sent, set last response as 1 second ago to prevent counting issues with 0 timestamp
					if AcquiresData.Sent.VaultSession == "" then
						MessagingResponsesTimestamp.AcquireAck = now - 1
						MessagingResponsesTimestamp.Released = now - 1
					end


					-- Send the acquire message
					print("Sending acquire:", currentLock.ServerSession, currentLock.VaultSession)
					now = DateTime.now().UnixTimestampMillis
					local message: Types.InterVaultMessage = {ServerSession=ServerSession, VaultSession=VaultSession, SentAt=now, Reason=Constants.InterVaultMessageReason.ACQUIRE}
					success, result = pcall(MessagingService.PublishAsync, MessagingService, currentLock.ServerSession..currentLock.VaultSession, message)


					-- Acquire send failed
					if not success then warn("[Retrying]", "MessagingService.PublishAsync", result)
					else


						-- Acquire sent
						AcquiresData.Sent.VaultSession = currentLock.VaultSession
						AcquiresData.Sent.ServerSession = currentLock.ServerSession
						AcquiresData.Sent.At = now


						-- Save current thread for resuming on message receive
						LockAcquireThread = coroutine.running()


						-- On another thread resume the thread with a fail status (if not resumed by response)
						Thread.Delay((Constants.MessagingExpectedDelay) / 1000 + 1, function(...)


							print("Manually resuming acquire thread")
							local thread = LockAcquireThread
							LockAcquireThread = nil
							if thread ~= nil and coroutine.status(thread) == "suspended" then task.spawn(thread, false) end
						end)


						-- Pause execution and on resume check if resumed by response or manually
						print("Freezing acquire thread")
						if not coroutine.yield() then continue end


						-- Break out of loop if resumed by response
						ReadyStates.Lock = true
						break
					end
				end


			else


				-- Save lock acquire complete
				LastActionCompletions.LockSave = LockData.LockedAt
				ReadyStates.Lock = true
				break
			end
		end


		-- Allow other threads to take over lock
		OngoingActions.LockChange:Update(false)
	end


	-- Read initial data from datastore
	local function ReadDataAsync()
		print("ReadDataAsync")


		-- While another thread is modifying the state of the data, wait
		while OngoingActions.DataChange.Current do OngoingActions.DataChange.ChangeSignal:Wait() end


		-- If vault state changed while waiting, ignore the call
		if VaultPrivateState ~= "REVIVE" then return end


		-- Prevent other threads from modifying data
		OngoingActions.DataChange:Update(true)


		print("Reading data now")


		-- Update the vault state
		VaultState:Update(Constants.VaultState.READING)


		-- Count attempts for logging failure rates
		local attempt = 1


		-- Keep trying till vault is in revive state and initial data is not read
		while VaultPrivateState == "REVIVE" and not ReadyStates.InitialData do


			-- Try reading data from DataStore
			local success, result:Types.DataStoreData? = pcall(vaultHolder.VaultDataStore.GetAsync, vaultHolder.VaultDataStore, vaultName, nil)


			-- Mark Datastore Service working or not
			DataStoreWorking:Update(success)


			-- If read failed, retry after some time
			if not success then
				warn("[Retrying 5] Attempt:", attempt, "DataStore.GetAsync", result)
				attempt += 1
				task.wait(6)
				continue
			end


			-- If data existed, use it
			if result ~= nil then


				print("Found old data")
				local now = DateTime.now().UnixTimestampMillis
				DSData = result


				-- Reconcile missing values
				Utils.Reconcile(DSData.__PUBLIC, template)


				-- Flag last data change timestamps
				LastActionCompletions.DataChange = now
				LastActionCompletions.DataSave = now


			else


				-- If no data exist in datastore, use the default data and flag for a save
				print("Using default data")
				DSData.__PUBLIC = Utils.DeepClone(template)
			end


			-- Update activity based on visible or hidden use
			if not vault.Hidden then
				if DSData.__ACTIVITY.FirstLogIn == 0 then DSData.__ACTIVITY.FirstLogIn = VaultOpentime end
				DSData.__ACTIVITY.LastLogIn = VaultOpentime
			end


			-- Set initial data as read
			ReadyStates.DataChanges = true
			ReadyStates.InitialData = true
			break
		end


		-- Release data change lock for other threads
		OngoingActions.DataChange:Update(false)
	end


	-- Upon data read, Save it every fixed amount of time
	-- TODO: Needs minor optimization for AFK vaults (loop runs (full DSSaveLoopDelay duration) even for AFK vault)
	local function DataSaveLoop()
		print("DSSaveLoop")


		-- If there exist another loop, don't start a new loop
		if OngoingActions.DataSaveLoop or not Requirements.DataSaveLoop then return end
		OngoingActions.DataSaveLoop = true


		print("Data save loop start")


		-- While ds save loop is required, keep running with delay
		while Requirements.DataSaveLoop do


			-- Mark function start time
			local now = DateTime.now().UnixTimestampMillis


			-- If initial data not read, wait entire period
			if not ReadyStates.InitialData then print("Initial data not read"); task.wait(Constants.DSSaveLoopDelay / 1000); continue end


			-- If no unsaved changes, wait entire period
			if not ReadyStates.DataChanges then print("No unsaved change"); task.wait(Constants.DSSaveLoopDelay / 1000); continue end


			-- Recent change was within last 5 seconds and last save was within last DSSaveLoopDelay (60 seconds), wait a small period and attempt save
			if now - LastActionCompletions.DataChange < 5000 and now - LastActionCompletions.DataSave < Constants.DSSaveLoopDelay then print("Last change too recent"); task.wait(10); continue end


			-- Regular save
			SaveDataAsync(false)
		end


		-- Allow other threads to start new loop
		print("Data save loop end")
		OngoingActions.DataSaveLoop = false
	end


	-- Set the vault in a semi-released mode where the vault is in the hands of the current server but lock is not renewed nor is data saved
	-- Only use for this mode is to prevent re-reviving a new vault and resume operation on this one
	local function StasisAsync()
		print("StasisAsync")


		-- Set private states
		VaultPrivateState = "STASIS"
		local now = DateTime.now().UnixTimestampMillis
		LastAchievedStates.Stasis = now


		-- If vault was in visible state, set the last logout
		if not vault.Hidden then DSData.__ACTIVITY.LastLogOut = now end


		-- Reset requirement flags
		Requirements.DataSaveLoop = false
		Requirements.LockRenewLoop = false


		-- Wait while another instance of Revive, Stasis or Cleanup is ongoing
		while OngoingActions.PrivateState.Current do OngoingActions.PrivateState.ChangeSignal:Wait() end


		-- If changed state while waiting, quit
		if VaultPrivateState ~= "STASIS" then
			OngoingActions.PrivateState:Update(false)
			return
		end


		-- Prevent another instance of Revive, Stasis or Cleanup
		OngoingActions.PrivateState:Update(true)


		-- If lock was not acquired even after waiting, directly cleanup without any wait
		-- Or if another server is waiting for the vault to close, directly cleanup
		if not ReadyStates.Lock or AcquiresData.Received.VaultSession ~= "" then
			Thread.Spawn(CleanupAsync)
			OngoingActions.PrivateState:Update(false)
			return


		else


			-- Save before going stasis
			-- TODO: saving before going stasis removes the possibility of server crashing (data lost while stasis) but it causes unnecessary frequent saves for server jumpers
			if ReadyStates.InitialData and ReadyStates.DataChanges then SaveDataAsync(true) end
			if VaultPrivateState ~= "STASIS" then
				OngoingActions.PrivateState:Update(false)
				return
			end


			-- Add a new delayed thread that waits for a specific time and then cleans up the vault automatically if it has been sitting idle all that time
			Thread.Delay((Constants.MemoryStoreLockExpiryDelay - Constants.MSLockRenewalDelay) / (2 * 1000), function()
				if VaultPrivateState == "STASIS" and now == LastAchievedStates.Stasis then CleanupAsync() end
			end)


			-- Update the state of the vault
			VaultState:Update(Constants.VaultState.STASIS)


			-- Release private state lock
			OngoingActions.PrivateState:Update(false)
		end
	end


	-- Renew lock only when it gets closer to stale
	local function RenewLockAsync()
		print("RenewLockAsync")


		-- While another thread is modifying lock, wait
		while OngoingActions.LockChange.Current do OngoingActions.LockChange.ChangeSignal:Wait() end


		-- Mark function start time
		local now = DateTime.now().UnixTimestampMillis


		-- If renew was called too early, return and do nothing
		if Constants.MSLockRenewalDelay / 2 >= (now - LastActionCompletions.LockSave) then return end


		-- Prevent other threads from modifying lock
		OngoingActions.LockChange:Update(true)


		print("Renewing lock")


		-- Execute as pcall to prevent errors breaking the loop
		local success = pcall(vaultHolder.LockMemoryStore.UpdateAsync, vaultHolder.LockMemoryStore, vaultName,
			function(current: Types.LockData?): Types.LockData?


				-- Mark start time
				now = DateTime.now().UnixTimestampMillis


				if current ~= nil and current.ServerSession == ServerSession and current.VaultSession == VaultSession then


					-- For same session id, update with new lock
					LockData.LockedAt = now
					return LockData


				else


					-- For lost lock, mark lock as released, discard any unsaved changes and cleanup the vault
					ReadyStates.DataChanges = false
					ReadyStates.Lock = false
					Thread.Spawn(CleanupAsync)
					return nil
				end
			end, Constants.MemoryStoreLockExpiryDelay)


		-- Mark MemoryStore service as working or not
		MemoryStoreWorking:Update(success)



		if not success then
			-- Let other threads modify lock
			OngoingActions.LockChange:Update(false)


			-- If failed and last updated is longer than memory store limit, close the vault
			if DateTime.now().UnixTimestampMillis - LastActionCompletions.LockSave > Constants.MemoryStoreLockExpiryDelay - Constants.MSLockRenewalDelay then CleanupAsync() end
			return
		end


		-- If lock saved successfully, update the last updated time
		LastActionCompletions.LockSave = LockData.LockedAt


		-- Unlock lock modifications
		OngoingActions.LockChange:Update(false)
	end


	-- Upon lock acquire, keep it updated every fixed amount of time
	local function LockRenewLoop()
		print("LockRenewLoop")


		-- If there exist another loop, don't start a new loop
		if OngoingActions.LockRenewLoop or not Requirements.LockRenewLoop then return end
		OngoingActions.LockRenewLoop = true


		print("Lock renew loop start")


		-- While lock renew loop is required, keep renewing with delay
		while Requirements.LockRenewLoop do
			task.wait(math.max(0, (Constants.MSLockRenewalDelay - (DateTime.now().UnixTimestampMillis - LastActionCompletions.LockSave))/1000))
			RenewLockAsync()
		end


		print("Lock renew loop end")


		-- Allow other threads to start loop now
		Requirements.LockRenewLoop = false
	end


	-- Revive rebuilds missing or broken parts of the vault and make it new ready for use
	-- It is async and so changes while this function is being executed can change or halt the process or reviving
	local function ReviveAsync()


		-- Set private states
		VaultPrivateState = "REVIVE"


		-- Set all requirement flags
		Requirements.LockRenewLoop = true
		Requirements.DataSaveLoop = true


		-- Wait while another instance of Revive, Stasis or Cleanup is ongoing
		while OngoingActions.PrivateState.Current do OngoingActions.PrivateState.ChangeSignal:Wait() end


		-- If stasis or cleanup was called while waiting, quit
		if VaultPrivateState ~= "REVIVE" then return end


		-- Prevent another instance of Revive, Stasis or Cleanup
		OngoingActions.PrivateState:Update(true)


		-- Blocking Setup Messaging until it is required and not set up
		if VaultPrivateState == "REVIVE" and not ReadyStates.Messaging then PrepareMessagingAsync() end


		-- If vault was called for stasis or cleanup by the time messaging was prepared, close and let it take over
		if VaultPrivateState ~= "REVIVE" then
			OngoingActions.PrivateState:Update(false)
			return
		end


		-- Blocking Lock acquire until it is required and not acquired
		if VaultPrivateState == "REVIVE" and not ReadyStates.Lock then AcquireLockAsync() end


		-- If lock is not acquired yet and vault was called for stasis or cleanup, close and let it take over
		if VaultPrivateState ~= "REVIVE" and not ReadyStates.Lock then
			OngoingActions.PrivateState:Update(false)
			return
		end


		-- Start the lock renew loop
		Thread.Defer(LockRenewLoop)


		-- If another server requested acquire, close and let cleanup take over
		-- Don't release just yet because the caller of this might be a remote update which is compulsory, or have this part and let the remote update just auto reject
		--if AcquireReceivedFrom ~= "" then
		--	VaultPrivateStateChanging:Update(false)
		--	CleanupAsync()
		--	return
		--end


		-- If data is not present, read the data
		if not ReadyStates.InitialData then ReadDataAsync() end


		-- Set the vault state
		VaultState:Update(Constants.VaultState.ACTIVE)


		-- Start the vault save loop
		Thread.Defer(DataSaveLoop)


		-- Set the vault as usable
		VaultUsable:Update(true)


		-- Release lock for private state change
		OngoingActions.PrivateState:Update(false)
	end


	-- Initiate all vault services if not started already, the caller will be called a unique reader
	-- Return a unique function to mark release, if no other readers are active, the vault will switch to stasis mode or be cleaned up
	-- This function call is compulsory in order to prevent a vault from getting released automatically (in scenarios like trading where keeping the vault open till trade succeeds)
	-- Similarly, calling the release function is compulsory to let the profile release freely
	function vault:AddReader()


		-- Infinitely scale count to serve individual reader
		local rid = NextReaderId
		NextReaderId += 1
		table.insert(ActiveReaders, rid)


		-- Current reader auto releases on shutdown
		local shutdownConnection : Signal.Connection<boolean, boolean>


		-- Return a release function unique to the caller that can be called once and any further calls are ignored
		local releaseFunction = function ()


			-- Release the shutdown callback
			if shutdownConnection.Connected then shutdownConnection:Disconnect() end


			-- Check if the reader is still active (to prevent double-release)
			local index = table.find(ActiveReaders, rid)


			-- Skip if already called (reader absent)
			if not index then return end


			-- If yes, remove the reader
			table.remove(ActiveReaders, index)


			-- No readers remain, set the vault to stasis mode or cleanup if server is already shutting down
			if #ActiveReaders == 0 then


				-- If server is shutting down then directly cleanup else move to stasis mode
				print("No active readers")
				if ServerShuttingDown then CleanupAsync()
				else StasisAsync()
				end
			end
		end


		-- Attach a watcher for server shut down
		shutdownConnection = ServerShuttingDown.ChangeSignal:Connect(function(_: boolean, isShuttingDown: boolean)
			if isShuttingDown then releaseFunction() end
		end)


		-- Revive the vault
		Thread.Spawn(ReviveAsync)
		return releaseFunction
	end


	return vault
end


return table.freeze({
	GetVault = GetVault,
	ServerShuttingDown = ServerShuttingDown,
	MemoryStoreWorking = MemoryStoreWorking,
	DataStoreWorking = DataStoreWorking,
	Types=Types,
})