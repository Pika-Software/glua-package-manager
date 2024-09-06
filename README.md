## Import protocols
- `file:` files from `/` directory
- `lua:` files from `/lua/` directory
- `http:`, `https:` fetch from internet
- `dll:` hostname is binary module name `/lua/bin/`
- `github:` same as `https:` but uses GitHub Rest API

### Examples
- `github://apiKey@user/repository/branch` (download and mount branch to file system)
- `github://apiKey@user/repository/branch/path/to/my/file.lua` (lua, yue, moon will be compiled, json will returned as table, other formats will be returned as string)

### TODO
* concommands
* send in packages
* client package sending
