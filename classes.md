## How to use this class system:

### 1. Define base class (basically a metatable for our cars)

```lua
---@class dreamwork.std.Car : dreamwork.std.Object           <-- do not forget to inherit from dreamwork.std.Object
---@field __class dreamwork.std.CarClass
local Car = class.base( "Car" )

---@alias Car dreamwork.std.Car                        <-- alias Car, so it is easier for us to reference it in params and etc.

---@protected               <-- do not forget to add protected so __init won't be shown
function Car:__init()
    self.speed = 0
    self.color = 0xFF0000
end
```

### 2. Define a class, which will be used to create a Car

```lua
--- [SHARED AND MENU] <-- dont forget specify realm where your class avalible
---
--- The class used to create new `Car` instances.
---
---@class dreamwork.std.CarClass : dreamwork.std.Car      <-- do not forget to inherit from base
---@field __base dreamwork.std.Car
---@overload fun(): dreamwork.std.Car
local CarClass = class.create( Car )
std.Car = CarClass
```

### 3. Create a new car

```lua
local car = std.Car()
print( car.__name ) -- Car
print( std.Car.__name == car.__name ) -- true
print( car.speed ) -- 0
```

### 4. Inherit from the Car class

```lua
---@class dreamwork.std.Truck : dreamwork.std.Car
---@field __class dreamwork.std.TruckClass
---@field __parent dreamwork.std.Car               <-- now we need to define the parent, so LuaLS can know how to access our parent
local Truck = class.base( "Truck", false, std.Car )

---@alias Truck dreamwork.std.Truck

--- [SHARED AND MENU]
---
--- The class used to create new `Truck` instances.
---
---@class dreamwork.std.TruckClass : dreamwork.std.Truck
---@field __base dreamwork.std.Truck
---@field __parent dreamwork.std.CarClass
---@overload fun(): dreamwork.std.Truck
local TruckClass = class.create( Truck )
std.Truck = TruckClass
```

## Class Template

```lua

---@class dreamwork.std.Template : dreamwork.std.Object
---@field __class dreamwork.std.TemplateClass
local Template = class.base( "Template" )

---@alias Template dreamwork.std.Template

---@protected
function Template:__init()

end

--- [SHARED AND MENU]
---
--- The class used to create new `Template` instances.
---
---@class dreamwork.std.TemplateClass : dreamwork.std.Template
---@field __base dreamwork.std.Template
---@overload fun(): dreamwork.std.Template
local TemplateClass = class.create( Template )
std.Template = TemplateClass

---@class dreamwork.std.TemplateChild : dreamwork.std.Template
---@field __class dreamwork.std.TemplateChildClass
---@field __parent dreamwork.std.Template
local TemplateChild = class.base( "TemplateChild", false, std.Template )

---@alias TemplateChild dreamwork.std.TemplateChild

--- [SHARED AND MENU]
---
--- The class used to create new `TemplateChild` instances.
---
---@class dreamwork.std.TemplateChildClass : dreamwork.std.TemplateChild
---@field __base dreamwork.std.TemplateChild
---@field __parent dreamwork.std.TemplateClass
---@overload fun(): TemplateChild
local TemplateChildClass = class.create( TemplateChild )
std.TemplateChild = TemplateChildClass

```
