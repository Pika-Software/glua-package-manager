[![Lint](https://github.com/Pika-Software/glua_package_manager/actions/workflows/glualint-check.yml/badge.svg)](https://github.com/Pika-Software/glua_package_manager/actions/workflows/glualint-check.yml)

# GLua Package Manager
Package manager supporting isolation, synchronous import, package dependency building and more.

## Features
- Package information structure like [package.json](https://docs.npmjs.com/cli/v6/configuring-npm/package-json)
- Synchronous import of packages from different sources

## How to improve?
For better speed and reliability, the following binary modules can be installed in the game:
- [async_write](https://github.com/WilliamVenner/gm_async_write)
- [gmsv_reqwest](https://github.com/WilliamVenner/gmsv_reqwest)
- [chttp](https://github.com/timschumi/gmod-chttp)

## How to create your own package?
1. Create `package.lua` and `init.lua` files in directory `lua/packages/<your-package-name>/`.
2. Enter information about your package in `package.lua`, below is an example.
3. Write your code in `init.lua`, if you want the script to be only on the client or server, write in your `package.lua` additional lines `server` or `client`, an example below.

Also, you can run an existing addon via gpm, just add the code below to `package.lua`, and you don’t even need to add `init.lua`.
### package.lua example
```lua
-- The name of the package is just text that will be displayed in the format name@version, for example My Awesome Package@0.0.1
name = "My Awesome Package"

-- Author is an optional field, it is just a field with text that can be read.
author = "Awesome Guy"

-- Version format { 00 } { 00 } { 00 } = 0.0.0
version = 000001

-- The `main` in this case is the entry point to the package (where the code execution will start from)
main = "path/to/my/code/main.lua"

-- Allows to run only on the server side. (default is true, true)
server = true
client = false

-- Allows you to disable packet isolation, I don't know why you need it, but it's there. ( def. true )
isolation = true

-- Should automatically run the package ( works only with packages from lua folders )
autorun = false

-- Disables the creation of the package logger, if you do not need it you can disable it. ( def. true )
logger = true
```
This file can also contain any other additional information such as package author, license or description.

### `import` function usage example
Here is an example of the use of import in the init.lua file of the package.
```lua
-- pkg1 init.lua
import "packages/pkg2"

print( package2.feature() )
```
Look for more examples in our code ;)

## Todo
- [ ] add in zip source compression support
- [ ] zip source
- [ ] github source
- [ ] http zip source support

## License
[MIT](LICENSE) © Pika Software
