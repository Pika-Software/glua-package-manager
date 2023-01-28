
local CompileString = CompileString
local IterateZipFiles = gpm.unzip.IterateZipFiles

module("gpm.importer", package.seeall)

-- Example: gpm.importer.GetLuaFuncs( gpm.unzip.IterateZipFiles(fileHandle) )
function CompileLuaFuncs(iter)
    assert( iter )

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
    info.main = isstring(tbl.main) and tbl.main or nil

    return info
end

function LoadPackageInfoFromFunc(func)
    if isstring(func) then func = CompileString(func) end
    if not isfunction(func) then return end

    setfenv(func, {})
    return ParsePackageInfo(func())
end


function ImportZIP(pathToArchive)
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

    if not packageInfo then return ErrorNoHaltWithStack("bad zip") end
    if not packageInfo.main or not files[packageInfo.main] then return ErrorNoHaltWithStack("no main file provided") end

    local main = files[packageInfo.main]
    main()
end

function import(fileName)
    if fileName:StartWith("data/") then
        if fileName:EndsWith(".zip.dat") then
            return ImportZIP(fileName)
        elseif filename:EndsWith(".gma.dat") then
            print("ToDo") -- ToDo
        end
    end
end

_G.import = import

-- Tests
if false then return end

import "data/test.zip.dat"

