local Signal = require(script.Parent.Parent:WaitForChild('Signal'))
local State = require(script.Parent.Parent:WaitForChild('State'))


export type Vault<DataT =	any> = {
	AddReader:					(self:Vault<DataT>)->()->(),
	UpdateData: 				(self:Vault<DataT>, keys:{string|number}, value:any)->(),
	GetPublicData: 				(self:Vault<DataT>)->DataT,
	GetActivityData: 			(self:Vault<DataT>)->ActivityData,
	Usable:						State.State<boolean>,
	DataUpdatedSignal:			Signal.Signal<{string|number}, any>,
	Session:					string,
	Server:						string,
	Name: 						string,
	Locals:						{},
	Hidden:						boolean,

	__index: Vault<DataT>,
}


export type LockData = {
	LockedAt:number,
	VaultSession:string,
	ServerSession:string,
}


export type ActivityData = {
	FirstLogIn:number,
	LastLogIn:number,
	LastLogOut:number
}


export type DataStoreData = {
	__ACTIVITY:ActivityData,
	__PUBLIC:any
}


export type InterVaultMessage = {
	SentAt:number,
	Reason:InterVaultMessageReason,
	ServerSession: string,
	VaultSession: string,
	Extra: any
}


export type VaultsHolder = {
	Name:string,
	VaultDataStore:DataStore,
	LockMemoryStore:MemoryStoreHashMap,
	Vaults:{[string]:Vault}
}


export type Acquirer = {
	JobId:string,
	ServerSession:string,
	VaultSession:string,
	AcquireTime:number
}


export type AcquireStatus = number
export type LockFreshness = number
export type VaultState = number
export type InterVaultMessageReason = number


return nil
