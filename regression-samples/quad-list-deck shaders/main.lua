----------------------------------------------------------------
-- Copyright (c) 2010-2011 Zipline Games, Inc. 
-- All Rights Reserved. 
-- http://getmoai.com
----------------------------------------------------------------

MOAIDebugLines.setStyle ( MOAIDebugLines.PROP_MODEL_BOUNDS, 2, 1, 1, 1 )
MOAIDebugLines.setStyle ( MOAIDebugLines.PROP_WORLD_BOUNDS, 1, 0.5, 0.5, 0.5 )

-- just for readability
local RECT_XMIN		= 1
local RECT_YMIN		= 2
local RECT_XMAX		= 3
local RECT_YMAX		= 4

local sprites		= {}
local frames 		= {}
local shaders 		= {}

-- the vertex shader
local vsh = [[
attribute vec4 position;
attribute vec2 uv;
attribute vec4 color;
varying vec4 colorVarying;
varying vec2 uvVarying;

void main ()
{
	gl_Position = position;
	uvVarying = uv;
	colorVarying = color;
}
]]


-- the fragment shader
local fsh = [[
#ifdef GL_ES
precision highp float;
#endif

varying MEDP vec4 colorVarying;
varying vec2 uvVarying;
uniform sampler2D sampler;
uniform MEDP float colorMultiplier;

void main()
{
	vec4 color = texture2D ( sampler, uvVarying ) * colorVarying;
	gl_FragColor = vec4(color.rgb * colorMultiplier, color.a);
}
]]

function getShader(materialId)
	if shaders[materialId] then
		return shaders[materialId]
	end

	local program = MOAIShaderProgram.new ()
	
	program:reserveUniforms ( 1 )
	program:declareUniformFloat ( 1, 'colorMultiplier', 1.5)

	program:setVertexAttribute ( 1, 'position' )
	program:setVertexAttribute ( 2, 'uv' )
	program:setVertexAttribute ( 3, 'color' )
	
	program:load ( vsh, fsh )

	local shader = MOAIShader.new ()
	shader:setProgram ( program )

	shaders[materialId] = shader

	return shader
end

function loadAsset(basename)
	json = MOAIJsonParser.decode ( MOAIFileSystem.loadFile ( basename .. '.json' ))
	assert ( json )

	-- chunksize is the *maximum* size of an image tile.
	-- image tiles are laid out left to right and top to bottom, and all tiles chunksize
	-- *unless* they are along the right or bottom of the image *and* the image isn't
	-- an even multiple of chunksize
	local CHUNK_BLEED_MARGIN = json.chunkBleedMargin or 0
	local CHUNKSIZE = json.chunckSize and (json.chunkSize - 2 * CHUNK_BLEED_MARGIN) or 512

	-- image width and height. we only need these to detect the edge case when the image
	-- size is not a clean multiple of chunksize and the border tiles are therefore
	-- smaller than chunksize
	local WIDTH			= json.width
	local HEIGHT		= json.height

	local ANCHOR_X		= json.anchor and json.anchor.x or 0
	local ANCHOR_Y		= json.anchor and json.anchor.y or 0

	local uvRects		= {}
	local screenRects	= {}
	local materialIDs	= {}

	for i, tile in ipairs ( json.tiles ) do

		local tileObj = {
			uvRects = {},
			screenRects = {},
			chunks = {},
			shaderParams = {},
			left = 0,
			top = 0,
		}

		local cropRect	= tile.cropRect
		local padRect	= tile.paddingRect

		local xOff = ANCHOR_X + cropRect [ RECT_XMIN ] - padRect [ RECT_XMIN ]
		local yOff = ANCHOR_Y + cropRect [ RECT_YMIN ] - padRect [ RECT_YMIN ]

		local screenSub, screenSubWidth, screenSubHeight = MOAIGfxQuadListDeck2D.subdivideRect (

			CHUNKSIZE,
			CHUNKSIZE,

			cropRect [ RECT_XMIN ],
			cropRect [ RECT_YMIN ],
			cropRect [ RECT_XMAX ],
			cropRect [ RECT_YMAX ]
		)

		table.insert ( sprites, {
			base	= #materialIDs + 1,
			size	= #screenSub,
		})
		
		for i, screenRect in ipairs ( screenSub ) do

			print ( screenRect [ RECT_XMIN ], screenRect [ RECT_YMIN ], screenRect [ RECT_XMAX ], screenRect [ RECT_YMAX ])

			local xChunk = math.floor ( screenRect [ RECT_XMIN ] / CHUNKSIZE )
			local yChunk = math.floor ( screenRect [ RECT_YMIN ] / CHUNKSIZE )

			-- left, top coordinates of the tile in image space
			local xTile = xChunk * CHUNKSIZE
			local yTile = yChunk * CHUNKSIZE

			-- and here's the magic: if we're in a right or bottom tile, the dimensions of the *texture*
			-- may not be chunksize, so when we bring the rect into UV space we'll need to divide through
			-- by the actual tile dimensions and not chunksize
			local chunkWidth	= (( WIDTH - xTile ) < CHUNKSIZE ) and ( WIDTH - xTile ) or CHUNKSIZE
			local chunkHeight	= (( HEIGHT - yTile ) < CHUNKSIZE ) and ( HEIGHT - yTile ) or CHUNKSIZE

			-- to get the UV coordinates, just divide through by the actual chunk dimensions
			local uvRect = {
				[ RECT_XMIN ]	= ( screenRect [ RECT_XMIN ] - xTile  + CHUNK_BLEED_MARGIN) / chunkWidth,
				[ RECT_YMIN ]	= ( screenRect [ RECT_YMIN ] - yTile  + CHUNK_BLEED_MARGIN) / chunkHeight,
				[ RECT_XMAX ]	= ( screenRect [ RECT_XMAX ] - xTile  - CHUNK_BLEED_MARGIN) / chunkWidth,
				[ RECT_YMAX ]	= ( screenRect [ RECT_YMAX ] - yTile  - CHUNK_BLEED_MARGIN) / chunkHeight,
			}

			screenRect [ RECT_XMIN ] = screenRect [ RECT_XMIN ] - xOff
			screenRect [ RECT_YMIN ] = screenRect [ RECT_YMIN ] - yOff
			screenRect [ RECT_XMAX ] = screenRect [ RECT_XMAX ] - xOff
			screenRect [ RECT_YMAX ] = screenRect [ RECT_YMAX ] - yOff

			screenRect [ RECT_YMIN ] = screenRect [ RECT_YMIN ] * -1
			screenRect [ RECT_YMAX ] = screenRect [ RECT_YMAX ] * -1

			local WIDTH_IN_CHUNKS = math.ceil ( json.width / CHUNKSIZE )
			local materialID = ( xChunk + ( yChunk * WIDTH_IN_CHUNKS )) + 1

			tileObj.shaderParams[materialID] = {
				xOrg = xTile - cropRect[ RECT_XMIN ] - CHUNK_BLEED_MARGIN,
				yOrg = yTile - cropRect[ RECT_YMIN ] - CHUNK_BLEED_MARGIN,
				width = cropRect[ RECT_XMAX ] - cropRect[ RECT_XMIN ] - 2 * CHUNK_BLEED_MARGIN,
				height = cropRect[ RECT_YMAX ] - cropRect[ RECT_YMIN ] - 2 * CHUNK_BLEED_MARGIN,
				chunkWidth = chunkWidth,
				chunkHeight = chunkHeight,
				defaultChunkSize = CHUNKSIZE
			}

			table.insert(tileObj.uvRects, uvRect)
			-- print("inserting uvRect", MOAIJsonParser.encode(uvRect))
			table.insert(tileObj.screenRects, screenRect)
			-- print("inserting screenRect", MOAIJsonParser.encode(screenRect))
			if not (screenRect [ RECT_XMAX] - screenRect [ RECT_XMIN] <= 0
				or screenRect [ RECT_YMAX] - screenRect [ RECT_YMIN] <= 0 ) then
				table.insert(tileObj.chunks, materialID - 1)
				-- print("inserting chunk", materialID - 1)
			end

			table.insert ( uvRects, uvRect )
			table.insert ( screenRects, screenRect )
			table.insert ( materialIDs, materialID )
		end
		table.insert(frames, tileObj)
	end

	gfxQuadListDeck = MOAIGfxQuadListDeck2D.new ()

	-- we're going to init the textures with filenames to enable reloading and
	-- prevent caching of image data
	gfxQuadListDeck:reserveMaterials ( 2 )

	local loadAsBitmap = function ( filename )

		local image = MOAIImage.new ()
		image:load ( filename )
		image:resize ( 128, 128 )
		image:simpleThreshold ( 1, 1, 1, 0.5 )
		image:convert ( MOAIImage.COLOR_FMT_A_1 )
		return image
	end

	local maxCols = math.ceil(json.width / CHUNKSIZE)
	local maxRows = math.ceil(json.height / CHUNKSIZE)

	local fileCount = maxCols * maxRows

	local extension = ".png"
	-- reload the images one by one and generate bitmaps from their alpha
	-- ideally, these will be pre-generated and stored alongside the png's
	for i=1, fileCount do

		local zeroBasedIdx = i - 1
		local imageFilename = basename .. "." .. zeroBasedIdx .. extension

		-- Make sure the file exists!  If it does not, MOAITexture.load fails silently.
		assert(MOAIFileSystem.checkFileExists(imageFilename), "Texture._loadChunk: missing file '" .. imageFilename .. "'")
		print("load", imageFilename)
		gfxQuadListDeck:setTexture ( i, imageFilename )
		gfxQuadListDeck:setHitMask ( i, loadAsBitmap ( imageFilename ))
		gfxQuadListDeck:setHitMaskThreshold ( i, 0, 0, 0, 1 )
	end

	local totalRects = #materialIDs

	gfxQuadListDeck:reserveUVQuads ( totalRects)
	gfxQuadListDeck:reserveQuads ( totalRects )
	gfxQuadListDeck:reservePairs ( totalRects )

	for i = 1, totalRects do

		local uvRect = uvRects [ i ]
		local screenRect = screenRects [ i ]

		print ( 'uv rect', i, uvRect [ RECT_XMIN ], uvRect [ RECT_YMIN ], uvRect [ RECT_XMAX ], uvRect [ RECT_YMAX ])
		print ( 'screen rect', i, " --", screenRect [ RECT_XMIN ], screenRect [ RECT_YMIN ], screenRect [ RECT_XMAX ], screenRect [ RECT_YMAX ])

		gfxQuadListDeck:setUVRect ( i,
			uvRect [ RECT_XMIN ],
			uvRect [ RECT_YMIN ],
			uvRect [ RECT_XMAX ],
			uvRect [ RECT_YMAX ]
		)

		gfxQuadListDeck:setRect ( i,
			screenRect [ RECT_XMIN ],
			screenRect [ RECT_YMIN ],
			screenRect [ RECT_XMAX ],
			screenRect [ RECT_YMAX ]
		)

		gfxQuadListDeck:setPair ( i, i, i, materialIDs [ i ])
	end

	gfxQuadListDeck:reserveLists ( #sprites )
	for i, sprite in ipairs ( sprites ) do
		gfxQuadListDeck:setList ( i, sprite.base, sprite.size )
	end

	----------------------------------------------------------------

	prop = MOAIProp2D.new ()
	prop:setDeck ( gfxQuadListDeck )
	prop:setHitGranularity ( MOAIProp.HIT_TEST_FINE )
	layer:insertProp ( prop )

	return prop
end

function setFrame(index)
	local shaderParams = frames[index].shaderParams
	if shaderParams then
		for materialId, param in pairs(shaderParams) do

			prop:setShader(materialId, getShader(materialId))
		end
	end
	prop:setIndex ( index )
	label:setString ( tostring(index) )
end

index = 1

function onMouseEvent ( down, delta )

	if down == true then

		local x, y = MOAIInputMgr.device.pointer:getLoc ()
		x, y = layer:wndToWorld ( x, y )
		-- if prop:inside ( x, y ) then

			if delta > 0 then
				index = ( index % #sprites ) + 1
			elseif delta < 0 then
				index = index - 1
				index = index <= 0 and #sprites or index
			end
			
			setFrame(index)

		-- end
	end
end

MOAIInputMgr.device.mouseLeft:setCallback ( function ( down ) onMouseEvent ( down, 1 ) end )
MOAIInputMgr.device.mouseRight:setCallback ( function ( down ) onMouseEvent ( down, -1 ) end )

MOAISim.openWindow ( "test", 320, 480 )

viewport = MOAIViewport.new ()
viewport:setSize ( 320, 480 )
viewport:setScale ( 320, 480 )

layer = MOAILayer2D.new ()
layer:setViewport ( viewport )
MOAISim.pushRenderPass ( layer )


font = MOAIFont.new ()
font:loadFromTTF ( 'r/arial-rounded.TTF' )

label = MOAITextLabel.new ()
label:setString ( '' )
label:setFont ( font )
label:setTextSize ( 32 )
label:setYFlip ( true )
label:setAlignment ( MOAITextBox.CENTER_JUSTIFY, MOAITextBox.BASELINE_JUSTIFY )
label:setLoc ( 0, -220 )
layer:insertProp ( label )

-- animation with horizontal tiles in texture files
loadAsset('r/running_julius')

-- animation with vertical tiles in texture files
-- loadAsset('r/worry_bear_run_left')

-- single frame smallest than the tile size
--loadAsset('r/worry_bear_idle')

-- single, small rectangle (smaller than chunk size)
--loadAsset('r/rect')

-- single, large rectangle (bigger than chunk size, uses non-square blocks)
-- a 720x720 image, with a 512 input chunkSize, will be cut in 4 pieces (from top left to bottom right)
-- the conditioner works like this: 720 % 512 = 208. What's the nearest upper pow2 for 208? 256
-- 512x512     256x512
-- 512x256     256x256
-- loadAsset('r/rect2'):setScl ( .25, .25 )

setFrame(1)

