# ![GLua Package Manager](https://i.imgur.com/w454Ms1.png?1)

[![Lint](https://github.com/Pika-Software/glua_package_manager/actions/workflows/glualint-check.yml/badge.svg)](https://github.com/Pika-Software/glua_package_manager/actions/workflows/glualint-check.yml)
## Features
- Package information structure like [package.json](https://docs.npmjs.com/cli/v6/configuring-npm/package-json)
- Package dependencies support

## TODO
- [ ] Concommands
- [ ] Package registry with package verification
- [x] Package enviroment isolation
- [ ] Встраивать скрипты из zip файла в файловую систему с помощью gma генерации, для поддержки AddCSLuaFile
- [ ] Использование сжатия в пакетных файлах zip

## How to create your own package?
1. Create `package.lua` and `main.lua` files in directory `lua/packages/<your-package-name>/`.
2. Enter information about your package in `package.lua` (See [package.lua](package.lua.md)), or just write `return {}`.
3. Write your code in `main.lua`, this is shared file, so you can write serverside and clientside code.

Also, you can run an existing addon via gpm, just add the code below to `package.lua`, and you don’t even need to add `init.lua`.
```lua
-- package.lua
return {
    -- gpm will run the specified file instead of init.lua
    main = "path/to/my/code/main.lua",
}
```

## License
[MIT](LICENSE) © Pika Software
