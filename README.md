# Lua Lenses

A powerful and flexible functional lens library for Lua that provides safe object property access and manipulation. Lenses allow you to focus on specific parts of nested data structures and perform operations like getting, setting, and immutable updates.

## Features

- Safe access to deeply nested table structures
- Immutable updates via `set_copy`
- Mutable updates via `set`
- Composable lenses using `and_then` or the `..` operator
- Dynamic key resolution using functions
- Array wildcards for operating on all numeric indices
- Configurable strictness and missing key behavior

## Installation

### Using LuaRocks

```bash
luarocks install lua-lenses
```

### Manual Installation

Copy the `lenses.lua` file to your project and require it:

```lua
local lenses = require("lenses")
```

## Basic Usage

### Creating Lenses

```lua
-- Create a lens from individual keys
local userNameLens = lenses.lens("user", "name")

-- Create a lens from a dot-separated path
local addressLens = lenses.path("user.address.street")

-- Create a lens for a single key
local ageLens = lenses.key("age")

-- Create a lens with custom options
local strictLens = lenses.with_opts({"user", "email"}, {
    strict = true,           -- Error on missing keys
    createMissing = false    -- Don't create missing tables
})
```

### Using Lenses

```lua
local data = {
    user = {
        name = "John",
        age = 30
    }
}

-- Getting values
local name = userNameLens:get(data)  -- Returns "John"

-- Setting values (mutates original)
userNameLens:set(data, "Jane")

-- Immutable updates (returns new copy)
local newData = userNameLens:set_copy(data, "Jane")
```

### Lens Composition

```lua
-- Using and_then
local userStreetLens = userLens:and_then(addressLens)

-- Using the .. operator
local userStreetLens = userLens .. addressLens

-- Composed lens operations
local street = userStreetLens:get(data)
local newData = userStreetLens:set_copy(data, "123 Main St")
```

### Array Operations

```lua
-- Create a lens for array elements
local arrayLens = lenses.array_wildcard()

-- Apply to all numeric indices
local items = arrayLens:get(data.items)
local newData = arrayLens:set_copy(data.items, 0)  -- Set all items to 0
```

## Advanced Features

### Dynamic Keys

```lua
-- Use a function to compute the key dynamically
local dynamicLens = lenses.lens("users", function(tbl)
    return tbl.currentUserIndex
end)
```

### Strict Mode

```lua
local strictLens = lenses.with_opts({"user", "email"}, {
    strict = true
})

-- Will throw an error if path doesn't exist
local email = strictLens:get(data)
```

### Auto-creating Missing Tables

```lua
local autoCreateLens = lenses.with_opts({"deep", "nested", "path"}, {
    createMissing = true
})

-- Will create intermediate tables as needed
autoCreateLens:set(data, "value")
```

## Error Handling

By default, lenses operate in non-strict mode and will return `nil` for missing paths. In strict mode, they will throw errors for:

- Accessing non-existent keys
- Attempting to traverse through non-table values
- Setting values on non-tables
- Missing intermediate tables when `createMissing = false`

## Performance Considerations

- `set_copy` creates new tables for the entire path, suitable for immutable updates
- `set` modifies the original table, more efficient but mutates data
- Dynamic key functions are called on each operation
- Array wildcards operate on all numeric indices

## License

MIT License
