gpm.Packages = gpm.Packages or {}

module( "gpm.package", package.seeall )

-- Get one existing package
function Get( packageName )
    return gpm.Packages[ packageName ]
end

-- Get all existing packages
function GetAll()
    return gpm.Packages
end

-- Package Meta
local meta = {}
meta.__index = meta

function meta:GetName()
    return self.Name or self.FilePath
end

function meta:GetEnvironment()
    return self.Environment
end

function meta:GetFunction()
    return self.Function
end

function meta:GetVersion()
    return self.Version
end

function meta:GetLogger()
    return self.logger
end

-- Creating a new one
function Create( packageInfo, func, files, env )
    local packageName = packageInfo.name
    local startTime = SysTime()

    local packageEnv = gpm.environment.Create( func, env )
    packageEnv.PACKAGE_ENV = packageEnv

    -- Hooks & Timers
    gpm.environment.CustomTimers( packageEnv, packageName )
    gpm.environment.CustomHooks( packageEnv, packageName )

    -- Include
    function packageEnv.include( fileName )
        local fileFunc = files[ "lua/" .. fileName ]
        if (fileFunc) then
            return fileFunc()
        end

        return include( fileName )
    end

    -- Personal package logger
    local logger = gpm.logger.Create( packageName, packageInfo.color )
    packageEnv.logger = logger

    -- Creating meta
    local new = setmetatable( {
        ["Environment"] = packageEnv,
        ["Version"] = packageInfo.version,
        ["Name"] = packageName,
        ["Function"] = func,
        ["Logger"] = logger
    }, meta )

    gpm.Logger:Info( "Package `%s` was successfully loaded! It took %.4f seconds.", packageName, SysTime() - startTime )
    gpm.Packages[ packageName ] = new
    return new
end