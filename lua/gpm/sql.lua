local _G = _G
local gpm = _G.gpm
local environment, Logger = gpm.environment, gpm.Logger
local argument, istable, isnumber, isstring, isfunction, SQLError, throw = environment.argument, environment.istable, environment.isnumber, environment.isstring, environment.isfunction, environment.SQLError, environment.throw
local len, find
do
	local _obj_0 = environment.string
	len, find = _obj_0.len, _obj_0.find
end
local time
do
	local _obj_0 = environment.os
	time = _obj_0.time
end
local sql = _G.rawget(gpm, "sql")
if not istable(sql) then
	sql = _G.setmetatable({ }, {
		__index = environment.sql
	})
	gpm.sql = sql
end
local queryOne, queryValue, rawQuery, query, transaction
do
	local _obj_0 = environment.sql
	queryOne, queryValue, rawQuery, query, transaction = _obj_0.queryOne, _obj_0.queryValue, _obj_0.rawQuery, _obj_0.query, _obj_0.transaction
end
-- http_cache table, used for etag caching in http library
do
	local http_cache = { }
	sql.http_cache = http_cache
	http_cache.get = function(url)
		argument(url, 1, "string")
		return queryOne("select etag, content from 'gpm.http_cache' where url=? limit 1", url)
	end
	local MAX_SIZE = 50 * 1024
	http_cache.MAX_SIZE = MAX_SIZE
	http_cache.set = function(url, etag, content)
		argument(url, 1, "string")
		argument(etag, 2, "string")
		argument(content, 3, "string")
		if len(content) > MAX_SIZE then
			-- do not cache content that are larger than MAX_SIZE
			return nil
		end
		if find(content, "\x00", 1, true) then
			-- we are unable to store null bytes in sqlite
			return nil
		end
		query("insert or replace into 'gpm.http_cache' (url, etag, timestamp, content) values (?, ?, ?, ?)", url, etag, time(), content)
		return nil
	end
end
-- key-value store for gpm
do
	local store = { }
	sql.store = store
	store.set = function(key, value)
		argument(key, 1, "string")
		query("insert or replace into 'gpm.store' values (?, ?)", key, value)
		return nil
	end
	store.get = function(key)
		argument(key, 1, "string")
		return queryValue("select value from 'gpm.store' where key=?", key)
	end
end
--- repositories
if SERVER then
	local repositories = { }
	sql.repositories = repositories
	repositories.getRepositories = function()
		return query("select * from 'gpm.repositories'") or { }
	end
	repositories.addRepository = function(url)
		argument(url, 1, "string")
		-- sadly gmod's sqlite does not support returning clause :(
		return queryOne("insert or ignore into 'gpm.repositories' (url) values (?); select * from 'gpm.repositories' where url=?", url, url)
	end
	local getRepositoryId
	getRepositoryId = function(repository)
		if istable(repository) then
			return repository.id or repository.url
		end
		if isnumber(repository) then
			return repository
		end
		if isstring(repository) then
			return queryValue("select id from 'gpm.repositories' where url=?", repository)
		end
		return nil
	end
	repositories.removeRepository = function(repository)
		local repositoryId = getRepositoryId(repository)
		if not repositoryId then
			throw(SQLError("invalid repository '" .. tostring(repository) .. "' was given as #1 argument"))
		end
		transaction(function()
			-- delete all versions, packages and repository
			local _list_0 = query("select id from 'gpm.packages' where repositoryId=?", repositoryId)
			for _index_0 = 1, #_list_0 do
				local package = _list_0[_index_0]
				local packageId = package.id
				query("delete from 'gpm.package_versions' where packageId=?; delete from 'gpm.packages' where id=?", packageId, packageId)
			end
			query("delete from 'gpm.repositories' where id=?", repositoryId)
			return nil
		end)
		return nil
	end
	repositories.getPackage = function(repository, name)
		argument(name, 2, "string")
		local repositoryId = getRepositoryId(repository)
		if not repositoryId then
			throw(SQLError("invalid repository '" .. tostring(repository) .. "' was given as #1 argument"))
		end
		local pkg = queryOne("select * from 'gpm.packages' where name=? and repositoryId=?", name, repositoryId)
		if pkg then
			pkg.versions = query("select version, metadata from 'gpm.package_versions' where packageId=?", pkg.id)
			return pkg
		end
		return nil
	end
	repositories.getPackages = function(repository)
		local repositoryId = getRepositoryId(repository)
		if not repositoryId then
			throw(SQLError("invalid repository '" .. tostring(repository) .. "' was given as #1 argument"))
		end
		local packages = query("select * from 'gpm.packages' where repositoryId=?", repositoryId) or { }
		-- fetch versions for each package
		for _index_0 = 1, #packages do
			local pkg = packages[_index_0]
			pkg.versions = query("select version, metadata from 'gpm.package_versions' where packageId=?", pkg.id)
		end
		return packages
	end
	repositories.updateRepository = function(repository, packages)
		argument(packages, 2, "table")
		local repositoryId = getRepositoryId(repository)
		if not repositoryId then
			throw(SQLError("invalid repository '" .. tostring(repository) .. "' was given as #1 argument"))
		end
		local oldPackages = query("select id, name from 'gpm.packages' where repositoryId=?", repositoryId) or { }
		for _index_0 = 1, #oldPackages do
			local pkg = oldPackages[_index_0]
			oldPackages[pkg.name] = pkg.id
		end
		return transaction(function()
			for name, pkg in pairs(packages) do
				query("insert or replace into 'gpm.packages' (name, url, type, repositoryId) values (?, ?, ?, ?)", pkg.name, pkg.url, pkg.type, repositoryId)
				local packageId = queryValue("select id from 'gpm.packages' where name=? and repositoryId=?", pkg.name, repositoryId)
				query("delete from 'gpm.package_versions' where packageId=?", packageId)
				local _list_0 = pkg.versions
				for _index_0 = 1, #_list_0 do
					local tbl = _list_0[_index_0]
					query("insert into 'gpm.package_versions' (version, metadata, packageId) values (?, ?, ?)", tbl.version, tbl.metadata, packageId)
				end
				oldPackages[name] = nil
			end
			-- remove old packages
			for name, id in pairs(oldPackages) do
				query("delete from 'gpm.package_versions' where packageId=?; delete from 'gpm.packages' where id=?", id, id)
			end
			return
		end)
	end
end
-- files
do
	local tonumber = _G.tonumber
	local files = { }
	sql.files = files
	files.save = function(path, size, seconds, hash)
		argument(path, 1, "string")
		argument(size, 2, "number")
		if seconds then
			argument(seconds, 3, "number")
		end
		if hash then
			argument(hash, 4, "string")
		end
		query("insert or replace into 'gpm.files' (path, size, time, hash) values (?, ?, ?, ?)", path, size, seconds, hash)
		return nil
	end
	files.get = function(path)
		argument(path, 1, "string")
		local result = queryOne("select * from 'gpm.files' where path=?", path)
		if result then
			result.size = tonumber(result.size, 10) or -1
			result.time = tonumber(result.time, 10)
			return result
		end
		return nil
	end
end
-- optimize sqlite database
if not sql.__optimized then
	local pragma_values = rawQuery("pragma foreign_keys; pragma journal_mode; pragma synchronous; pragma wal_autocheckpoint")
	if pragma_values[1].foreign_keys == "0" then
		rawQuery("pragma foreign_keys = 1")
	end
	if pragma_values[2].journal_mode == "delete" then
		rawQuery("pragma journal_mode = wal")
	end
	if pragma_values[3].synchronous == "0" then
		rawQuery("pragma synchronous = normal")
	end
	if pragma_values[4].wal_autocheckpoint == "1000" then
		rawQuery("pragma wal_autocheckpoint = 100")
	end
	sql.__optimized = true
end
-- truncate WAL journal on shutdown
_G.hook.Add("ShutDown", gpm.PREFIX .. "::SQLite", function()
	if _G.sql.Query("pragma wal_checkpoint(TRUNCATE)") == false then
		Logger:Error("Failed to truncate WAL journal: %s", _G.sql.LastError())
	end
	return nil
end)
local migrations = {
	{
		name = "initial",
		execute = function() end
	},
	{
		name = "http_cache add primary key",
		execute = function()
			rawQuery("drop table if exists 'gpm.http_cache'")
			rawQuery([[create table 'gpm.http_cache' (
                url text primary key,
                etag text,
                timestamp int,
                content blob
            )]])
			return nil
		end
	},
	{
		name = "added key-value store",
		execute = function()
			rawQuery("create table 'gpm.store' ( key text unique, value text )")
			return nil
		end
	},
	{
		name = "initial repositories and packages",
		execute = function()
			rawQuery("drop table if exists 'gpm.table_version'")
			rawQuery("drop table if exists 'gpm.repository'")
			rawQuery("drop table if exists 'gpm.packages'")
			if SERVER then
				rawQuery("create table 'gpm.repositories' ( id integer primary key autoincrement, url text unique not null )")
				rawQuery([[                    create table 'gpm.packages' (
                        id integer primary key autoincrement,
                        name text not null,
                        url text not null,
                        type int not null,
                        repositoryId integer,

                        foreign key(repositoryId) references 'gpm.repositories' (id)
                        unique(name, repositoryId) on conflict replace
                    )
                ]])
				rawQuery([[                    create table 'gpm.package_versions' (
                        version text not null,
                        metadata text,
                        packageId integer not null,

                        foreign key(packageId) references 'gpm.packages' (id)
                        unique(version, packageId) on conflict replace
                    )
                ]])
			end
			return nil
		end
	},
	{
		name = "initial file table",
		execute = function()
			return rawQuery([[                create table 'gpm.files' (
                    id integer primary key autoincrement,
                    path text not null unique,
                    size integer not null,
                    time number,
                    hash text
                )
            ]])
		end
	}
}
if not sql.tableExists("gpm.migration_history") then
	rawQuery("create table 'gpm.migration_history' (name text, timestamp integer)")
end
local migrationExists
migrationExists = function(name)
	for _index_0 = 1, #migrations do
		local migration = migrations[_index_0]
		if migration.name == name then
			return true
		end
	end
	return false
end
sql.migrationExists = migrationExists
local runMigration
runMigration = function(migration)
	if not isfunction(migration.execute) then
		throw(SQLError("Migration '" .. tostring(migration.name) .. "' does not have an execute function"))
	end
	Logger:Info("Running migration '" .. tostring(migration.name) .. "'...")
	local ok = xpcall(transaction, SQLError.display, migration.execute)
	if ok then
		query("insert into 'gpm.migration_history' (name, timestamp) values (?, ?)", migration.name, time())
	end
	return ok
end
sql.runMigration = runMigration
sql.migrate = function(name)
	if not isstring(name) then
		throw(SQLError("Migration name must be a string, not " .. tostring(name)))
	end
	local history = rawQuery("select name from 'gpm.migration_history'") or { }
	for _index_0 = 1, #history do
		local migration = history[_index_0]
		history[migration.name] = true
	end
	-- find if given migration name exists
	if not migrationExists(name) then
		throw(SQLError("Migration '" .. name .. "' not found"))
	end
	-- first execute migrations
	for _index_0 = 1, #migrations do
		local migration = migrations[_index_0]
		if not history[migration.name] then
			if runMigration(migration) == false then
				break
			end
		end
		if migration.name == name then
			break
		end
	end
	return nil
end
