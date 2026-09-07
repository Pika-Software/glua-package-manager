---@class dreamwork.std
local std = dreamwork.std
local len = std.len

local debug = std.debug
local debug_fempty = debug.fempty

---@diagnostic disable-next-line: undefined-global
local glua_render = render or {}

---@diagnostic disable-next-line: undefined-global
local glua_cam = cam or {}

--- [CLIENT]
---
--- The library with powerful set of functions that let you control how the world and its contents are rendered.
---
--- It can also be used to draw some 3D client-side effects such as beams, boxes and spheres.
---
---@class dreamwork.std.gfx3d
---@field PixelShaders1 boolean `true` if the current settings and the system allow the usage of pixel shaders 1.4, `false` otherwise.
---@field PixelShaders2 boolean `true` if the current settings and the system allow the usage of pixel shaders 2.0, `false` otherwise.
---@field VertexShaders boolean `true` if the current settings and the system allow the usage of vertex shaders 1.1, `false` otherwise.
---@field DirectX number The supported DirectX level, 8 for DX8, 9 for DX9, 10 for DX10, 11 for DX11.
---@field HDR boolean `true` if the current settings and the system allow the usage of HDR, `false` otherwise.
local gfx3d = std.gfx3d or {}
std.gfx3d = gfx3d

gfx3d.PixelShaders1 = (glua_render.SupportsPixelShaders_1_4 or debug_fempty)() == true
gfx3d.PixelShaders2 = (glua_render.SupportsPixelShaders_2_0 or debug_fempty)() == true
gfx3d.VertexShaders = (glua_render.SupportsVertexShaders_2_0 or debug_fempty)() == true

do

    local directx_version = ((glua_render.GetDXLevel or debug_fempty)() or 80) * 0.1
    gfx3d.DirectX = directx_version
    gfx3d.HDR = directx_version >= 8

end

---@alias dreamwork.std.gfx3d.ModelFlags
---| 1 STUDIO_RENDER # The current render is for opaque renderables only.
---| 2 STUDIO_VIEWXFORMATTACHMENTS # Applies view-space transforms to model attachments (used for attachment positioning/rendering in view models).
---| 4 STUDIO_DRAWTRANSLUCENTSUBMODELS # The current render is for translucent renderables only.
---| 8 STUDIO_TWOPASS # The current render is for both opaque and translucent renderables.
---| 16 STUDIO_STATIC_LIGHTING # Uses precomputed/static lighting instead of dynamic lighting.
---| 32 STUDIO_WIREFRAME Renders the model in wireframe mode.
---| 64 STUDIO_ITEM_BLINK Enables blinking/item highlight effect.
---| 128 STUDIO_NOSHADOWS # Prevents the model from casting or receiving shadows.
---| 256 STUDIO_WIREFRAME_VCOLLIDE # Renders the vcollide/collision mesh in wireframe mode.
---| 1024 STUDIO_SKIP_FLEXES # Do not update/apply flexes.
---| 16777216 STUDIO_GENERATE_STATS # Not a studio flag, but used to flag when we want studio stats.
---| 134217728 STUDIO_SSAODEPTHTEXTURE # Not a studio flag, but used to flag model as using SSAO depth material override.
---| 268435456 STUDIO_SKIP_DECALS # Do not render decals.
---| 1073741824 STUDIO_SHADOWDEPTHTEXTURE # Not a studio flag, but used to flag model as using shadow depth material override.
---| 2147483648 STUDIO_TRANSPARENCY # Not a studio flag, but used to flag model as a non-sorting brush model.

-- TODO: add 3d render. functions

-- ref: https://github.com/luttje/glua-api-snippets/blob/lua-language-server-addon/library/render.lua
-- ref: https://github.com/luttje/glua-api-snippets/blob/lua-language-server-addon/library/cam.lua

gfx3d.clear = glua_render.Clear or debug_fempty

do

    local cam_Start3D2D = glua_cam.Start3D2D or debug_fempty
    local cam_Start = glua_cam.Start or debug_fempty

    ---@class dreamwork.std.gfx3d.RenderView.offcenter
    ---@field left number Where the left edge starts, natural value is `0`.
    ---@field right number Where the right edge ends, natural value is equal to `w` (the width of the viewport).
    ---@field bottom number Where the bottom edge starts, natural value is `0`.
    ---@field top number Where the top edge ends, natural value is equal to `h` (the height of the viewport).

    ---@class dreamwork.std.gfx3d.RenderView
    ---@field origin Vector3 | nil The position to render from.
    ---@field angles Angle3 | nil The angles to render from.
    ---@field fov integer | nil The field of view of the view port.
    ---@field x integer | nil The x position of the view port
    ---@field y integer | nil The y position of the view port
    ---@field w integer | nil The width of the view port.
    ---@field h integer | nil The height of the view port.
    ---@field znear number | nil The distance to the near clipping plane.
    ---@field zfar number | nil The distance to the far clipping plane.
    ---@field aspect number | nil The aspect ratio of the view port (Note that this is NOT set to `w/h` by default).
    ---@field subrect boolean | nil Allow draw into a subrect of the larger screen.
    ---@field bloomtone boolean | nil Controlls default engine bloom, tonemapping and "brightness changes" on HDR maps.
    ---@field offcenter dreamwork.std.gfx3d.RenderView.offcenter | nil Controlls what portion of the screen to draw.

    local str_3d = "3D"

    --- [CLIENT]
    ---
    ---
    ---
    ---@param view dreamwork.std.gfx3d.RenderView
    function gfx3d.start( view )
        ---@diagnostic disable-next-line: cast-type-mismatch
        ---@cast view RenderCamData
        view.type = str_3d
        cam_Start( view )
    end

    gfx3d.stop = glua_cam.End3D or debug_fempty

    --- [CLIENT]
    ---
    ---
    ---
    ---@param origin Vector3
    ---@param angles Angle3
    ---@param scale number
    function gfx3d.start2d( origin, angles, scale )
        cam_Start3D2D( origin, angles, scale )
    end

    gfx3d.stop2d = glua_cam.End3D2D or debug_fempty

end

--- capture
--
-- glua_render.Capture
-- glua_render.CapturePixels
--

--- light
--
-- glua_render.SetLightmapTexture
--
--

--- material
--
-- glua_render.BrushMaterialOverride
-- glua_render.SetMaterial

do

    local render_DrawSprite = glua_render.DrawSprite

    function gfx3d.drawSprite()

    end

    local render_DrawBeam = glua_render.DrawBeam

    --- [CLIENT]
    ---
    ---
    ---
    ---@param start_position Vector3
    ---@param end_position Vector3
    ---@param width number
    ---@param texture_end number
    ---@param color dreamwork.std.Color
    function gfx3d.drawBeam( start_position, end_position, width, texture_start, texture_end, color, alpha )
        -- render_DrawBeam( start_position, end_position, width, texture_start, texture_end, color, alpha )
    end

    local render_DrawWireframeBox = glua_render.DrawWireframeBox
    local render_DrawBox = glua_render.DrawBox

    function gfx3d.drawBox()

    end

    local render_DrawLine = glua_render.DrawLine

    function gfx3d.drawLine()

    end

    local render_DrawWireframeSphere = glua_render.DrawWireframeSphere
    local render_DrawSphere = glua_render.DrawSphere

    function gfx3d.drawSphere()

    end

    -- glua_render.DrawQuad
    -- glua_render.DrawQuadEasy

end

do

    local render_StartBeam = glua_render.StartBeam
    local render_AddBeam = glua_render.AddBeam
    local render_EndBeam = glua_render.EndBeam

    ---@class dreamwork.std.gfx3d.ComplexBeamSegment
    ---@field origin Vector3
    ---@field width number
    ---@field texture_end number
    ---@field color dreamwork.std.Color

    --- [CLIENT]
    ---
    ---
    ---
    ---@param segments dreamwork.std.gfx3d.ComplexBeamSegment[]
    function gfx3d.drawComplexBeam( segments, segment_count )
        if segment_count == nil then
            segment_count = len( segments )
        end

        render_StartBeam( segment_count )

        for i = 1, segment_count do
            local segment = segments[ i ]
            -- render_AddBeam( segment.origin, segment.width, segment.texture_end, segment.color )
        end

        render_EndBeam()
    end

end


-- TODO: rewrite this crap into normat push/pop scissor call https://gitlab.com/DBotThePony/DLib/-/blob/develop/lua_src/dlib/extensions/render.lua?ref_type=heads
