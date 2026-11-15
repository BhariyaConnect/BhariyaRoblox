<div align="center">

# ◈ State

### A tiny reactive state container for Roblox Luau.

**Change the value once. Let every dependent react.**

[![Version](https://img.shields.io/badge/version-1.0.0-8b5cf6?style=for-the-badge)](#)
[![Platform](https://img.shields.io/badge/platform-Roblox-111827?style=for-the-badge&logo=roblox)](#)
[![Language](https://img.shields.io/badge/language-Luau-00A2FF?style=for-the-badge)](#)
[![Strict](https://img.shields.io/badge/typing-strict-16a34a?style=for-the-badge)](#)

**State keeps a value and broadcasts every update to its listeners through a Signal.**

[Getting Started](#-getting-started) · [Examples](#-examples) · [API](#-api-reference) · [Tips](#-tips--gotchas)

</div>

---

## ⚡ What is State?

Ever changed a value and then had to remember every single place that depends on it?

A player's coins change. The HUD needs updating. A shop button needs refreshing. A quest tracker needs to react. Maybe an achievement system is listening too.

Instead of manually updating every dependent system, let each one subscribe to the state.

```text
                 State: Coins
                      │
          ┌───────────┼───────────┐
          │           │           │
        HUD         Shop        Quests
          │           │           │
       Refresh      Refresh     Check
```

**State is a small reactive container built around that idea.**

It stores the current value and exposes a `ChangeSignal`. Whenever `Update()` is called, listeners receive both the old value and the new value.

## ✨ Features

- **Generic types:** the initial value determines the state's type.
- **Reactive updates:** listeners are notified through a Signal.
- **Old + new values:** callbacks receive both values.
- **Every update fires:** even if the new value is identical to the old value.
- **Modification timestamp:** `LastModified` is updated using `os.clock()`.
- **Small API:** one constructor, one update method, one signal.

---

## 🚀 Getting Started

### 1. Install the module

Place `State` alongside your `Signal` module, because State requires it as a sibling:

```text
YourFolder
├── State
└── Signal
```

### 2. Create a state

```lua
local State = require(path.to.State)

local Coins = State(100)
```

The initial value determines the generic type:

```lua
local Coins = State(100)       -- State<number>
local IsAlive = State(true)    -- State<boolean>
local PlayerName = State("A")  -- State<string>
```

### 3. Read the current value

```lua
print(Coins.Current) -- 100
```

### 4. Listen for changes

```lua
local connection = Coins.ChangeSignal:Connect(function(oldValue, newValue)
    print("Coins changed:", oldValue, "->", newValue)
end)
```

### 5. Update the state

```lua
Coins:Update(150)

-- Output:
-- Coins changed: 100 -> 150
```

That's the entire loop: create, subscribe, update. Every listener gets notified when `Update()` fires the signal.

---

## 🎮 Examples

### Update a UI when a value changes

```lua
local Coins = State(100)

local function updateCoinLabel(oldValue, newValue)
    coinLabel.Text = tostring(newValue)
end

Coins.ChangeSignal:Connect(updateCoinLabel)

-- Somewhere in your game:
Coins:Update(250)
```

The UI doesn't need to know where the update came from. It only needs to subscribe.

### Multiple systems, one state

```lua
local Health = State(100)

Health.ChangeSignal:Connect(function(old, new)
    healthBar.Size = UDim2.fromScale(new / 100, 1)
end)

Health.ChangeSignal:Connect(function(old, new)
    if new < old then
        print("Player took damage!")
    end
end)

Health.ChangeSignal:Connect(function(old, new)
    if new <= 0 then
        print("Player is down!")
    end
end)

Health:Update(75)
```

One update, multiple independent reactions.

### Track previous and current values

Because listeners receive both values, you can compare them without storing another variable:

```lua
local Level = State(1)

Level.ChangeSignal:Connect(function(oldLevel, newLevel)
    if newLevel > oldLevel then
        print("Level up!")
    elseif newLevel < oldLevel then
        print("Level decreased.")
    end
end)

Level:Update(2)
```

### React to every update

State deliberately fires even when the new value is equal to the old value:

```lua
local Mode = State("Lobby")

Mode.ChangeSignal:Connect(function(oldMode, newMode)
    print("Update received:", oldMode, newMode)
end)

Mode:Update("Lobby")
```

The listener still runs. This can be useful when an update itself matters, not only a change in value.

If you only want to react when the value is different, compare the arguments:

```lua
Mode.ChangeSignal:Connect(function(oldMode, newMode)
    if oldMode == newMode then
        return
    end

    print("The mode actually changed.")
end)
```

### Read the last modification time

```lua
local Status = State("Ready")

Status:Update("Loading")

print(Status.LastModified) -- os.clock() timestamp
```

`LastModified` is updated whenever `Update()` is called, including updates where the new value equals the old value.

---

## 📚 API Reference

### `State(initial)`

Creates a new state object.

```lua
local Coins = State(100)
```

| Argument | Description |
|---|---|
| `initial` | Required initial value; determines the generic type |

Returns a `State<T>` object.

### `state.Current`

The current value stored by the state.

```lua
print(Coins.Current)
```

Use `Update()` to change the value so listeners are notified.

### `state:Update(newValue)`

Sets the current value, updates `LastModified`, and fires `ChangeSignal`.

```lua
Coins:Update(200)
```

Listeners receive:

```lua
function(oldValue, newValue)
    -- ...
end
```

The signal fires on every call, even when `oldValue == newValue`.

### `state.ChangeSignal`

The Signal used to subscribe to updates.

```lua
local connection = Coins.ChangeSignal:Connect(function(oldValue, newValue)
    print(oldValue, newValue)
end)

-- When no longer needed:
connection:Disconnect()
```

The exact connection behaviour is provided by the Signal module.

### `state.LastModified`

The `os.clock()` value recorded during construction and updated on every call to `Update()`.

```lua
print(Coins.LastModified)
```

This is an elapsed-time clock value, not a Unix timestamp or wall-clock date.

---

## 🧠 How it works

The implementation is intentionally small:

```lua
function State:Update(newValue)
    local oldValue = self.Current

    self.Current = newValue
    self.LastModified = os.clock()

    self.ChangeSignal:Fire(oldValue, newValue)
end
```

That's the core.

1. Capture the old value.
2. Store the new value.
3. Record the modification time.
4. Notify every connected listener with `(oldValue, newValue)`.

The state object itself doesn't know what depends on it. That responsibility belongs to the listeners.

---

## 🎯 Tips & gotchas

### ✅ Prefer `Update()` over assigning `Current`

```lua
-- Recommended
Coins:Update(500)
```

Directly assigning `Current` bypasses the timestamp update and signal notification:

```lua
-- Avoid
Coins.Current = 500
```

### ✅ Keep listeners focused

A listener should generally handle one responsibility. Let the HUD update the HUD, let the quest system check quests, and let the achievement system check achievements.

This keeps systems independent.

### ✅ Disconnect listeners when finished

If a temporary object subscribes to a state, disconnect when that object is no longer in use:

```lua
local connection = Coins.ChangeSignal:Connect(function(old, new)
    -- React to updates
end)

-- Later:
connection:Disconnect()
```

### ⚠️ Equal values still trigger listeners

This is intentional behaviour, not a deduplication-based observable.

```lua
local Ready = State(true)

Ready.ChangeSignal:Connect(function(old, new)
    print("Fired", old, new)
end)

Ready:Update(true) -- Still fires.
```

Add an equality check inside the listener if your use case needs change-only behaviour.

### ⚠️ State does not automatically observe table mutations

If the current value is a table, mutating that table directly does not call `Update()`:

```lua
local Profile = State({
    Coins = 100,
})

-- This does not fire ChangeSignal:
Profile.Current.Coins += 50
```

To notify listeners, update the state:

```lua
local newProfile = table.clone(Profile.Current)
newProfile.Coins += 50

Profile:Update(newProfile)
```

This example uses a shallow clone. If nested tables are modified, clone the relevant nested structures too.

### ⚠️ Listener errors depend on Signal

State delegates notification to your Signal module. Error handling, listener ordering, and connection semantics therefore depend on that implementation.

---

## 🧪 Quick behaviour checklist

- [ ] A state can be created with a number, string, boolean, or table.
- [ ] `Current` starts with the supplied initial value.
- [ ] `LastModified` is initialized at construction.
- [ ] `Update()` changes `Current`.
- [ ] `Update()` refreshes `LastModified`.
- [ ] Listeners receive old value first and new value second.
- [ ] Listeners are notified even when old and new values are equal.
- [ ] Disconnecting a connection follows the Signal module's behaviour.

---

## 📦 Version

**State v1.0.0**

---

<div align="center">

### Stop chasing dependencies. Let them listen.

**State — one value, many reactions.**

</div>
