[![Lint](https://github.com/Pika-Software/glua_package_manager/actions/workflows/glualint-check.yml/badge.svg)](https://github.com/Pika-Software/glua_package_manager/actions/workflows/glualint-check.yml)

# GLua Package Manager
Package manager supporting isolation, synchronous import, package dependency building and more.

## Features
- Package information structure like [package.json](https://docs.npmjs.com/cli/v6/configuring-npm/package-json)
- Synchronous import of packages from different sources

### Console commands
- `gpm_clear_cache` - Clears the cache of externally downloaded packages.
- `gpm_reload` - Restarts the package manager by refreshing its own code as well as reloading all packages.
- `gpm_list` - Prints a list of loaded packages in the console.

### Console variables
- `gpm_cache_lifetime` - Packages cache lifetime, in hours, sets after how many hours the downloaded gpm packages will not be relevant.
- `gpm_http_timeout` - Default http timeout for gpm http library.

## How to create your own package?
1. Create `package.lua` and `init.lua` files in directory `lua/packages/<your-package-name>/`.
2. Enter information about your package in `package.lua`, below is an example.
3. Write your code in `init.lua`, if you want the script to be only on the client or server, write in your `package.lua` additional lines `server` or `client`, an example below.

Also, you can run an existing addon via gpm, just add the code below to `package.lua`, and you don’t even need to add `init.lua`.

### `package.lua` example
```lua
-- lua/packages/example-package/package.lua
name = "example-package"
version = 000100

-- Files to be used as an entry point into the package, supports relative paths and global relative to "lua/"
init = {
    ["client"] = "cl_init.lua",
    ["server"] = "init.lua",
    ["menu"] = "init.lua"
}

-- If there is no autorun, the package will wait for import from another package
autorun = true

-- Don't touch it if you don't know what you're doing
environment = true

-- Client files ( supports relative paths and global paths by "lua/" )
send = {
    "file.lua",
    "my_addon/file2.lua"
}

-- If false, the logger will not be created by default and logs color
logger = false
color = Color( 255, 255, 0 )

-- Allowed gamemodes list, if nil then all gamemodes are allowed
gamemodes = {
    "sandbox",
    "darkrp"
}

-- Allowed maps list, if nil then all maps are allowed
maps = {
    "gm_construct"
}

-- If true, then the package is allowed to run only in a singleplayer game
singleplayer = false

-- Enables automatic naming for listed libraries, e.g. all hooks with hook = true will have a package identifier in the hook name, if the hook name is a string of course...
autonames = {
    ["properties"] = true,
    ["timer"] = true,
    ["cvars"] = true,
    ["hook"] = true,
    ["net"] = false
}

```

## Available package file parameters
- ### Package name (`name`) (def. `nil`)
    The name of the package is just text that will be displayed in the format `name@version`, for example `My Awesome Package@0.0.1`.

- ### Package version (`version`) (def. `nil`)
    By default, the version is a number whose format is { 00 } { 00 } { 00 } = 0.0.0, you can also use your own version format, just put your version here as a string.

- ### Package init (`init`)
    This is a universal parameter, which can be either a string or a table, in case it is a string, the package will run on both server and client and menu using the same initialization point, but if it is a table, it must contain parameters like ["realm"] = "path/to/init. lua", if any side is not specified then it won't be launched/sent, i.e. if we specify this value to {["server"] = "init.lua"} the package will only run on server and won't be sent to clients and also will not support menu realm.

    #### Example
    ```lua
        init = {
            ["server"] = "init.lua",
            ["client"] = "cl_init.lua"
        }
    ```

- ### Package autorun (`autorun`) (def. `false`)
    The default setting is `false`, if this parameter is set to `true` and the package is in a valid `lua/` directory, the package will automatically start and will not wait to be run externally.

- ### Package environment (`environment`) (def. `true`)
    This is the parameter responsible for environment, by default it is `true`, if it is set to `false` then the package will run in `_G` and all global values created in it will go to `_G`, as well as you will no longer have access to gpm environment features. I recommend to use this only if you really need it.

- ### Package send list (`send`) (def. `nil`)
    The list of files to send to the client, can be useful if the package runs exclusively on the client and has more than one file. (must be a table with indexes from 1 to infinity)

- ### Package logger (`logger`) (def. `false`)
    If set to `true` then a personal logger object will be created in the package environment, to easily send logs to the console. If necessary, you can create a logger object yourself, just call `gpm.CreateLogger( name, color )` (`name` is `string`, `color` is `Color`).

    #### Example usage
    ```lua
    local logger = gpm.Logger

    logger:Info( "My info message, this supports lua formatting like %s %f and other", "this", 0.025 )
    logger:Warn( "Warns!")
    logger:Error( "Errors!" )

    -- by default, they are only sent if the developer convar > 0
    logger:Debug( "Debug prings" )

    -- you can also set your own condition for debugging information
    logger:SetDebugFilter( function( str, ... )
        return true
    end )
    ```
    #### Result
    ![Console](https://i.imgur.com/FwScVHf.png)

- ### Package active gamemode (`gamemodes`) (def. `nil`)
    A string with a one gamemode or a list table with allowed gamemodes, if the current gamemode does not match any of the ones listed here the package will not run.

- ### Package current map (`maps`) (def. `nil`)
    A string with a map name or a list table with many map names, if the current map does not match any of the ones listed here the package will not run.

- ### Package singleplayer only (`singleplayer`) (def. `false`)
    The boolean value that allows the package to be executed only in a singleplayer game.

- ### Others
    This file can also contain any other additional information such as package author, license or description.

## Simple `import` function usage example
Here is an example of the use of import in the `init.lua` file of the package.
```lua
-- pkg1 init.lua
import "packages/pkg2"

print( package2.feature() )
```
Look for more examples in our code ;)

## How to improve?
For better speed and reliability, the following binary modules can be installed in the game:
- [gm_efsw](https://github.com/Pika-Software/gm_efsw) ⭐
- [gm_asyncio](https://github.com/Pika-Software/gm_asyncio) ⭐
- [gm_moonloader](https://github.com/Pika-Software/gm_moonloader) ⭐
- [gm_chttp](https://github.com/timschumi/gmod-chttp)
- [async_write](https://github.com/WilliamVenner/gm_async_write)
- [gmsv_reqwest](https://github.com/WilliamVenner/gmsv_reqwest)

In the near future we will release our own, better implemented binary modules to improve performance.

## License
[MIT](LICENSE) © Pika Software
