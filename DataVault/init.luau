--!strict
--!native
--!optimize 2


--[[
DataVault v1.0.0

NOTE:

DSData.__PUBLIC = {Player = 100}
vault:UpdateData({"Player", "Coins"}, 50)
This is a case of undesired behavior and should be avoided

vault:GetPublicData().Score = 1234
Modifying data without UpdateDataAsync should be avoided as it may give unpredictable save behavior

Template should always be roblox serializable, no guarantee will be provided for invalid or non-serializable data

2 Templates for the same vault (opened simultaneously) should be the same, no guarantees will be provided otherwise

Stasis keeps vault usable as true, beware, rather always hold a reader to the vault till you think the vault might be used
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


local VaultsCount = State(0)
local ServerShuttingDown = State(false)
local LastMemoryStoreActionSuccess = State(true)
local LastDataStoreActionSuccess = State(true)
const ServerSession = HttpService:GenerateGUID(false)


game:BindToClose(function()
	ServerShuttingDown:Update(true)
	while VaultsCount.Current ~= 0 do VaultsCount.ChangeSignal:Wait() end
end)


local function GetVault<DataT>(dsName: string, vaultName: string, hidden:boolean, template: DataT): Types.Vault<DataT>


	-- Fetch VaultsHolder
	local vaultHolder = FetchVaultsHolder(dsName)


	-- If vault already in server, return it blindly
	local oldVault: Types.Vault<DataT> = vaultHolder.Vaults[vaultName]
	if oldVault ~= nil then


		-- If current vault is opened in Visible mode, convert old vault to visible
		if not hidden and oldVault.Hidden then oldVault:UpgradeToVisible() end


		return oldVault
	end


	-- Else create a new vault
	local vault = {Hidden=hidden} :: Types.Vault<DataT>
	local VaultSession = HttpService:GenerateGUID(false) -- Unique ID to find and track the vault session (will be used by other servers to talk to current server)


	-- Dummy lock value
	local LockData: Types.LockData = {VaultSession = VaultSession, ServerSession = ServerSession, LockedAt = 0}


	-- Dummy ActivityData
	local ActivityData = {
		FirstLogIn = 0,
		LastLogIn = 0,
		LastLogOut = 0,
	}

	-- Dummy PublicData
	local PublicData: DataT = {}


	-- Vault parameters scoped to the function
	local VaultUsable = State(false) -- Vault starts with being unusable
	local VaultState = State(Constants.VaultState.CREATED) -- Initial state of the vault is CREATED
	local NextReaderId = 0 -- Each reader gets its own ID
	local ActiveReaders: {number} = {} -- ALl the active readers
	local DataUpdatedSignal:Signal.Signal<{string|number}, any> = Signal() -- Fired when any data field changes
	local VaultPrivateState: Types.VaultPrivateState = Constants.VaultPrivateState.UNKNOWN -- Saves vault's private state


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
		DataSave = State(false),
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
	local StasisWaitThread: thread? -- Thread waiting for stasis time to be over to clean up the vault
	local ShutdownConnection: Signal.Connection<boolean>? -- Connection to wait for server shutdown


	vault.Name = vaultName
	vault.Usable = VaultUsable
	vault.DataUpdatedSignal = DataUpdatedSignal
	vault.Session = VaultSession
	vault.Server = ServerSession
	vault.Locals = {}


	-- Returns the public data only if vault is usable
	-- NOTE: Do not use this method without having an active reader for the vault first, else nil will be returned with a warning
	function vault:GetPublicData()


		-- Warn if vault is not in usable state
		if not VaultUsable.Current then warn("[DataVault] Vault is in unusable state, hence it's public data should not be read") end


		-- Finally return public data
		return PublicData


	end


	-- Returns the activity data only if vault is usable
	-- NOTE: Do not use this method without having an active reader for the vault first, else nil will be returned with a warning
	function vault:GetActivityData()


		-- Warn if vault is not in usable state
		if not VaultUsable.Current then warn("[DataVault] Vault is in unusable state, hence it's activity data should not be read") end


		-- Finally return activity data
		return ActivityData


	end


	-- The function to update any field in the data
	-- This also signals all update listeners about the change
	function vault:UpdateData(keys, value)


		-- Reject if vault is not in usable state
		if not VaultUsable.Current then


			warn("Vault is in unusable state, hence it's data can not be modified")
			return


		end


		-- Starting point for finding the exact spot where data has to be changed
		local pointer:{[string|number]:any} = PublicData


		-- Execute in pcall to prevent key and index errors blocking the data change lock forever
		local success, reason = pcall(function()


			-- Iterate through the keys and update the current pointer
			for i, key in keys do


				-- Reached the last key, place value somehow
				if i == #keys then


					-- OPTIMISATION: If value is different, only then set the has changes flag
					if value ~= pointer[key] then


						-- Flag the vault as data changes ready
						pointer[key] = value
						ReadyStates.DataChanges = true


						-- Update last data change timestamp
						LastActionCompletions.DataChange = DateTime.now().UnixTimestampMillis


						-- Fire the signal for data update listeners
						DataUpdatedSignal:Fire(keys, value)
					end
				else


					-- Create empty table if it doesn't exist
					pointer[key] = pointer[key] or {}


					-- Move the pointer to the next key
					pointer = pointer[key]
				end
			end
		end)


		-- Warn errors in data update
		if not success then warn("[DataVault] UpdateData failed: ", reason) end


	end


	-- Upgrade a hidden vault to visible (update its activity data)
	function vault:UpgradeToVisible()


		-- If was visible already, ignore the call
		if not vault.Hidden then return end
		vault.Hidden = false


		-- Set last login to now
		ActivityData.LastLogIn = DateTime.now().UnixTimestampMillis


		-- Flag vault data as dirty
		ReadyStates.DataChanges = true


	end


	-- Release the lock or upgrade it to the newest acquirer
	local function UpgradeOrReleaseLockAsync()


		-- While another thread is modifying lock, wait
		while OngoingActions.LockChange.Current do OngoingActions.LockChange.ChangeSignal:Wait() end


		-- If vault went back to revived state while waiting, ignore the release call
		if VaultPrivateState == Constants.VaultPrivateState.REVIVE then return end


		-- Prevent other threads from modifying lock
		OngoingActions.LockChange:Update(true)


		-- Will keep time for any action
		local now: number


		-- Attempts to save failure count
		local attempts = 1


		-- Run the loop indefinitely as release is not an optional operation
		while true do


			-- Execute as pcall to prevent errors
			local success, value:Types.LockData? = pcall(vaultHolder.LockMemoryStore.UpdateAsync, vaultHolder.LockMemoryStore, vaultName,
				function(current: Types.LockData?): Types.LockData?


					-- Mark action start time
					now = DateTime.now().UnixTimestampMillis


					-- If lock exists and owner is exactly current server and vault
					if current ~= nil and current.ServerSession == ServerSession and current.VaultSession == VaultSession then


						-- Update with new lock with the acquirer's session
						return {LockedAt=now, ServerSession=AcquiresData.Received.ServerSession, VaultSession=AcquiresData.Received.VaultSession}


					else -- For a different owner, mark lock as released, discard any unsaved changes and cleanup the vault (MIGHT LOSE DATA but impossible unless services are down)


						ReadyStates.DataChanges = false
						ReadyStates.Lock = false
						return nil
					end


				end, Constants.LockExpiryDelayMS / 1000)


			-- Flag MemoryStore service as working or failed
			LastMemoryStoreActionSuccess:Update(success)


			-- Mark when released will be sent
			now = DateTime.now().UnixTimestampMillis


			-- If lock upgrade/release was successful, send the release message
			if success then


				-- Lock was upgraded
				if value ~= nil and value.VaultSession ~= "" then


					-- Send released message to acquirer
					local message: Types.InterVaultMessage = {ServerSession=ServerSession, VaultSession=VaultSession, SentAt=now, Reason=Constants.InterVaultMessageReason.RELEASED}
					local mess_success, result = pcall(MessagingService.PublishAsync, MessagingService, value.ServerSession..":"..value.VaultSession, message)
					if not mess_success then warn("[Retrying 3]", "MessagingService.PublishAsync Acquire response", result) end


				end


				-- Unlock lock modifications
				OngoingActions.LockChange:Update(false)
				break


			else -- Upgrade/release failed


				-- Wait and retry
				warn("[Retrying 3] Attempt:", attempts, "MemoryStore.UpdateAsync (upgrade or release lock)")
				task.wait(3)


				-- Unlock lock modifications
				OngoingActions.LockChange:Update(false)


				-- If failed and last updated is too old, stop retries
				if now - LastActionCompletions.LockSave > Constants.LockStaleDelayMS then break end


				-- Increment attempt
				attempts += 1


			end
		end
	end


	-- Save data into datastore with the option to force save which forcefully saves ignoring last updated and last saved values
	local function SaveDataAsync(forceSave: boolean)


		-- Count attempts for logging failure rates
		local attempt = 1


		-- Continue till there are changes yet to be saved
		while ReadyStates.DataChanges do


			-- While another thread is saving data, wait
			while OngoingActions.DataSave.Current do OngoingActions.DataSave.ChangeSignal:Wait() end


			-- Action Start time
			local now = DateTime.now().UnixTimestampMillis


			-- If no unsaved changes after waiting, or last change was too recent and last save isn't too old, skip. But forceSave skips the time based skipping
			if not ReadyStates.InitialData or not ReadyStates.DataChanges or ((not forceSave and now - LastActionCompletions.DataSave < 5000 and now - LastActionCompletions.DataSave < Constants.DataSaveLoopDelayMS)) then return end


			-- Prevent other thread from modifying data
			OngoingActions.DataSave:Update(true)


			-- Flag available data changes as false
			ReadyStates.DataChanges = false


			-- SetAsync clones the last value of the data, so further modification while it is saving acts as new changes
			local success, result = pcall(vaultHolder.VaultDataStore.SetAsync, vaultHolder.VaultDataStore, vaultName, {__ACTIVITY=ActivityData, __PUBLIC=PublicData})


			-- Flag DataStore service as working or not
			LastDataStoreActionSuccess:Update(success)


			-- If save failed, retry after delay
			if not success then


				-- Re-attach the unsaved changes flag
				ReadyStates.DataChanges = true
				warn("[Retrying 5] Attempt:", attempt, "DataStore.SetAsync", result)
				task.wait(5)
				attempt += 1


				-- Allow other threads to take over the data save
				OngoingActions.DataSave:Update(false)
				continue


			else


				-- Allow other threads to take over the data save
				OngoingActions.DataSave:Update(false)


			end


			-- Flag last save
			LastActionCompletions.DataSave = now
			break


		end
	end


	-- Closes Messaging for the vault
	local function CloseMessagingAsync()


		-- While another thread is modifying the state of the messaging, wait
		while OngoingActions.MessagingChannel.Current do OngoingActions.MessagingChannel.ChangeSignal:Wait() end


		-- If vault went back to revived state while waiting, ignore the release call
		if VaultPrivateState == Constants.VaultPrivateState.REVIVE then return end


		-- Prevent other thread from modifying messaging
		OngoingActions.MessagingChannel:Update(true)


		-- If Messaging channel exists, disconnect it
		if MessagingChannel ~= nil then


			MessagingChannel:Disconnect()
			MessagingChannel = nil
			ReadyStates.Messaging = false


		end


		-- Release the lock for messaging change
		OngoingActions.MessagingChannel:Update(false)


	end


	-- Cleanup the vault from memory, leaving it totally unusable
	-- It can not be recovered once cleaned up
	local function CleanupAsync()


		-- Ignore run for already cleaned vault
		if VaultPrivateState == Constants.VaultPrivateState.CLEANUP then return end


		VaultPrivateState = Constants.VaultPrivateState.CLEANUP
		LastAchievedStates.Cleanup = DateTime.now().UnixTimestampMillis


		-- Set new state for the vault
		VaultState:Update(Constants.VaultState.RELEASING)


		-- De-reference the vault instantly so future vault queries will not return this vault
		vaultHolder.Vaults[vaultName] = nil
		VaultUsable:Update(false)


		-- Disconnect the shutdown connection
		if ShutdownConnection ~= nil and ShutdownConnection.Connected then
			ShutdownConnection:Disconnect()
			ShutdownConnection = nil
		end


		-- Cancel the stasis wait thread
		if StasisWaitThread ~= nil and coroutine.status(StasisWaitThread) == "suspended" then


			task.cancel(StasisWaitThread)
			StasisWaitThread = nil


		end


		-- Reset all requirements
		Requirements.DataSaveLoop = false
		Requirements.LockRenewLoop = false


		-- Wait while another instance of Revive, Stasis or Cleanup is ongoing
		while OngoingActions.PrivateState.Current do OngoingActions.PrivateState.ChangeSignal:Wait() end


		-- Save one final time
		if ReadyStates.InitialData and ReadyStates.DataChanges then SaveDataAsync(true) end


		-- Release the lock safely (upgrade if required)
		if ReadyStates.Lock then UpgradeOrReleaseLockAsync() end


		-- Close messaging channel
		if ReadyStates.Messaging then CloseMessagingAsync() end


		-- Set new state for the vault
		VaultState:Update(Constants.VaultState.RELEASED)


		-- Send forget to the server who received current session's acquire
		if AcquiresData.Sent.VaultSession ~= "" then


			local message: Types.InterVaultMessage = {ServerSession=ServerSession, VaultSession=VaultSession, SentAt=DateTime.now().UnixTimestampMillis, Reason=Constants.InterVaultMessageReason.FORGET}
			local success, result = pcall(MessagingService.PublishAsync, MessagingService, AcquiresData.Sent.ServerSession..":"..AcquiresData.Sent.VaultSession, message)
			if not success then warn("[Retrying 3]", "MessagingService.PublishAsync Forget", result) end


		end


		-- Cleanup if lock acquire was still waiting
		local thread = LockAcquireThread
		LockAcquireThread = nil
		if thread ~= nil and coroutine.status(thread) == "suspended" then task.spawn(thread, false) end


		-- Reduce the number of active vaults (used to delay server shutdown)
		VaultsCount:Update(VaultsCount.Current - 1)
	end


	-- Performs operations based on messages received from another session or server
	local function MessagingLogic(Message: {Data:Types.InterVaultMessage, Sent:number})


		if Message.Data.Reason == Constants.InterVaultMessageReason.ACQUIRE then


			-- If this message is older than currently saved, ignore
			if Message.Data.SentAt < AcquiresData.Received.At then return end


			-- Save the server session id to upgrade lock in the future
			AcquiresData.Received.VaultSession = Message.Data.VaultSession
			AcquiresData.Received.ServerSession = Message.Data.ServerSession
			AcquiresData.Received.At = Message.Data.SentAt


			local message: Types.InterVaultMessage = {Reason=Constants.InterVaultMessageReason.ACQUIRE_OK, ServerSession=ServerSession, VaultSession=VaultSession, SentAt=DateTime.now().UnixTimestampMillis}
			local success, result = pcall(MessagingService.PublishAsync, MessagingService, Message.Data.ServerSession..":"..Message.Data.VaultSession, message)
			if not success then warn("[Retrying 3]", "MessagingService.PublishAsync Acquire response", result) end

			-- If vault was already in stasis mode, upgrade directly
			if VaultPrivateState == Constants.VaultPrivateState.STASIS then CleanupAsync() end


		elseif Message.Data.Reason == Constants.InterVaultMessageReason.FORGET then


			-- Remove the last known acquirer if the same server sent Forget
			if Message.Data.ServerSession == AcquiresData.Received.ServerSession and
				Message.Data.VaultSession == AcquiresData.Received.VaultSession and
				Message.Data.SentAt > AcquiresData.Received.At
			then


				AcquiresData.Received.ServerSession = ""
				AcquiresData.Received.VaultSession = ""
				AcquiresData.Received.At = 0


			end


		elseif Message.Data.Reason == Constants.InterVaultMessageReason.ACQUIRE_OK then


			-- Acknowledgement received for acquire
			if Message.Data.ServerSession == AcquiresData.Sent.ServerSession and
				Message.Data.VaultSession == AcquiresData.Sent.VaultSession and
				Message.Data.SentAt > AcquiresData.Sent.At
			then


				MessagingResponsesTimestamp.AcquireAck = Message.Data.SentAt


			end


		elseif Message.Data.Reason == Constants.InterVaultMessageReason.RELEASED then


			-- Other server released or upgraded the lock
			if Message.Data.ServerSession == AcquiresData.Sent.ServerSession and
				Message.Data.VaultSession == AcquiresData.Sent.VaultSession and
				Message.Data.SentAt > AcquiresData.Sent.At
			then


				MessagingResponsesTimestamp.Released = Message.Data.SentAt


				-- Activate the lock acquire suspended thread
				local thread = LockAcquireThread
				LockAcquireThread = nil
				LockData.LockedAt = Message.Data.SentAt
				if thread ~= nil and coroutine.status(thread) == "suspended" then task.spawn(thread) end


			end
		end
	end


	-- Starts preparation of Messaging service for the vault (skips if it is already prepared)
	local function PrepareMessagingAsync()


		-- While another thread is modifying the state of messaging, wait
		while OngoingActions.MessagingChannel.Current do OngoingActions.MessagingChannel.ChangeSignal:Wait() end


		-- If vault changed state while waiting, ignore the call
		if VaultPrivateState ~= Constants.VaultPrivateState.REVIVE then return end


		-- Prevent other thread from modifying messaging
		OngoingActions.MessagingChannel:Update(true)


		-- Update the vault state
		VaultState:Update(Constants.VaultState.MESSAGEPREPARING)


		-- Count attempts for logging failure rates
		local attempt = 1


		-- While messaging is unusable and required, try making it usable
		while VaultPrivateState == Constants.VaultPrivateState.REVIVE and not ReadyStates.Messaging do


			-- Try subscribing to the session
			local success, result = pcall(MessagingService.SubscribeAsync, MessagingService, ServerSession..":"..VaultSession, MessagingLogic)


			-- If subscribe failed, retry after a delay
			if not success then


				warn("[Retrying 2] Attempt:", attempt, "MessagingService.SubscribeAsync", result)
				task.wait(2)
				attempt += 1
				continue


			end


			MessagingChannel = result
			ReadyStates.Messaging = true
			break
		end


		-- Release the lock for messaging change
		OngoingActions.MessagingChannel:Update(false)
	end


	-- Acquire lock
	local function AcquireLockAsync()


		-- While another thread is modifying the state of the lock, wait
		while OngoingActions.LockChange.Current do OngoingActions.LockChange.ChangeSignal:Wait() end


		-- Prevent other thread from modifying lock
		OngoingActions.LockChange:Update(true)


		-- Update the vault state
		VaultState:Update(Constants.VaultState.LOCKING)


		-- Count attempts for logging failure rates
		local attempt = 1


		-- If lock is unacquired, and it is required, try to acquire it
		while VaultPrivateState == Constants.VaultPrivateState.REVIVE and not ReadyStates.Lock do


			-- Remembers if acquire needs to be sent
			local acquireRequired = false
			local currentLock: Types.LockData


			-- Call Update in pcall to prevent errors breaking the loop
			local success, result = pcall(vaultHolder.LockMemoryStore.UpdateAsync, vaultHolder.LockMemoryStore, vaultName,
				function(current: Types.LockData?): Types.LockData?


					-- Mark function start time
					local now = DateTime.now().UnixTimestampMillis


					if current == nil or (current.ServerSession == "" and current.VaultSession == "") then


						-- Lock non-existent, instantly acquire it
						LockData.LockedAt = now
						return LockData


					elseif current.ServerSession == ServerSession and current.VaultSession == VaultSession then


						-- Lock is stale, renew it
						if current.LockedAt + Constants.LockStaleDelayMS < now then


							LockData.LockedAt = now
							return LockData


						end


						-- Ignore update if lock is fresh
						LockData = current
						return nil


					else


						-- Lock is stale, and did not receive any response for 5 acquires, assume server dead
						if (now - current.LockedAt) > Constants.LockStaleDelayMS and (AcquiresData.Sent.At - MessagingResponsesTimestamp.AcquireAck) >= Constants.MessagingExpectedDelayMS * 5 then


							LockData.LockedAt = now
							return LockData


						end


						-- Mark retry required
						acquireRequired = true
						currentLock = current
						return nil


					end
				end, Constants.LockExpiryDelayMS / 1000)


			-- Update Failed, retry
			if not success then


				warn("[Retrying 3] Attempt:", attempt, "MemoryStore.UpdateAsync", result)
				task.wait(3)
				attempt += 1
				continue


			end


			-- Flag MemoryStore service as working or not
			LastMemoryStoreActionSuccess:Update(success)


			-- Needs to send acquire
			if acquireRequired then


				-- Mark process start
				local now = DateTime.now().UnixTimestampMillis


				-- Acquire was never sent
				-- or Response is older than recent acquire
				-- or Response is older than Expected delay
				-- For sending acquire again
				if AcquiresData.Sent.VaultSession == "" or AcquiresData.Sent.At > MessagingResponsesTimestamp.AcquireAck or now - MessagingResponsesTimestamp.AcquireAck > Constants.MessagingExpectedDelayMS then


					-- If acquire was never sent, set last response as 1 ms ago to prevent counting issues with 0 timestamp
					if AcquiresData.Sent.VaultSession == "" then


						MessagingResponsesTimestamp.AcquireAck = now - 1
						MessagingResponsesTimestamp.Released = now - 1


					end


					-- Send the acquire message
					local message: Types.InterVaultMessage = {ServerSession=ServerSession, VaultSession=VaultSession, SentAt=now, Reason=Constants.InterVaultMessageReason.ACQUIRE}
					success, result = pcall(MessagingService.PublishAsync, MessagingService, currentLock.ServerSession..":"..currentLock.VaultSession, message)


					if not success then


						-- Acquire send failed
						warn("[Retrying 3]", "MessagingService.PublishAsync Acquire", result)
						task.wait(3)


					else


						-- Acquire sent
						AcquiresData.Sent.VaultSession = currentLock.VaultSession
						AcquiresData.Sent.ServerSession = currentLock.ServerSession
						AcquiresData.Sent.At = now


						-- Save current thread for resuming on message receive
						LockAcquireThread = coroutine.running()


						-- On another thread resume the thread with a fail status (if not resumed by response)
						Thread.Delay((Constants.MessagingExpectedDelayMS) / 1000 + 1, function(...)


							local thread = LockAcquireThread
							LockAcquireThread = nil
							if thread ~= nil and coroutine.status(thread) == "suspended" then task.spawn(thread) end


						end)


						-- Pause execution and on resume with check if resumed by response or timeout
						coroutine.yield()
						continue


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


		-- If vault state changed while waiting, ignore the call
		if VaultPrivateState ~= Constants.VaultPrivateState.REVIVE then return end


		-- Update the vault state
		VaultState:Update(Constants.VaultState.READING)


		-- Count attempts for logging failure rates
		local attempt = 1


		-- Keep trying till vault is in revive state and initial data is not read
		while VaultPrivateState == Constants.VaultPrivateState.REVIVE and not ReadyStates.InitialData do


			-- Try reading data from DataStore
			local success, result:Types.DataStoreData? = pcall(vaultHolder.VaultDataStore.GetAsync, vaultHolder.VaultDataStore, vaultName, nil)


			-- Mark Datastore Service working or not
			LastDataStoreActionSuccess:Update(success)


			-- If read failed, retry after some time
			if not success then


				warn("[Retrying 6] Attempt:", attempt, "DataStore.GetAsync", result)
				attempt += 1
				task.wait(6)
				continue


			end


			-- Mark function start time
			local now = DateTime.now().UnixTimestampMillis


			-- If data existed, use it
			if result ~= nil then


				-- Reconcile missing values
				ActivityData = Utils.Reconcile(result.__ACTIVITY, ActivityData)
				PublicData = Utils.Reconcile(result.__PUBLIC, template)


				-- Flag last data change timestamps
				LastActionCompletions.DataChange = now
				LastActionCompletions.DataSave = now


			else


				-- If no data exist in datastore, use the default data and flag for a save
				PublicData = Utils.DeepClone(template)


			end


			-- Update activity based on visible or hidden use
			if not vault.Hidden then


				if ActivityData.FirstLogIn == 0 then ActivityData.FirstLogIn = now end
				ActivityData.LastLogIn = now
				vault:UpgradeToVisible()


			end


			-- Set initial data as read
			ReadyStates.InitialData = true
			break


		end
	end


	-- Upon data read, Save it every fixed amount of time
	local function DataSaveLoop()


		-- If there exist another loop, don't start a new loop
		if OngoingActions.DataSaveLoop then return end
		OngoingActions.DataSaveLoop = true


		-- While ds save loop is required, keep running with delay
		while Requirements.DataSaveLoop do


			-- Mark function start time
			local now = DateTime.now().UnixTimestampMillis


			-- If initial data not read, wait entire period
			if not ReadyStates.InitialData then task.wait(Constants.DataSaveLoopDelayMS / 1000); continue end


			-- If no unsaved changes, wait entire period
			if not ReadyStates.DataChanges then task.wait(Constants.DataSaveLoopDelayMS / 1000); continue end


			-- Recent change was within last 5 seconds and last save was within last DataSaveLoopDelayMS (60 seconds), wait a small period and attempt save
			if now - LastActionCompletions.DataChange < 5000 and now - LastActionCompletions.DataSave < Constants.DataSaveLoopDelayMS then task.wait(10); continue end


			-- Regular save
			SaveDataAsync(false)


		end


		-- Allow other threads to start new loop
		OngoingActions.DataSaveLoop = false


	end


	-- Set the vault in a semi-released mode where the vault is in the hands of the current server but lock is not renewed nor is data saved
	-- Only use for this mode is to prevent re-reviving a new vault and resume operation on this one
	local function StasisAsync()


		-- Prevent already stasis or cleaned vaults
		if VaultPrivateState == Constants.VaultPrivateState.STASIS or VaultPrivateState == Constants.VaultPrivateState.CLEANUP then return end


		-- Set private states
		VaultPrivateState = Constants.VaultPrivateState.STASIS
		local now = DateTime.now().UnixTimestampMillis
		LastAchievedStates.Stasis = now


		-- If vault was in visible state, set the last logout
		if not vault.Hidden then
			ActivityData.LastLogOut = now
			ReadyStates.DataChanges = true
		end


		-- Reset requirement flags
		Requirements.DataSaveLoop = false
		Requirements.LockRenewLoop = false


		-- Wait while another instance of Revive, Stasis or Cleanup is ongoing
		while OngoingActions.PrivateState.Current do OngoingActions.PrivateState.ChangeSignal:Wait() end


		-- If changed state while waiting, quit
		if VaultPrivateState ~= Constants.VaultPrivateState.STASIS then return end


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
			-- NOTE: saving before going stasis removes the possibility of server crashing (data lost while stasis) but it causes unnecessary frequent saves for server jumpers
			if ReadyStates.InitialData and ReadyStates.DataChanges then SaveDataAsync(true) end
			if VaultPrivateState ~= Constants.VaultPrivateState.STASIS then


				OngoingActions.PrivateState:Update(false)
				return


			end


			-- Add a new delayed thread that waits for a specific time and then cleans up the vault automatically if it has been sitting idle all that time
			StasisWaitThread = task.delay((Constants.LockExpiryDelayMS - Constants.LockRenewalDelayMS) / (2 * 1000), function()
				if VaultPrivateState == Constants.VaultPrivateState.STASIS and now == LastAchievedStates.Stasis then CleanupAsync() end
			end)


			-- Update the state of the vault
			VaultState:Update(Constants.VaultState.STASIS)


			-- Release private state lock
			OngoingActions.PrivateState:Update(false)


		end
	end


	-- Renews lock only when it gets closer to stale
	local function RenewLockAsync()


		-- While another thread is modifying lock, wait
		while OngoingActions.LockChange.Current do OngoingActions.LockChange.ChangeSignal:Wait() end


		-- Mark function start time
		local now = DateTime.now().UnixTimestampMillis


		-- If renew was called too early, return and do nothing
		if Constants.LockRenewalDelayMS / 2 >= (now - LastActionCompletions.LockSave) then return end


		-- Prevent other threads from modifying lock
		OngoingActions.LockChange:Update(true)


		-- Execute as pcall to prevent errors breaking the loop
		local success, last:Types.LockData? = pcall(vaultHolder.LockMemoryStore.UpdateAsync, vaultHolder.LockMemoryStore, vaultName,
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
					VaultUsable:Update(false)
					Thread.Defer(CleanupAsync)
					return nil


				end
			end, Constants.LockExpiryDelayMS / 1000)


		-- Mark MemoryStore service as working or not
		LastMemoryStoreActionSuccess:Update(success)


		if not success then


			-- Let other threads modify lock
			OngoingActions.LockChange:Update(false)


			-- If failed and last updated is longer than memory store limit, close the vault
			if DateTime.now().UnixTimestampMillis - LastActionCompletions.LockSave > Constants.LockExpiryDelayMS - Constants.LockRenewalDelayMS then CleanupAsync() end
			return


		end


		-- If lock saved successfully, update the last updated time
		if last ~= nil then LastActionCompletions.LockSave = last.LockedAt end


		-- Unlock lock modifications
		OngoingActions.LockChange:Update(false)
	end


	-- Upon lock acquire, keep it updated every fixed amount of time
	local function LockRenewLoop()


		-- If there exist another loop, don't start a new loop
		if OngoingActions.LockRenewLoop then return end
		OngoingActions.LockRenewLoop = true


		-- While lock renew loop is required, keep renewing with delay
		while Requirements.LockRenewLoop do
			task.wait(math.max(0, (Constants.LockRenewalDelayMS - (DateTime.now().UnixTimestampMillis - LastActionCompletions.LockSave))/1000))
			RenewLockAsync()
		end


		-- Allow other threads to start loop now
		OngoingActions.LockRenewLoop = false
	end


	-- Revive rebuilds missing or broken parts of the vault and make it new ready for use
	-- It is async and so changes while this function is being executed can change or halt the process or reviving
	local function ReviveAsync()


		-- Prevent already revived or cleaned vaults
		if VaultPrivateState == Constants.VaultPrivateState.REVIVE or VaultPrivateState == Constants.VaultPrivateState.CLEANUP then return end


		-- Set private states
		VaultPrivateState = Constants.VaultPrivateState.REVIVE


		-- Set all requirement flags
		Requirements.LockRenewLoop = true
		Requirements.DataSaveLoop = true


		-- Wait while another instance of Revive, Stasis or Cleanup is ongoing
		while OngoingActions.PrivateState.Current do OngoingActions.PrivateState.ChangeSignal:Wait() end


		-- If stasis or cleanup was called while waiting, quit
		if VaultPrivateState ~= Constants.VaultPrivateState.REVIVE then return end


		-- Prevent another instance of Revive, Stasis or Cleanup
		OngoingActions.PrivateState:Update(true)


		-- Blocking Setup Messaging until it is required and not set up
		if VaultPrivateState == Constants.VaultPrivateState.REVIVE and not ReadyStates.Messaging then PrepareMessagingAsync() end


		-- If vault was called for stasis or cleanup by the time messaging was prepared, close and let it take over
		if VaultPrivateState ~= Constants.VaultPrivateState.REVIVE then


			OngoingActions.PrivateState:Update(false)
			return


		end


		-- Blocking Lock acquire until it is required and not acquired
		if VaultPrivateState == Constants.VaultPrivateState.REVIVE and not ReadyStates.Lock then AcquireLockAsync() end


		-- If lock is not acquired yet and vault was called for stasis or cleanup, close and let it take over
		if VaultPrivateState == Constants.VaultPrivateState.CLEANUP or (VaultPrivateState ~= Constants.VaultPrivateState.REVIVE and not ReadyStates.Lock) then


			OngoingActions.PrivateState:Update(false)
			return


		end


		-- Start the lock renew loop
		Thread.Defer(LockRenewLoop)


		-- If data is not present, read the data
		if VaultPrivateState ~= Constants.VaultPrivateState.CLEANUP and not ReadyStates.InitialData then ReadDataAsync() end


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


		-- Return dummy if server already shutting down
		if ServerShuttingDown.Current then 
			warn("Attempted to open vault after server shutdown")
			return function() end 
		end


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
				if ServerShuttingDown.Current then CleanupAsync()
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


	--Save the vault in vault holder
	vaultHolder.Vaults[vaultName] = vault
	VaultsCount:Update(VaultsCount.Current + 1)


	-- Cleanup forcefully if server shutdown is called
	ShutdownConnection = ServerShuttingDown.ChangeSignal:Once(function(prev: boolean, now: boolean)
		if now then CleanupAsync() end
	end)


	return vault
end


return table.freeze({
	GetVault = GetVault,
	ServerShuttingDown = ServerShuttingDown,
	MemoryStoreWorking = LastMemoryStoreActionSuccess,
	DataStoreWorking = LastDataStoreActionSuccess,
})