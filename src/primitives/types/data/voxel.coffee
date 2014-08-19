Data = require './data'
Util = require '../../../util'

class Voxel extends Data
  @traits: ['node', 'data', 'source', 'voxel']

  constructor: (node, context, helpers) ->
    super node, context, helpers

    @buffer = @spec = null
    @filled = false

    @space =
      width:  0
      height: 0
      depth:  0

    @used =
      width:  0
      height: 0
      depth:  0

  sourceShader: (shader) ->
    @buffer.shader shader

  getDimensions: () ->
    space = @space

    items:  @items
    width:  space.width
    height: space.height
    depth:  space.depth

  getActive: () ->
    used = @used

    items:  @items
    width:  used.width
    height: used.height
    depth:  used.depth * @buffer.getFilled()

  make: () ->
    super

    # Read given dimensions
    width    = @_get 'voxel.width'
    height   = @_get 'voxel.height'
    depth    = @_get 'voxel.depth'
    channels = @_get 'data.dimensions'
    items    = @_get 'data.items'

    dims = @spec =
      channels: channels
      items:    items
      width:    width
      height:   height
      depth:    depth

    @items    = dims.items
    @channels = dims.channels

    # Init to right size if data supplied
    data = @_get 'data.data'
    dims = Util.Data.getDimensions data, dims

    space = @space
    space.width  = Math.max space.width,  dims.width  || 1
    space.height = Math.max space.height, dims.height || 1
    space.depth  = Math.max space.depth,  dims.depth  || 1

    # Create voxel buffer
    @buffer = @_renderables.make 'voxelBuffer',
              width:    space.width
              height:   space.height
              depth:    space.depth
              channels: channels
              items:    items

    # Notify of buffer reallocation
    @trigger
      type: 'rebuild'

  unmake: () ->
    super
    if @buffer
      @buffer.dispose()
      @buffer = null

  change: (changed, touched, init) ->
    @rebuild() if touched['voxel'] or changed['data.dimensions']

    return unless @buffer

    if changed['data.expression']? or
       init

      @buffer.callback = @callback @_get 'data.expression'

  update: () ->
    return unless @buffer
    return unless !@filled or @_get 'data.live'

    data = @_get 'data.data'

    space    = @space
    used     = @used
    filled   = @buffer.getFilled()

    w = used.width
    h = used.height
    d = used.depth

    if data?
      dims = Util.Data.getDimensions data, @spec
      if dims.width  < spec.width  or
         dims.height < spec.height or
         dims.depth  < spec.depth
        @rebuild()

      @buffer.callback = getThunk data

      used.width  = dims.width
      used.height = dims.height
      used.depth  = dims.depth

    else
      length = @buffer.update()

      used.width  = w = space.width
      used.height = h = space.height
      used.depth  = Math.ceil length / w / h

    if used.width  != w or
       used.height != h or
       used.depth  != d or
       filled != @buffer.getFilled()
      @trigger
        type: 'resize'

    @filled = true

module.exports = Voxel