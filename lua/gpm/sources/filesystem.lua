local gpm = _G.gpm
local environment = gpm.environment
local await, SourceError = environment.await, environment.SourceError
local read
do
	local _obj_0 = environment.Package
	read = _obj_0.read
end
return environment.class("FileSource", {
	FetchInfo = environment.async(function(self, url)
		local package = await(read(url))
		if package then
			return {
				url = url,
				package = package
			}
		end
		error(SourceError("Failed to read or find package file for " .. url.href))
		return nil
	end)
}, nil, gpm.loader.Source)("file")
