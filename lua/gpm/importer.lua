
local IterateZipFiles = gpm.unzip.IterateZipFiles
local CompileString = CompileString
local ArgAssert = ArgAssert
local promise = gpm.promise

module("gpm.importer", package.seeall)

local LUA_REALM = SERVER and "lsv" or "lcl"

-- Example: gpm.importer.GetLuaFuncs( gpm.unzip.IterateZipFiles(fileHandle) )
function CompileLuaFuncs( iter )
    ArgAssert( iter, 1, "function" )

    return function()
        local fileName, data
        repeat
            fileName, data = iter()
            if fileName and fileName:EndsWith(".lua") then
                return fileName, CompileString(data or "", fileName)
            end
        until fileName == nil
    end
end

function ParsePackageInfo(tbl)
    if not istable(tbl) then return end

    local info = {}
    info.name = isstring(tbl.name) and tbl.name or "no name"
    info.version = isstring(tbl.version) and tbl.version or "0.0.1"
    info.main = isstring(tbl.main) and tbl.main or nil

    return info
end

function LoadPackageInfoFromFunc(func)
    if isstring(func) then func = CompileString(func) end
    if not isfunction(func) then return end

    setfenv(func, {})
    local ok, info = xpcall(func, ErrorNoHaltWithStack)
    return ok and ParsePackageInfo(info)
end

function ImportZIP( pathToArchive )
    local f
    if pathToArchive:StartWith("data/") then
        f = file.Open(pathToArchive:sub(6), "rb", "DATA")
    end
    if not f then return ErrorNoHaltWithStack("file not found") end

    local packageInfo
    local files = {}
    for fileName, func in CompileLuaFuncs( IterateZipFiles(f) ) do
        if fileName:StartWith("lua/") then fileName = fileName:sub(5) end

        if fileName == "package.lua" then
            packageInfo = LoadPackageInfoFromFunc(func)
        else
            files[fileName] = func
        end
    end

    f:Close()

    if not packageInfo then return ErrorNoHaltWithStack("package.lua not found") end
    if not packageInfo.main or not files[packageInfo.main] then return ErrorNoHaltWithStack("no main file provided") end

    packageInfo.ImportedFrom = "ZIP"
    packageInfo.ImportedExtra = nil

    local main = files[ packageInfo.main ]
    return gpm.package.InitializePackage( packageInfo, main, files )
end

LocalFilesFinderMeta = LocalFilesFinderMeta or {}
LocalFilesFinderMeta.__index = function(self, fileName)
    if isstring(fileName) and fileName:EndsWith(".lua") and file.Exists(fileName, LUA_REALM) then
        self[fileName] = CompileFile(fileName) -- Caching result
        return self[fileName]
    end
end

function ImportLocal(fileName)
    local packageFileName = fileName:EndsWith("package.lua") and fileName
    if not packageFileName then packageFileName = fileName .. "/package.lua" end
    if not file.Exists(packageFileName, LUA_REALM) then return ErrorNoHaltWithStack("file not found") end

    local packageInfo = LoadPackageInfoFromFunc( CompileFile(packageFileName) )
    if not packageInfo then return ErrorNoHaltWithStack("invalid package.lua") end

    local mainFile = packageInfo.main and file.Exists(packageInfo.main, LUA_REALM) and CompileFile(packageInfo.main, "package.lua")
    if not mainFile then return ErrorNoHaltWithStack("failed to include main file") end

    AddCSLuaFile(packageFileName)
    AddCSLuaFile(packageInfo.main)

    local files = setmetatable({}, LocalFilesFinderMeta)
    files[packageInfo.main] = mainFile

    packageInfo.ImportedFrom = "Local"
    packageInfo.ImportedExtra = nil

    return gpm.package.InitializePackage( packageInfo, mainFile, files )
end

AsyncImport = promise.Async(function( fileName)
    if fileName:StartWith("data/") then
        if fileName:EndsWith(".zip.dat") then
            return ImportZIP(fileName)
        elseif filename:EndsWith(".gma.dat") then
            print("ToDo") -- ToDo
        end
    elseif fileName:StartWith("lua/") then
        fileName = fileName:sub(5)
        return ImportLocal(fileName)
    end
end )

function import( fileName, async )
    ArgAssert( fileName, 1, "string" )
    assert( async or promise.RunningInAsync(), "import supposed to be running in coroutine/async function (do you running it from package)" )

    local p = AsyncImport( fileName )
    if not async then return p:Await() end
    return p
end

_G.import = import

-- Tests
if false then return end

local Test = promise.Async(function(...)

    --local test = import "data/test.zip.dat"


    local mypkg = import "lua/packages/mypkg"
    mypkg.HelloWorld()

end)

concommand.Add("imp", function()
    Test()
    -- coroutine.wrap(function()
    --     xpcall(function()
    --         --import "lua/packages/mypkg"
    --         if CLIENT then
    --             import "data/test.zip.dat"
    --         end
    --     end, ErrorNoHaltWithStack)
    -- end)()
end)

