# BhariyaRoblox

A collection of reusable Roblox Luau modules maintained by [BhariyaConnect](https://github.com/BhariyaConnect). These modules are published for use in current and future Roblox projects.

## Modules

| Module | Description  |
|---|---|
| **[DataVault](https://github.com/BhariyaConnect/BhariyaRoblox/tree/master/DataVault)** | A player-data management module designed to coordinate data access and persistence across Roblox servers. |
| **[Signal](https://github.com/BhariyaConnect/BhariyaRoblox/tree/master/Signal)** | A typed event and signal implementation for connecting callbacks, firing events, waiting for events, and disconnecting listeners. Uses a circular doubly linked-list approach for listener management. |
| **[Thread](https://github.com/BhariyaConnect/BhariyaRoblox/tree/master/Thread)** | A coroutine/thread utility with a stack-based pool for reusing threads. Its functions are protected with `pcall` to help prevent thread loss when callbacks error. |
| **[State](https://github.com/BhariyaConnect/BhariyaRoblox/tree/master/State)** | A typed state module. Its documented behavior includes running callers and waiters in separate threads, with callback and waiter errors isolated using `pcall`. |
| **[Promise](https://github.com/BhariyaConnect/BhariyaRoblox/tree/master/Promise)** | A typed utility for representing asynchronous operations and handling their completion through callbacks and waiters. |
| **[BaseConverter](https://github.com/BhariyaConnect/BhariyaRoblox/tree/master/BaseConverter)** | A small typed base-conversion utility for signed integers. |

## Common characteristics

The module documentation highlights these conventions and implementation choices:

- Built with the newer Luau type solver in mind.
- Uses generics to improve type information, IntelliSense, and autocomplete.
- Public variables and methods use PascalCase naming.
- Callback-based modules use protected callback execution where documented.


## Installation and usage

Open the folder for the module you want to use and follow its README and source files for setup and API details. The modules are maintained together in this repository.
