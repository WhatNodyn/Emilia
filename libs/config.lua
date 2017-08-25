local config = {}

-- NOTE: Do not edit this file! Instead create "config.lua" in the
-- parent directory and override values there.

------------------
-- CONFIG START --
------------------

-- Default root, a path pointing to where all data is stored
config.root = (os.getenv('EMILIA_DATA') or process.cwd()) .. '/data'

------------------
--  CONFIG END  --
------------------

-- Here we load user overrides
local newConfig = (os.getenv('EMILIA_DATA') or process.cwd()) .. '/config.lua'
local f = loadfile(newConfig)
if f then
    newConfig = {}
    setfenv(f, newConfig)()
    for k, v in pairs(newConfig) do
        config[k] = v
    end
end

return config
