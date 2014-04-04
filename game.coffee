########################
#
# Input Controller
#
########################

class InputController
  constructor: ->
    document.onkeydown = @on_keydown.bind(this)
    document.onkeyup = @on_keyup.bind(this)
    @key_bindings = {}
    @keys_down = {}
    @keys_pressed = {}
    @keys_released = []
    @keys = 
      TAB: 9
      ENTER: 13
      ESC: 27
      SPACE: 32
      LEFT_ARROW: 37
      UP_ARROW: 38
      RIGHT_ARROW: 39
      DOWN_ARROW: 40
    for c in [65..90]
      @keys[String.fromCharCode c] = c

  event_code_for_event: (e) ->
    if e.type == 'keydown' or e.type == 'keyup'
      e.keyCode

  bind_key_to_action: (key_name, action) ->
    key = @keys[key_name]
    @key_bindings[key] = action

  on_keydown: (e) ->
    action = @key_bindings[@event_code_for_event e]
    return unless action

    @keys_pressed[action] = true unless @keys_down[action]
    @keys_down[action] = true

    e.stopPropagation()
    e.preventDefault()

  on_keyup: (e) ->
    action = @key_bindings[@event_code_for_event e]
    return unless action
    @keys_released.push action
    e.stopPropagation()
    e.preventDefault()

  clear_pressed_keys: ->
    for action in @keys_released
      @keys_down[action] = false
    @keys_released = []
    @keys_pressed = {}

  is_pressed: (action) -> @keys_pressed[action]
  is_down: (action) -> @keys_down[action]
  is_released: (action) -> (action in @keys_released)


########################
#
# Game Engine
#
########################

class GameEngine
  constructor: (delay=20) ->
    @input = new InputController()
    @last_dt = 
    @delay = delay

    @request_animation_frame =  window.requestAnimationFrame or
      window.webkitRequestAnimationFrame or
      window.mozRequestAnimationFrame or
      window.oRequestAnimationFrame or
      window.msRequestAnimationFrame or
      (callback) ->
        window.setTimeout((-> callback 1000 / 60), 1000 / 60)

  update: (dt) ->
  render: ->

  run: ->
    return if @running
    @running = true
    raf = @request_animation_frame
    s = =>
      return unless @running
      @step()
      raf s
    @last_step = Date.now()
    raf s

  stop: ->
    @running = false

  step: ->
    now = Date.now()
    dt = (now - @last_step) 
    @last_step = now
    
    # Slow down the game
    if @last_dt < @delay
      @last_dt += dt
      return
    else
      @last_dt = 0
      @update(dt)
      @render()
    
    @input.clear_pressed_keys()
    

########################
#
# Physical Object
#
########################

class PhysicalObject

  constructor: ->
    @gravity = 0.3
    @velocity = {X:0, Y:0}
    @position = {X:10, Y:10}
    @is_on_ground = false

  hit_the_ceiling: ->
    @position.Y <= 0

  update_position:(dt) ->

    # Don't fall through the ground
    if @is_on_ground
      @velocity.Y = 0.0

    @position.Y += @velocity.Y  # update position
    @velocity.Y += @gravity     # update velocity

    # Don't go through the roof
    if @hit_the_ceiling()
      @position.Y = 0
      @velocity.Y = @gravity

  start_jump: ->
    if @is_on_ground
      @velocity.Y = -3.0
      @is_on_ground = false

  end_jump: ->
    max = -0.5
    if @velocity.Y < max
      @velocity.Y = max


########################
#
# The Game
#
########################

class Game extends GameEngine

  constructor: (delay, level) ->
    super
    @input.bind_key_to_action 'SPACE', 'jump'
    @input.bind_key_to_action 'UP_ARROW', 'jump'

    @canvas = document.getElementById("canvas")
    @tilemap = @parse_level level
    @player = new PhysicalObject()


  parse_level: (string) ->
    max_length = 0 

    # Parse the string into a 2d array
    pixel_map = string.split("\n").map(
      (row) ->
        max_length = row.length if row.length > max_length
        row.split("")
    )
    # Fill up undefined pixels with blank ones
    for row in pixel_map
      for i in [0..max_length]
        row[i] = " " if row[i] == undefined

    return pixel_map

  move_camera: (dir) ->
    switch dir
      when "right"
        @tilemap.map (a) ->  a.push(a.shift())
      when "left"
        @tilemap.map (a) ->  a.unshift(a.pop())
      # when "up"
      #   @tilemap.unshift(@tilemap.pop())
      # when "down"
      #   @tilemap.push(@tilemap.shift())

  update:(dt) ->        

    if @input.is_pressed 'jump'
      @player.start_jump()
    if @input.is_released 'jump'
      @player.end_jump()

    old_y = Math.round(@player.position.Y)                              # current player position
    @player.update_position(dt)                                       # calculate new player position
    new_y = Math.min Math.round(@player.position.Y), @tilemap.length-1  # ensure new player position is within the level bounds

    @move_camera "right"

    # Fall onto platforms from the top
    if new_y > old_y                                # if the player is falling down (not jumping up)
      for y in [new_y..old_y]                       # check all tiles between new and old postition (vertically)
        if @tilemap[y][@player.position.X] != " "   # if one of them is solid, put the player ontop
          @player.is_on_ground = true
          @player.position.Y = y-1

    # Fall off platforms when they end        
    if new_y == old_y and @player.is_on_ground          # if the player isn't jump or falling
      if @tilemap[old_y+1][@player.position.X] == " "   # if the tile below the player isn't solid
        @player.is_on_ground = false                    # start falling


  render: ->
    buffer = @tilemap.map((ar)-> ar.slice())                        # clone tilemap
    buffer[Math.round(@player.position.Y)][@player.position.X] = "@"  # inject player
    @canvas.innerHTML = buffer.map((el) -> el.join("")).join("\n")  # throw it on screen


#######################
#
# Init
#
########################

level = """






                                                                              xxxxxxxxxxxxxxxx xxxxxxxxxx  xxxxxxxxxxx    xxxxxxxxxx     xxxxx




                                       xxxxxxxxxxxxxxxx                                       



                                                            xxxxxxxxxxxxxxx

                                  xxxxxxxxx



                                                            xxxxxxxxxxxxxxx

                                  xxxxxxxxx
          
  xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  

"""

game = new Game(20 ,level)
game.run()
