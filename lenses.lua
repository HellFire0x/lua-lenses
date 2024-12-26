-- lenses.lua
local lenses = {}
lenses.__index = lenses

-------------------------------------------------------------------------------
-- HELPER FUNCTIONS
-------------------------------------------------------------------------------

-- Shallow copy a table
local function shallow_copy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = v
    end
    return copy
end

-- Split a string by a delimiter (default: ".")
local function split_path(str, sep)
    sep = sep or "%."
    local fields = {}
    for field in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(fields, field)
    end
    return fields
end

-------------------------------------------------------------------------------
-- CORE LENS CONSTRUCTOR
-------------------------------------------------------------------------------

-- Create a lens from a sequence of keys (which might be strings or functions).
-- Each "key" can be:
--  1) a string -> direct table key
--  2) a function(tbl) -> returns the actual key to use (dynamic)
local function build_lens(keys, opts)
    opts = opts or {}
    local strict = opts.strict -- if true, we error on missing keys or invalid paths
    local createMissing = opts.createMissing -- if true, set() will create missing sub-tables
    local pathDescr = table.concat(
        (function()
            local t = {}
            for _, k in ipairs(keys) do
                t[#t+1] = type(k) == "string" and k or "<fn>"
            end
            return t
        end)(), "."
    )

    local lens = {}

    ----------------------------------------------------------------------------
    -- GET
    ----------------------------------------------------------------------------
    function lens:get(tbl)
        local current = tbl
        for _, k in ipairs(keys) do
            -- If the key is a function, call it to retrieve the real key
            local realKey = (type(k) == "function") and k(current) or k

            if type(current) ~= "table" then
                if strict then
                    error(("Attempt to index non-table while accessing '%s'"):format(pathDescr))
                else
                    return nil
                end
            end

            if current[realKey] == nil then
                if strict then
                    error(("Key '%s' does not exist in table at path '%s'"):format(tostring(realKey), pathDescr))
                else
                    return nil
                end
            end

            current = current[realKey]
        end
        return current
    end

    ----------------------------------------------------------------------------
    -- SET (in-place)
    ----------------------------------------------------------------------------
    function lens:set(tbl, value)
        local current = tbl
        for i = 1, #keys do
            local k = keys[i]
            local realKey = (type(k) == "function") and k(current) or k

            if i == #keys then
                -- final step: set the value
                if type(current) ~= "table" then
                    if strict then
                        error(("Cannot set on non-table at path '%s'"):format(pathDescr))
                    else
                        return
                    end
                end
                current[realKey] = value
            else
                -- intermediate step
                if type(current) ~= "table" then
                    if strict then
                        error(("Encountered non-table before final step at path '%s'"):format(pathDescr))
                    else
                        return
                    end
                end

                if current[realKey] == nil then
                    if createMissing then
                        current[realKey] = {}
                    else
                        if strict then
                            error(("Missing key '%s' in path '%s' and createMissing=false"):format(tostring(realKey), pathDescr))
                        else
                            return
                        end
                    end
                elseif type(current[realKey]) ~= "table" and (i < #keys) then
                    if createMissing then
                        -- Overwrite non-table with a new table
                        current[realKey] = {}
                    else
                        if strict then
                            error(("Expected table at '%s' for sub-key in path '%s'"):format(tostring(realKey), pathDescr))
                        else
                            return
                        end
                    end
                end
                current = current[realKey]
            end
        end
    end

    ----------------------------------------------------------------------------
    -- SET_COPY (immutable approach)
    ----------------------------------------------------------------------------
    function lens:set_copy(tbl, value)
        -- Recursively copy until we reach the final key
        local function recurse(original, depth)
            if depth > #keys then
                -- we've arrived at the target
                return value
            end

            if type(original) ~= "table" then
                if strict then
                    error(("Non-table encountered at depth %d, path '%s'"):format(depth, pathDescr))
                else
                    -- do nothing (return original as-is)
                    return original
                end
            end

            local c = shallow_copy(original)
            local k = keys[depth]
            local realKey = (type(k) == "function") and k(original) or k

            if c[realKey] == nil then
                -- handle missing subtable
                if depth < #keys then
                    if createMissing then
                        c[realKey] = recurse({}, depth + 1)
                    else
                        if strict then
                            error(("Missing subkey '%s' in path '%s', createMissing=false"):format(tostring(realKey), pathDescr))
                        else
                            -- do nothing
                        end
                    end
                else
                    -- final step: set the value
                    c[realKey] = value
                end
            else
                -- copy deeper
                c[realKey] = recurse(c[realKey], depth + 1)
            end

            return c
        end

        return recurse(tbl, 1)
    end

    ----------------------------------------------------------------------------
    -- COMPOSITION
    ----------------------------------------------------------------------------
    -- Compose this lens with another lens, e.g., lensA:and_then(lensB)
    -- The result is a new lens that focuses on path A, then path B inside that subtable.
    function lens:and_then(nextLens)
        -- new lens is effectively a multi-step path
        local function combined_get(tbl)
            local mid = self:get(tbl)
            if mid == nil then
                return nil
            end
            return nextLens:get(mid)
        end

        local function combined_set(tbl, value)
            local mid = self:get(tbl)
            if mid ~= nil then
                nextLens:set(mid, value)
            end
        end

        local function combined_set_copy(tbl, value)
            local mid = self:get(tbl)
            if mid == nil then
                -- either return tbl as-is or, if createMissing, we need to build the sub-structure
                if createMissing or nextLens.createMissing then
                    local partial = self:set_copy(tbl, {})     -- first ensure mid is a table
                    return self:and_then(nextLens):set_copy(partial, value)
                else
                    return tbl
                end
            else
                -- set a copy at the sub-level, then set that copy back in the parent immutably
                local updated_sub = nextLens:set_copy(mid, value)
                return self:set_copy(tbl, updated_sub)
            end
        end

        -- unify opts so nextLens picks up the same strict/createMissing if we want
        local newOpts = {
            strict = strict or nextLens.strict,
            createMissing = createMissing or nextLens.createMissing,
        }

        return build_lens({}, newOpts) -- create a dummy lens structure, then override methods
        :override_methods({
            get = combined_get,
            set = combined_set,
            set_copy = combined_set_copy,
        })
    end

    ----------------------------------------------------------------------------
    -- Add a convenience method for overriding the lens’ get/set/set_copy
    ----------------------------------------------------------------------------
    function lens:override_methods(methodTable)
        for k, fn in pairs(methodTable) do
            self[k] = fn
        end
        return self
    end

    ----------------------------------------------------------------------------
    -- Return lens with attached config
    ----------------------------------------------------------------------------
    lens.strict = strict
    lens.createMissing = createMissing
    return lens
end

-------------------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------------------

-- Create a lens from a sequence of keys (strings or functions)
function lenses.lens(...)
    local keys = {...}
    return build_lens(keys, {})
end

-- Create a lens from a string path (like "foo.bar.baz"), split by dots
function lenses.path(str)
    local keys = split_path(str)
    return build_lens(keys, {})
end

-- Single key lens (convenience)
function lenses.key(k)
    return build_lens({k}, {})
end

-- Create a lens with custom options (strict, createMissing)
function lenses.with_opts(keys, opts)
    return build_lens(keys, opts)
end

-- A lens that iterates over all *numeric* indices (wildcard for array-like tables).
-- We return a table of sub-lenses, or a special lens that applies set_copy to all.
function lenses.array_wildcard(opts)
    opts = opts or {}
    local function get_all(tbl)
        if type(tbl) ~= "table" then
            return nil
        end
        local results = {}
        for i, v in ipairs(tbl) do
            results[i] = v
        end
        return results
    end

    local function set_all(tbl, value)
        if type(tbl) ~= "table" then return end
        for i, _ in ipairs(tbl) do
            tbl[i] = value
        end
    end

    local function set_copy_all(tbl, value)
        if type(tbl) ~= "table" then
            return tbl
        end
        local c = shallow_copy(tbl)
        for i, _ in ipairs(c) do
            c[i] = value
        end
        return c
    end

    local lens = build_lens({}, opts)
    lens:get = get_all
    lens:set = set_all
    lens:set_copy = set_copy_all
    return lens
end

-- Extend build_lens with a chain operator for syntactic sugar
-- e.g. lensA .. lensB
getmetatable(lenses.lens).__concat = function(a, b)
    return a:and_then(b)
end

return lenses
