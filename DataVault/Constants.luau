local Types = require(script.Parent:WaitForChild("Types"))


return {
	InterVaultMessageReason = table.freeze({
		ACQUIRE 	= 0 	:: Types.InterVaultMessageReason, -- Ask for lock from old server
		RELEASED 	= 1 	:: Types.InterVaultMessageReason, -- Vault was released and lock is either upgraded or removed
		FORGET 		= 2 	:: Types.InterVaultMessageReason, -- Ask old server to ignore previous acquire call
		ACQUIRE_OK 	= 3 	:: Types.InterVaultMessageReason, -- Acquire acknowledgement
	}),

	VaultState = table.freeze({
		CREATED 			= 0 	:: Types.VaultState, -- Freshly created vault object
		MESSAGEPREPARING 	= 1 	:: Types.VaultState, -- Vault just started reviving, preparing messaging now
		LOCKING 			= 2 	:: Types.VaultState, -- Vault has completed preparing messaging, acquiring lock now
		READING 			= 3 	:: Types.VaultState, -- Vault has completed acquiring lock, reading initial data now
		ACTIVE 				= 4 	:: Types.VaultState, -- Vault completed revive process and is active for changes
		STASIS 				= 5 	:: Types.VaultState, -- Vault has moved to stasis mode, will still hold the vault in case player returns
		RELEASING	 		= 6 	:: Types.VaultState, -- Server started releasing the vault
		RELEASED 			= 7 	:: Types.VaultState, -- Vault was released and cleaned up rendering unusable
	}),

	MSLockRenewalDelay 					= 20 * 1000, -- 20 seconds (Server updates MS after this interval)
	MSLockStaleDelay 					= (20 * 1000 * 5) + 1000, -- 101 seconds (5 misses) (MS not updated for this interval is considered down or dead)
	MemoryStoreLockExpiryDelay 			= 30 * 60 * 1000, -- 30 minutes (MS exist for this interval so other servers can see who owned the lock before down or dead, or still owns it)

	MessagingExpectedDelay				= 7 * 1000, -- 7 seconds
	DSSaveLoopDelay 					= 60 * 1000, -- 60 seconds
}