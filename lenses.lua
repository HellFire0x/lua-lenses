-- lenses.lua
local lenses = {}
lenses.__index = lenses

-- Constructor: create a lens that represents a path of keys
-- e.g. lens("foo", "bar", "baz") -> lens for tbl.foo.bar.baz
function lenses.lens(...)
    local keys = {...}

    return {
        get = function(tbl)
            local curr = tbl
            for _, k in ipairs(keys) do
                if type(curr) ~= "table" or curr[k] == nil then
                    return nil
                end
                curr = curr[k]
            end
            return curr
        end,

        set = function(tbl, value, opts)
            -- default opts if not provided
            opts = opts or {}
            local createMissing = opts.createMissing == true

            local curr = tbl
            local n = #keys
            for i = 1, n do
                local k = keys[i]
                local is_last = (i == n)

                if is_last then
                    -- final key => set the value
                    curr[k] = value
                else
                    -- intermediate key => descend
                    if type(curr[k]) ~= "table" then
                        if createMissing then
                            curr[k] = {}
                        else
                            -- if we can't create missing, do nothing or raise an error
                            if curr[k] == nil then
                                return -- or error("Path does not exist and createMissing=false")
                            end
                        end
                    end
                    curr = curr[k]
                end
            end
        end,

        set_copy = function(tbl, value, opts)
            -- Creates a shallow copy of each table along the path
            opts = opts or {}
            local createMissing = opts.createMissing == true

            -- We'll recursively copy tables as we traverse
            local function copy_table(orig)
                local new_t = {}
                for k, v in pairs(orig) do
                    new_t[k] = v
                end
                return new_t
            end

            local function set_recursive(original, depth)
                if depth > #keys then
                    -- we've set the value
                    return original
                end

                local key = keys[depth]
                local copy = copy_table(original)

                if depth == #keys then
                    -- last key => set the value
                    copy[key] = value
                else
                    local sub = copy[key]
                    if type(sub) ~= "table" then
                        if createMissing then
                            sub = {}
                        else
                            if sub == nil then
                                -- cannot proceed
                                return copy
                            else
                                -- or error("Non-table found while descending path, createMissing=false")
                            end
                        end
                    end
                    copy[key] = set_recursive(sub, depth + 1)
                end
                return copy
            end

            return set_recursive(tbl, 1)
        end,
    }
end

-- Helper lens for a single key (for composition)
function lenses.key(k)
    return lenses.lens(k)
end

-- Compose two lenses
-- usage: local combined = lensA:and_then(lensB)
function lenses:and_then(other)
    return {
        get = function(tbl)
            local mid = self.get(tbl)
            if mid == nil then
                return nil
            end
            return other.get(mid)
        end,

        set = function(tbl, value, opts)
            -- We need to get the mid table and set on that
            local mid = self.get(tbl)
            if mid == nil and opts and opts.createMissing then
                -- create if needed
                self.set(tbl, {}, opts)
                mid = self.get(tbl)
            end
            if mid then
                other.set(mid, value, opts)
            end
        end,

        set_copy = function(tbl, value, opts)
            -- We do an immutable-like approach
            local mid = self.get(tbl)
            if mid == nil and opts and opts.createMissing then
                -- first create an empty table in copy
                local updated_tbl = self.set_copy(tbl, {}, opts)
                return self:and_then(other).set_copy(updated_tbl, value, opts)
            elseif mid == nil then
                return tbl
            else
                -- We'll copy the top-level portion, then set inside
                local l1_updated = self.set_copy(tbl, other.set_copy(mid, value, opts), opts)
                return l1_updated
            end
        end,
    }
end

return lenses
