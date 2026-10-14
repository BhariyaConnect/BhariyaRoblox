--!strict
--!native
--!optimize 2

local Signal = require(script.Parent)
task.wait(3)

local count = 1_000
local createStart = os.clock()
for i = 1, count do
	Signal()
end
local createEnd = os.clock()

print(count, "signal creation took", (createEnd-createStart) * 1000, "ms")
task.wait(1)
local sig = Signal()
createStart = os.clock()
for i = 1, count do
	sig:Connect(function()end)
end
createEnd = os.clock()

print(count, "connect took", (createEnd-createStart) * 1000, "ms")
task.wait(1)
createStart = os.clock()
for i = 1, count do
	sig:Once(function()end)
end
createEnd = os.clock()

print(count, "once took", (createEnd-createStart) * 1000, "ms")
task.wait(1)
createStart = os.clock()
for i = 1, count do
	sig:Fire()
end
createEnd = os.clock()

print(count, "fire with", count*2, "callbacks each took", (createEnd-createStart) * 1000, "ms")

--[[
Old signal
  07:41:19.956  1000 signal creation took 0.03640000068116933 ms  -  Server - Benchmark:15
  07:41:20.957  1000 connect took 0.20140000560786575 ms  -  Server - Benchmark:24
  07:41:21.957  1000 once took 0.2530999918235466 ms  -  Server - Benchmark:32
  07:41:23.576  1000 fire with 2000 callbacks each took 602.100000003702 ms  -  Server - Benchmark:40
  ]]