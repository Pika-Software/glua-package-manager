name = "package_v2"
autorun = true

dependencies = {
    ["abc"] = "^0.1.0",
    ["units"] = "github:Pika-Software/units"
}

exports = "./init.lua"

send = {
    "submodule.lua"
}
