
-- local promise = gpm.promise

-- module( "gpm.sources.zip", package.seeall )

-- Import = promise.Async( function(path)
--     return promise.Reject("not implemented")
-- end )

-- local IterateZipFiles = gpm.unzip.IterateZipFiles

-- -- Example: gpm.importer.GetLuaFuncs( gpm.unzip.IterateZipFiles(fileHandle) )
-- function CompileLuaFuncs( iter )
--     ArgAssert( iter, 1, "function" )

--     return function()
--         local fileName, data
--         repeat
--             fileName, data = iter()
--             if fileName and string.EndsWith( fileName, ".lua" ) then
--                 return fileName, CompileString( data or "", fileName )
--             end
--         until fileName == nil
--     end
-- end

-- function ImportZIP( pathToArchive )
--     local f
--     if string.StartWith( pathToArchive, "data/" ) then
--         f = file.Open( string.sub( pathToArchive, 6 ), "rb", "DATA")
--     end

--     if not f then return ErrorNoHaltWithStack( "file not found" ) end

--     local packageInfo
--     local files = {}
--     for fileName, func in CompileLuaFuncs( IterateZipFiles( f ) ) do
--         if string.StartWith( fileName, "lua/" ) then fileName = string.sub( fileName, 5 ) end

--         if ( fileName == "package.lua" ) then
--             packageInfo = package.GetMetaData( func )
--         else
--             files[ fileName ] = func
--         end
--     end

--     f:Close()

--     if not packageInfo then return ErrorNoHaltWithStack( "package.lua not found" ) end
--     if not packageInfo.main or not files[ packageInfo.main ] then
--         return ErrorNoHaltWithStack( "no main file provided" )
--     end

--     packageInfo.ImportedFrom = "ZIP"
--     packageInfo.ImportedExtra = nil

--     local main = files[ packageInfo.main ]
--     return gpm.package.InitializePackage( packageInfo, main, files )
-- end