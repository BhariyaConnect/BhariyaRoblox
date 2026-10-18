# Promise v1.0.0
- Based on New luau type solver
- Uses generics for IntelliSense and easy autofill
- Tiny module making the code easy to read by anyone
- Use variables and methods with Pascal naming scheme only, camel or snake cases are for internal work and should not be used unless you know exactly what you are doing
- Uses circular doubly linked list based approach to allow O(1) disconnects at abrupt indexes.
- All callers and waiters start as different threads at the same time (in order of their entrances), its upto the cpu scheduler to decide which one finishes first.
- All callbacks and waiters are wrapped in pcall adding error handling, so error in one call doesn't affect the others
