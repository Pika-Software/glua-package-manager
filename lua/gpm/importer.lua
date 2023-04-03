-- Libraries
local packages = gpm.packages
local promise = gpm.promise
local string = string

-- Functions
local IterateZipFiles = gpm.unzip.IterateZipFiles
local CompileString = CompileString
local ArgAssert = ArgAssert

module( "gpm.importer", package.seeall )

local LUA_REALM = SERVER and "lsv" or "lcl"

-- Example: gpm.importer.GetLuaFuncs( gpm.unzip.IterateZipFiles(fileHandle) )
function CompileLuaFuncs( iter )
    ArgAssert( iter, 1, "function" )

    return function()
        local fileName, data
        repeat
            fileName, data = iter()
            if fileName and string.EndsWith( fileName, ".lua" ) then
                return fileName, CompileString( data or "", fileName )
            end
        until fileName == nil
    end
end

function ImportZIP( pathToArchive )
    local f
    if string.StartWith( pathToArchive, "data/" ) then
        f = file.Open( string.sub( pathToArchive, 6 ), "rb", "DATA")
    end

    if not f then return ErrorNoHaltWithStack( "file not found" ) end

    local packageInfo
    local files = {}
    for fileName, func in CompileLuaFuncs( IterateZipFiles( f ) ) do
        if string.StartWith( fileName, "lua/" ) then fileName = string.sub( fileName, 5 ) end

        if ( fileName == "package.lua" ) then
            packageInfo = packages.GetMetaData( func )
        else
            files[ fileName ] = func
        end
    end

    f:Close()

    if not packageInfo then return ErrorNoHaltWithStack( "package.lua not found" ) end
    if not packageInfo.main or not files[ packageInfo.main ] then
        return ErrorNoHaltWithStack( "no main file provided" )
    end

    packageInfo.ImportedFrom = "ZIP"
    packageInfo.ImportedExtra = nil

    local main = files[ packageInfo.main ]
    return gpm.packages.InitializePackage( packageInfo, main, files )
end

LocalFilesFinderMeta = LocalFilesFinderMeta or {}
LocalFilesFinderMeta.__index = function( self, fileName )
    if isstring( fileName ) and string.EndsWith( fileName, ".lua" ) and file.Exists( fileName, LUA_REALM ) then
        self[ fileName ] = CompileFile( fileName ) -- Caching result
        return self[ fileName ]
    end
end

function ImportLocal( fileName )
    local packageFileName = string.EndsWith( fileName, "package.lua" ) and fileName
    if not packageFileName then packageFileName = fileName .. "/package.lua" end
    if not file.Exists( packageFileName, LUA_REALM ) then return ErrorNoHaltWithStack( "file not found" ) end

    local packageInfo = packages.GetMetaData( CompileFile( packageFileName ) )
    if not packageInfo then return ErrorNoHaltWithStack( "invalid package.lua" ) end

    local mainFile = packageInfo.main and file.Exists( packageInfo.main, LUA_REALM ) and CompileFile( packageInfo.main, "package.lua" )
    if not mainFile then return ErrorNoHaltWithStack( "failed to include main file" ) end

    AddCSLuaFile( packageFileName )
    AddCSLuaFile( packageInfo.main )

    local files = setmetatable( {}, LocalFilesFinderMeta )
    files[ packageInfo.main ] = mainFile

    packageInfo.ImportedFrom = "Local"
    packageInfo.ImportedExtra = nil

    return gpm.packages.InitializePackage( packageInfo, mainFile, files )
end

AsyncImport = promise.Async(function( fileName)
    if string.StartWith( fileName, "data/" ) then
        if string.EndsWith( fileName, ".zip.dat" ) then
            return ImportZIP( fileName )
        elseif string.EndsWith( filename, ".gma.dat" ) then
            print( "ToDo" ) -- ToDo
        end
    elseif string.StartWith( fileName, "lua/" ) then
        fileName = string.sub( fileName, 5 )
        return gpm.sources.lua.Import( fileName )
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

