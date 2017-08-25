local config = require("libs.config")
local console = require("libs.console")
local scope = {
    variables = {},
    run = true
}

function scope:inherit()
    local new = {}
    
    if self == scope then
        self.universal = self
        self.global = new
    end

    new = setmetatable(new, {__index = self})
    new.variables = setmetatable({}, {__index = self.variables})
    new.run = true
    new.parent = self

    return new
end

function scope:destroy()
    if self ~= self.global and self ~= self.universal then
        return self.parent
    end

    return self
end

function scope:get(name, indices)
    local result = {}
    if name.variable then
        local keys = self:get(name.variable, name.index)
        for i, subkey in ipairs(keys) do
            local values = self:get(subkey, indices)
            for j, value in ipairs(values) do
                table.insert(result, value)
            end
        end
    else
        local values = self.variables[name] or {""}
        if not indices then
            return values
        end
        
        for i, index in ipairs(indices) do
            if type(index) == "table" then
                local start = index[1] < 0 and (#values - index[1]) or index[1]
                local stop = index[2] < 0 and (#values - index[2]) or index[2]

                local step = stop < start and -1 or 1
                
                for j = start, stop, step do
                    table.insert(result, values[j] or "")
                end
            else
                table.insert(result, values[index] or "")
            end
        end
    end

    return result
end

function scope:set(name, indices, values)
    if type(values) ~= "table" then
        values = {values}
    end

    if not indices then
        self.variables[name] = values
    else
        if not self:has(name) then
            self.variables[name] = {}
        end

        local newIndices = {}
        for i, index in ipairs(indices) do
            if type(index) ~= "table" then
                table.insert(newIndices, index)
            else
                local start = index[1] < 0 and (#values - index[1]) or index[1]
                local stop = index[2] < 0 and (#values - index[2]) or index[2]

                local step = stop < start and -1 or 1
                
                for j = start, stop, step do
                    table.insert(newIndices, j)
                end
            end
        end
        
        for i, index in ipairs(newIndices) do
            self.variables[name][index] = values[i] or ''
        end
    end
end

function scope:has(name)
    local var = rawget(self.variables, name)
    return (var ~= nil)
end

function scope:load()
    local store = config.root .. "/environment.emi"

    local file = io.open(store)
    if not file then
        return
    end
    
    local pattern = "^(%w+)=(.*)$"
    local line = file:read("*l")
    while line do
        local name, valueString = line:match(pattern)
        local values = {}
        for val in string.gmatch(valueString, "[^\030]+") do
            table.insert(values, val)
        end

        scope:set(name, nil, values)
        line = file:read('*l')
    end
    file:close()
end

function scope:save()
    local store = config.root .. "/environment.emi"

    local file = io.open(store, "w")
    if not file then
        console.warn("Could not save universal scope: Does the data root exist?")
        return
    end
    
    for name, values in pairs(scope.variables) do
        file:write(name .. "=" .. table.concat(values, "\030"))
    end
    file:flush()
    file:close()
end

return scope:inherit()
