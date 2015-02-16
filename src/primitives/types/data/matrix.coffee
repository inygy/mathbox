Data = require './data'
Util = require '../../../util'

class Matrix extends Data
  @traits = ['node', 'data', 'source', 'texture', 'matrix']

  init: () ->
    @buffer = @spec = @emitter = null
    @filled = false

    @space =
      width:   0
      height:  0
      history: 0

    @used =
      width:   0
      height:  0

  sourceShader: (shader) ->
    @buffer.shader shader

  getDimensions: () ->
    space = @space

    items:  @items
    width:  space.width
    height: space.height
    depth:  space.history

  getActive: () ->
    used = @used

    items:  @items
    width:  used.width
    height: used.height
    depth:  @buffer.getFilled()

  make: () ->
    super

    # Read sampling parameters
    minFilter = @_get 'texture.minFilter'
    magFilter = @_get 'texture.magFilter'
    type      = @_get 'texture.type'

    # Read given dimensions
    width    = @_get 'matrix.width'
    height   = @_get 'matrix.height'
    history  = @_get 'matrix.history'
    reserveX = @_get 'matrix.bufferWidth'
    reserveY = @_get 'matrix.bufferHeight'
    channels = @_get 'data.dimensions'
    items    = @_get 'data.items'

    dims = @spec =
      channels: channels
      items:    items
      width:    width
      height:   height
      depth:    history

    @items    = dims.items
    @channels = dims.channels

    # Init to right size if data supplied
    data = @_get 'data.data'
    dims = Util.Data.getDimensions data, dims

    space = @space
    space.width   = Math.max reserveX, dims.width  || 1
    space.height  = Math.max reserveY, dims.height || 1
    space.history = history

    # Create matrix buffer
    @buffer = @_renderables.make 'matrixBuffer',
              width:     space.width
              height:    space.height
              history:   space.history
              channels:  channels
              items:     items
              minFilter: minFilter
              magFilter: magFilter
              type:      type

    # Create data thunk to copy (multi-)array if bound to one
    if data?
      thunk    = Util.Data.getThunk    data
      @emitter = Util.Data.makeEmitter thunk, items, channels, 2

  unmake: () ->
    super
    if @buffer
      @buffer.dispose()
      @buffer = @spec = @emitter = null

  change: (changed, touched, init) ->
    return @rebuild() if touched['texture'] or
                         changed['matrix.history'] or
                         changed['data.dimensions'] or
                         changed['matrix.bufferWidth'] or
                         changed['matrix.bufferHeight']

    return unless @buffer

    if changed['matrix.width']
      width = @_get 'matrix.width'
      return @rebuild() if width  > @space.width

    if changed['matrix.height']
      height = @_get 'matrix.height'
      return @rebuild() if height > @space.height

    if changed['data.expression'] or
       changed['data.data'] or
       init

      emitter = @emitter
      data = @_get 'data.data'
      if !data?
        emitter = @callback @_get 'data.expression'
      @buffer.setCallback emitter

  callback: (callback) -> Util.Data.normalizeEmitter emitter, 2

  update: () ->
    return unless @buffer
    return unless !@filled or @_get 'data.live'

    data = @_get 'data.data'

    space    = @space
    used     = @used
    filled   = @buffer.getFilled()

    w = used.width
    h = used.height

    if data?
      dims = Util.Data.getDimensions data, @spec
      rebuild = false

      # Grow width if needed
      if dims.width > space.width
        rebuild = true

        # Size up by 200%, up to 128 increase.
        length = space.width
        step   = Math.min 128, length

        # But always at least size to fit
        space.width = Math.max length + step, dims.width

      # Grow height if needed
      if dims.height > space.height
        rebuild = true

        # Size up by 200%, up to 128 increase.
        length = space.height
        step   = Math.min 128, length

        # But always at least size to fit
        space.height = Math.max length + step, dims.height

      @rebuild() if rebuild

      used.width  = dims.width
      used.height = dims.height

      @buffer.setActive used.width, used.height
      @buffer.callback.rebind data
      @buffer.update()
    else
      @buffer.setActive @spec.width, @spec.height

      length = @buffer.update()

      used.width  = _w = @spec.width
      used.height = Math.ceil length / _w

    @filled = true

    if used.width  != w or
       used.height != h or
       filled != @buffer.getFilled()
      @trigger
        type: 'source.resize'

module.exports = Matrix
