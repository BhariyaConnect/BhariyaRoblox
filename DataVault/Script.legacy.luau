----!strict

--local DataVault = require(script.Parent)


--local temp = {
--	Name = "",
--	Score = 0,
--	Has = {
--		["A"] = 10,
--		["B"] = 0,
--		[100] = 2,
--	}
--}


--local vault = DataVault("DataVault-T1", "3", temp)
--print(vault.SessionId)


--vault.DataUpdatedSignal:Connect(function(value, keys)
--	print("Data changed: ", keys, "to", value)
--end)


--local cleanup = vault:Prepare()

--while not vault.Usable.Current do
--	vault.Usable.ChangeSignal:Wait()
--end


--print(vault:GetPublicData())


--local vault2 = DataVault("DataVault-T1", "3", temp)
--print(vault2.SessionId)

--vault2.DataUpdatedSignal:Connect(function(value, keys)
--	print("Data changed: ", keys, "to", value)
--end)
--local cleanup2 = vault2:Prepare()
--print(vault2:GetPublicData())