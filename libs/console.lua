local console = {
    styles = {
        warning = "\027[33m%s\027[0m",
        error = "\027[31;1m%s\027[0m",
        fatal = "\027[41;30m%s\027[0m",
        info = "\027[34m%s\027[0m",
        debug = "\027[90m%s\027[0m"
    }
}

function console.style(name, format)
    name = tostring(name)
    if format == nil then
        return console.styles[name]
    else
        console.styles[name] = format
    end
end

function console.format(style, message)
    style = tostring(style)
    
    local format = console.styles[style]
    if not format then
        format = console.styles[style .. "ing"]
    end
    
    if type(format) == "string" then
        return string.format(format, message)
    elseif type(format) == "function" then
        return format(message)
    else
        console.warn('Attempted to use missing style "' .. tostring(style) .. '".')
        return message
    end
end

function console.log(message)
    print(message)
    if coroutine.running() then
        coroutine.yield()
    end
end

setmetatable(console, {
    __index = function(table, key)
        local v = rawget(table, key)
        if v ~= nil then
            return v
        end

        return function(message)
           local formatted = table.format(key, message)
           console.log(formatted)
        end
   end
})

return console    
