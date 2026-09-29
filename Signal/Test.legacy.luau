--!nonstrict
--!native
--!optimize 2


local Signal = require(script.Parent)


local expected = ""
local actual = ""


function addToActual(value)
	if value == nil then
		actual = actual .. "nil "
	elseif value == false then
		actual = actual .. "false "
	elseif value == true then
		actual = actual .. "true "
	elseif typeof(value) == "string" then
		actual = actual .. value .. " "
	elseif typeof(value) == "number" then
		actual = actual .. tostring(value) .. " "
	end
end

function resetActual()
	actual = ""
end

function compare()
	print(if actual == expected then "PASS" else "FAIL")

	if actual ~= expected then
		print("EXPECTED:", expected)
		print("ACTUAL:  ", actual)
	end
end


local a, b, c


----------------------------------------------------------------
-- TEST_BASIC_FIRE
----------------------------------------------------------------

print("\nTEST_BASIC_FIRE")

resetActual()
expected = "A hello B hello "

local signal = Signal()

signal:Connect(function(value)
	addToActual("A")
	addToActual(value)
end)

signal:Connect(function(value)
	addToActual("B")
	addToActual(value)
end)

signal:Fire("hello")

compare()


----------------------------------------------------------------
-- TEST_MULTIPLE_FIRES
----------------------------------------------------------------

print("\nTEST_MULTIPLE_FIRES")

resetActual()
expected = "A 1 A 2 A 3 "

local signal = Signal()

signal:Connect(function(value)
	addToActual("A")
	addToActual(value)
end)

signal:Fire(1)
signal:Fire(2)
signal:Fire(3)

compare()


----------------------------------------------------------------
-- TEST_ARGUMENTS
----------------------------------------------------------------

print("\nTEST_ARGUMENTS")

resetActual()
expected = "hello 123 true nil world "

local signal = Signal()

signal:Connect(function(a, b, c, d, e)
	addToActual(a)
	addToActual(b)
	addToActual(c)
	addToActual(d)
	addToActual(e)
end)

signal:Fire("hello", 123, true, nil, "world")

compare()


----------------------------------------------------------------
-- TEST_NO_SUBSCRIBERS
----------------------------------------------------------------

print("\nTEST_NO_SUBSCRIBERS")

resetActual()
expected = ""

local signal = Signal()

signal:Fire("hello")
signal:Fire(123)

compare()


----------------------------------------------------------------
-- TEST_CONNECTION_ORDER
----------------------------------------------------------------

print("\nTEST_CONNECTION_ORDER")

resetActual()
expected = "A B C "

local signal = Signal()

signal:Connect(function()
	addToActual("A")
end)

signal:Connect(function()
	addToActual("B")
end)

signal:Connect(function()
	addToActual("C")
end)

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_DISCONNECT
----------------------------------------------------------------

print("\nTEST_DISCONNECT")

resetActual()
expected = "A C "

local signal = Signal()

a = signal:Connect(function()
	addToActual("A")
end)

b = signal:Connect(function()
	addToActual("B")
end)

c = signal:Connect(function()
	addToActual("C")
end)

b:Disconnect()

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_DISCONNECT_HEAD
----------------------------------------------------------------

print("\nTEST_DISCONNECT_HEAD")

resetActual()
expected = "B C "

local signal = Signal()

a = signal:Connect(function()
	addToActual("A")
end)

b = signal:Connect(function()
	addToActual("B")
end)

c = signal:Connect(function()
	addToActual("C")
end)

a:Disconnect()

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_DISCONNECT_TAIL
----------------------------------------------------------------

print("\nTEST_DISCONNECT_TAIL")

resetActual()
expected = "A B "

local signal = Signal()

a = signal:Connect(function()
	addToActual("A")
end)

b = signal:Connect(function()
	addToActual("B")
end)

c = signal:Connect(function()
	addToActual("C")
end)

c:Disconnect()

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_DISCONNECT_ONLY
----------------------------------------------------------------

print("\nTEST_DISCONNECT_ONLY")

resetActual()
expected = ""

local signal = Signal()

a = signal:Connect(function()
	addToActual("A")
end)

a:Disconnect()

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_DOUBLE_DISCONNECT
----------------------------------------------------------------

print("\nTEST_DOUBLE_DISCONNECT")

resetActual()
expected = ""

local signal = Signal()

a = signal:Connect(function()
	addToActual("A")
end)

a:Disconnect()
a:Disconnect()
a:Disconnect()

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_DISCONNECT_ONE_OF_MANY
----------------------------------------------------------------

print("\nTEST_DISCONNECT_ONE_OF_MANY")

resetActual()
expected = "A C D "

local signal = Signal()

a = signal:Connect(function()
	addToActual("A")
end)

b = signal:Connect(function()
	addToActual("B")
end)

c = signal:Connect(function()
	addToActual("C")
end)

local d = signal:Connect(function()
	addToActual("D")
end)

b:Disconnect()

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_DISCONNECT_ALL
----------------------------------------------------------------

print("\nTEST_DISCONNECT_ALL")

resetActual()
expected = ""

local signal = Signal()

signal:Connect(function()
	addToActual("A")
end)

signal:Connect(function()
	addToActual("B")
end)

signal:Connect(function()
	addToActual("C")
end)

signal:DisconnectAll()

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_DISCONNECT_ALL_EMPTY
----------------------------------------------------------------

print("\nTEST_DISCONNECT_ALL_EMPTY")

resetActual()
expected = ""

local signal = Signal()

signal:DisconnectAll()
signal:DisconnectAll()
signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_REUSE_AFTER_DISCONNECT_ALL
----------------------------------------------------------------

print("\nTEST_REUSE_AFTER_DISCONNECT_ALL")

resetActual()
expected = "B "

local signal = Signal()

signal:Connect(function()
	addToActual("A")
end)

signal:DisconnectAll()

signal:Connect(function()
	addToActual("B")
end)

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_ONCE
----------------------------------------------------------------

print("\nTEST_ONCE")

resetActual()
expected = "A "

local signal = Signal()

signal:Once(function()
	addToActual("A")
end)

signal:Fire()
signal:Fire()
signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_MULTIPLE_ONCE
----------------------------------------------------------------

print("\nTEST_MULTIPLE_ONCE")

resetActual()
expected = "A B C A A "

local signal = Signal()

signal:Once(function()
	addToActual("A")
end)

signal:Once(function()
	addToActual("B")
end)

signal:Once(function()
	addToActual("C")
end)

signal:Connect(function()
	addToActual("A")
end)

signal:Fire()
signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_ONCE_ARGUMENTS
----------------------------------------------------------------

print("\nTEST_ONCE_ARGUMENTS")

resetActual()
expected = "hello 123 true "

local signal = Signal()

signal:Once(function(a, b, c)
	addToActual(a)
	addToActual(b)
	addToActual(c)
end)

signal:Fire("hello", 123, true)
signal:Fire("NO", "NO", "NO")

compare()


----------------------------------------------------------------
-- TEST_ONCE_DISCONNECT
----------------------------------------------------------------

print("\nTEST_ONCE_DISCONNECT")

resetActual()
expected = ""

local signal = Signal()

a = signal:Once(function()
	addToActual("A")
end)

a:Disconnect()

signal:Fire()
signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_MIXED_CONNECT_ONCE
----------------------------------------------------------------

print("\nTEST_MIXED_CONNECT_ONCE")

resetActual()
expected = "A B C A C "

local signal = Signal()

signal:Connect(function()
	addToActual("A")
end)

signal:Once(function()
	addToActual("B")
end)

signal:Connect(function()
	addToActual("C")
end)

signal:Fire()
signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_WAIT
----------------------------------------------------------------

print("\nTEST_WAIT")

resetActual()
expected = "before after 123 "

local signal = Signal()

task.spawn(function()
	addToActual("before")

	local value = signal:Wait()

	addToActual("after")
	addToActual(value)
end)

task.wait()

signal:Fire(123)

task.wait()

compare()


----------------------------------------------------------------
-- TEST_WAIT_MULTIPLE_VALUES
----------------------------------------------------------------

print("\nTEST_WAIT_MULTIPLE_VALUES")

resetActual()
expected = "hello 123 true "

local signal = Signal()

task.spawn(function()
	local a, b, c = signal:Wait()

	addToActual(a)
	addToActual(b)
	addToActual(c)
end)

task.wait()

signal:Fire("hello", 123, true)

task.wait()

compare()


----------------------------------------------------------------
-- TEST_MULTIPLE_WAITERS
----------------------------------------------------------------

print("\nTEST_MULTIPLE_WAITERS")

resetActual()
expected = "A 123 B 123 C 123 "

local signal = Signal()

task.spawn(function()
	local value = signal:Wait()

	addToActual("A")
	addToActual(value)
end)

task.spawn(function()
	local value = signal:Wait()

	addToActual("B")
	addToActual(value)
end)

task.spawn(function()
	local value = signal:Wait()

	addToActual("C")
	addToActual(value)
end)

task.wait()

signal:Fire(123)

task.wait()

compare()


----------------------------------------------------------------
-- TEST_WAIT_MULTIPLE_TIMES
----------------------------------------------------------------

print("\nTEST_WAIT_MULTIPLE_TIMES")

resetActual()
expected = "A 1 B 2 C 3 "

local signal = Signal()

task.spawn(function()
	local value = signal:Wait()

	addToActual("A")
	addToActual(value)

	value = signal:Wait()

	addToActual("B")
	addToActual(value)

	value = signal:Wait()

	addToActual("C")
	addToActual(value)
end)

task.wait()

signal:Fire(1)
task.wait()

signal:Fire(2)
task.wait()

signal:Fire(3)
task.wait()

compare()


----------------------------------------------------------------
-- TEST_WAIT_LATE
----------------------------------------------------------------

print("\nTEST_WAIT_LATE")

resetActual()
expected = "A 123 "

local signal = Signal()

signal:Fire(999)

task.spawn(function()
	local value = signal:Wait()

	addToActual("A")
	addToActual(value)
end)

task.wait()

signal:Fire(123)

task.wait()

compare()


----------------------------------------------------------------
-- TEST_SELF_DISCONNECT
----------------------------------------------------------------

print("\nTEST_SELF_DISCONNECT")

resetActual()
expected = "A "

local signal = Signal()

local connection

connection = signal:Connect(function()
	addToActual("A")
	connection:Disconnect()
end)

signal:Fire()
signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_DISCONNECT_OTHER
----------------------------------------------------------------

print("\nTEST_DISCONNECT_OTHER")

resetActual()
expected = "A B "

local signal = Signal()

local connectionB

signal:Connect(function()
	addToActual("A")
	connectionB:Disconnect()
end)

connectionB = signal:Connect(function()
	addToActual("B")
end)

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_DISCONNECT_OTHER_THEN_FIRE
----------------------------------------------------------------

print("\nTEST_DISCONNECT_OTHER_THEN_FIRE")

resetActual()
expected = "A B A "

local signal = Signal()

local connectionB

signal:Connect(function()
	addToActual("A")
	connectionB:Disconnect()
end)

connectionB = signal:Connect(function()
	addToActual("B")
end)

signal:Fire()
signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_CONNECT_DURING_FIRE
----------------------------------------------------------------

print("\nTEST_CONNECT_DURING_FIRE")

resetActual()
expected = "A A B "

local signal = Signal()

local first = true

signal:Connect(function()
	addToActual("A")

	if first then
		first = false

		signal:Connect(function()
			addToActual("B")
		end)
	end
end)

signal:Fire()
signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_REENTRANT_FIRE
----------------------------------------------------------------

print("\nTEST_REENTRANT_FIRE")

resetActual()
expected = "A 1 A 2 A 3 "

local signal = Signal()

signal:Connect(function(value)
	addToActual("A")
	addToActual(value)

	if value < 3 then
		signal:Fire(value + 1)
	end
end)

signal:Fire(1)

compare()


----------------------------------------------------------------
-- TEST_REENTRANT_FIRE_MULTIPLE_CONNECTIONS
----------------------------------------------------------------

print("\nTEST_REENTRANT_FIRE_MULTIPLE_CONNECTIONS")

resetActual()
expected = "A 1 A 2 B 2 B 1 "

local signal = Signal()

signal:Connect(function(value)
	addToActual("A")
	addToActual(value)

	if value == 1 then
		signal:Fire(2)
	end
end)

signal:Connect(function(value)
	addToActual("B")
	addToActual(value)
end)

signal:Fire(1)

compare()


----------------------------------------------------------------
-- TEST_DISCONNECT_ALL_DURING_FIRE
----------------------------------------------------------------

print("\nTEST_DISCONNECT_ALL_DURING_FIRE")

resetActual()
expected = "A B C "

local signal = Signal()

signal:Connect(function()
	addToActual("A")
	signal:DisconnectAll()
end)

signal:Connect(function()
	addToActual("B")
end)

signal:Connect(function()
	addToActual("C")
end)

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_ONCE_REENTRANT_FIRE
----------------------------------------------------------------

print("\nTEST_ONCE_REENTRANT_FIRE")

resetActual()
expected = "A "

local signal = Signal()

signal:Once(function()
	addToActual("A")
	signal:Fire()
end)

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_ONCE_DISCONNECT_DURING_FIRE
----------------------------------------------------------------

print("\nTEST_ONCE_DISCONNECT_DURING_FIRE")

resetActual()
expected = "A B B "

local signal = Signal()

signal:Once(function()
	addToActual("A")
end)

signal:Connect(function()
	addToActual("B")
end)

signal:Fire()
signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_NIL_ARGUMENT
----------------------------------------------------------------

print("\nTEST_NIL_ARGUMENT")

resetActual()
expected = "nil "

local signal = Signal()

signal:Connect(function(value)
	addToActual(value)
end)

signal:Fire(nil)

compare()


----------------------------------------------------------------
-- TEST_MULTIPLE_NIL_ARGUMENTS
----------------------------------------------------------------

print("\nTEST_MULTIPLE_NIL_ARGUMENTS")

resetActual()
expected = "nil nil nil "

local signal = Signal()

signal:Connect(function(a, b, c)
	addToActual(a)
	addToActual(b)
	addToActual(c)
end)

signal:Fire(nil, nil, nil)

compare()


----------------------------------------------------------------
-- TEST_NIL_BETWEEN_VALUES
----------------------------------------------------------------

print("\nTEST_NIL_BETWEEN_VALUES")

resetActual()
expected = "A nil B "

local signal = Signal()

signal:Connect(function(a, b, c)
	addToActual(a)
	addToActual(b)
	addToActual(c)
end)

signal:Fire("A", nil, "B")

compare()


----------------------------------------------------------------
-- TEST_FALSE_ARGUMENT
----------------------------------------------------------------

print("\nTEST_FALSE_ARGUMENT")

resetActual()
expected = "false "

local signal = Signal()

signal:Connect(function(value)
	addToActual(value)
end)

signal:Fire(false)

compare()


----------------------------------------------------------------
-- TEST_ZERO_ARGUMENT
----------------------------------------------------------------

print("\nTEST_ZERO_ARGUMENT")

resetActual()
expected = "called "

local signal = Signal()

signal:Connect(function()
	addToActual("called")
end)

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_CONNECTION_AFTER_DISCONNECT_ALL
----------------------------------------------------------------

print("\nTEST_CONNECTION_AFTER_DISCONNECT_ALL")

resetActual()
expected = "B "

local signal = Signal()

a = signal:Connect(function()
	addToActual("A")
end)

signal:DisconnectAll()

b = signal:Connect(function()
	addToActual("B")
end)

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_DISCONNECT_ALL_MULTIPLE_TIMES
----------------------------------------------------------------

print("\nTEST_DISCONNECT_ALL_MULTIPLE_TIMES")

resetActual()
expected = "B "

local signal = Signal()

signal:Connect(function()
	addToActual("A")
end)

signal:DisconnectAll()
signal:DisconnectAll()
signal:DisconnectAll()

signal:Connect(function()
	addToActual("B")
end)

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_CONNECT_DISCONNECT_CONNECT
----------------------------------------------------------------

print("\nTEST_CONNECT_DISCONNECT_CONNECT")

resetActual()
expected = "B C "

local signal = Signal()

a = signal:Connect(function()
	addToActual("A")
end)

a:Disconnect()

b = signal:Connect(function()
	addToActual("B")
end)

c = signal:Connect(function()
	addToActual("C")
end)

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_MANY_CONNECTIONS
----------------------------------------------------------------

print("\nTEST_MANY_CONNECTIONS")

resetActual()
expected = "X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X X "

local signal = Signal()

local connections = {}

for i = 1, 100 do
	connections[i] = signal:Connect(function()
		addToActual("X")
	end)
end

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_MANY_DISCONNECTS
----------------------------------------------------------------

print("\nTEST_MANY_DISCONNECTS")

resetActual()
expected = ""

local signal = Signal()

local manyConnections = {}

for i = 1, 100 do
	manyConnections[i] = signal:Connect(function()
		addToActual("X")
	end)
end

for i = 1, 100 do
	manyConnections[i]:Disconnect()
end

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_DISCONNECT_HEAD_MIDDLE_TAIL
----------------------------------------------------------------

print("\nTEST_DISCONNECT_HEAD_MIDDLE_TAIL")

resetActual()
expected = "B D "

local signal = Signal()

a = signal:Connect(function()
	addToActual("A")
end)

b = signal:Connect(function()
	addToActual("B")
end)

c = signal:Connect(function()
	addToActual("C")
end)

local d = signal:Connect(function()
	addToActual("D")
end)

a:Disconnect()
c:Disconnect()

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_RECONNECT_AFTER_ALL_REMOVED
----------------------------------------------------------------

print("\nTEST_RECONNECT_AFTER_ALL_REMOVED")

resetActual()
expected = "C "

local signal = Signal()

a = signal:Connect(function()
	addToActual("A")
end)

b = signal:Connect(function()
	addToActual("B")
end)

a:Disconnect()
b:Disconnect()

c = signal:Connect(function()
	addToActual("C")
end)

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_WAIT_AND_CONNECT
----------------------------------------------------------------

print("\nTEST_WAIT_AND_CONNECT")

resetActual()
expected = "C 123 W 123 "

local signal = Signal()

signal:Connect(function(value)
	addToActual("C")
	addToActual(value)
end)

task.spawn(function()
	local value = signal:Wait()

	addToActual("W")
	addToActual(value)
end)

task.wait()

signal:Fire(123)

task.wait()

compare()


----------------------------------------------------------------
-- TEST_WAIT_AND_ONCE
----------------------------------------------------------------

print("\nTEST_WAIT_AND_ONCE")

resetActual()
expected = "O 123 W 123 "

local signal = Signal()

signal:Once(function(value)
	addToActual("O")
	addToActual(value)
end)

task.spawn(function()
	local value = signal:Wait()

	addToActual("W")
	addToActual(value)
end)

task.wait()

signal:Fire(123)

task.wait()

compare()


----------------------------------------------------------------
-- TEST_WAIT_MULTIPLE_FIRES
----------------------------------------------------------------

print("\nTEST_WAIT_MULTIPLE_FIRES")

resetActual()
expected = "W 1 W 2 "

local signal = Signal()

task.spawn(function()
	local value = signal:Wait()
	addToActual("W")
	addToActual(value)

	value = signal:Wait()
	addToActual("W")
	addToActual(value)
end)

task.wait()

signal:Fire(1)
task.wait()

signal:Fire(2)
task.wait()

compare()


----------------------------------------------------------------
-- TEST_SIGNAL_REUSE
----------------------------------------------------------------

print("\nTEST_SIGNAL_REUSE")

resetActual()
expected = "A B C "

local signal = Signal()

signal:Connect(function()
	addToActual("A")
end)

signal:Fire()

signal:DisconnectAll()

signal:Connect(function()
	addToActual("B")
end)

signal:Fire()

signal:DisconnectAll()

signal:Connect(function()
	addToActual("C")
end)

signal:Fire()

compare()


----------------------------------------------------------------
-- TEST_FINAL
----------------------------------------------------------------

print("\n========================================")
print("SIGNAL TESTS COMPLETE")
print("========================================")
