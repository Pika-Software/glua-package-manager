[![Lint](https://github.com/Pika-Software/glua_package_manager/actions/workflows/glualint-check.yml/badge.svg)](https://github.com/Pika-Software/glua_package_manager/actions/workflows/glualint-check.yml)

# GLua Package Manager
Package manager supporting isolation, synchronous import and package dependency building.

## Features
- Package information structure like [package.json](https://docs.npmjs.com/cli/v6/configuring-npm/package-json)
- Synchronous import of packages from different sources

## TODO
- [ ] Встраивать скрипты из zip файла в файловую систему с помощью gma генерации, для поддержки AddCSLuaFile
- [ ] Использование сжатия в пакетных файлах zip

## How to create your own package?
1. Create `package.lua` and `init.lua` files in directory `lua/packages/<your-package-name>/`.
2. Enter information about your package in `package.lua`, below is an example.
3. Write your code in `init.lua`, if you want the script to be only on the client or server, write in your `package.lua` additional lines `server` or `client`, an example below.

Also, you can run an existing addon via gpm, just add the code below to `package.lua`, and you don’t even need to add `init.lua`.
### package.lua example
```lua
-- The name of the package is just text that will be displayed in the format name@version, for example My Awesome Package@0.0.1
name = "My Awesome Package"

-- Version format { 00 } { 00 } { 00 } = 0.0.0
version = 000001

-- The `main` in this case is the entry point to the package (where the code execution will start from)
main = "path/to/my/code/main.lua"

-- Allows to run only on the server side. (default is true, true)
server = true
client = false

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

## License
[MIT](LICENSE) © Pika Software
