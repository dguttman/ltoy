require 'ruby-processing'

include Math

class Fixnum
  def to_rad
    self * 2*Math::PI/360
  end
end

class Float
  def to_rad
    self * 2*Math::PI/360
  end
end

module RpCommon
  
  def init_color
    background 0
    fill 255, 255
    stroke 255, 30 
  end
end


class Lsystem < Processing::App
  include RpCommon

  load_ruby_library "control_panel"


  def setup
    render_mode P3D
    @cx, @cy = width/2, height/2
    @lx, @ly = @cx, @cy
    init_color
    
    setup_buffer
    @x, @y = @bw/2, @bh/2
    
    @stroke_r, @stroke_g, @stroke_b = 255, 255, 255
    @stroke_w = 1
    @stroke_a = 255
    frame_rate 2000
    @alpha = 270

    @d = 5
    @tree = Tree.new(self)
    setup_program
    do_cp
    execute_program
  end
  
  def setup_buffer
    @bw, @bh = 1500, 1500
    
    @pg = createGraphics(@bw, @bh, JAVA2D)
    @pg.begin_draw
    @pg.fill 0
    @pg.stroke 0
    
    # @pg.stroke_weight 5
    # @pg.stroke 255, 0, 0, 255
    @pg.rect 0, 0, @bw, @bh
    @pg.end_draw
  end
  
  
  def do_cp
    control_panel do |c|
      c.slider :delta, 0..360, @delta
      c.slider :d, 0..50, @d
      c.slider :stroke_r, 0..255, @stroke_r
      c.slider :stroke_g, 0..255, @stroke_g
      c.slider :stroke_b, 0..255, @stroke_b
      c.slider :stroke_a, 0..255, @stroke_a
      c.slider :stroke_w, 0..10, @stroke_w
    end
  end
  
  def initial_condition
    @initial_condition
  end
  
  def set_initial_condition(condition_str)
    @initial_condition = condition_str.split('')
  end
  
  def add_rule(rule, &command)
    @rules ||= {}
    @rules[rule] = command
  end
  
  def move_forward
    x0, y0 = @x % @bw, @y % @bh
    nx0 = (@x / @bw).floor
    ny0 = (@y / @bh).floor
    
    @x += @d * Math.cos(@alpha.to_rad)
    @y += @d * Math.sin(@alpha.to_rad)
    
    x1, y1 = @x % @bw, @y % @bh
    nx1 = (@x / @bw).floor
    ny1 = (@y / @bh).floor
    
    @pg.begin_draw
    @pg.stroke @stroke_r, @stroke_g, @stroke_b, @stroke_a
    @pg.stroke_weight @stroke_w
    @pg.line x0, y0, x1, y1 if nx1 == nx0 && ny1 == ny0
    @pg.end_draw
  end
  
  def turn_left
    @alpha += @delta
  end
  
  def turn_right
    @alpha -= @delta
  end
  
  def push_state
    @pos_stack ||= []
    state = {:x => @x, :y => @y, :alpha => @alpha}
    @pos_stack.push(state)
  end
  
  def pop_state
    state = @pos_stack.pop
    @x, @y, @alpha = state[:x], state[:y], state[:alpha]
  end
  
  def draw
    background 0
    
    @i ||= 0
    command = @current_program[@i]
    @rules[command].call(true)
    @i += 1
    
    @i = 0 if @i >= @current_program.length
    
    if @mouse_look
      mouse_camera
    else
      auto_camera
    end
    
  end

  def mouse_camera
    lx0, ly0 = @lx, @ly
    
    lx1 = (@cx - @x)
    ly1 = (@cy - @y)
    
    lx = lx0 - @mx
    ly = ly0 - @my
    
    @mx, @my = 0, 0
    
    @lx = lx
    @ly = ly
    
    lx %= @bw
    ly %= @bh
    
    image @pg, lx, ly
    image @pg, lx - @bw, ly - @bh
    image @pg, lx - @bw, ly
    image @pg, lx, ly - @bh    
  end

  def auto_camera
    lx0, ly0 = @lx, @ly
    
    lx1 = (@cx - @x)
    ly1 = (@cy - @y)
    
    lx = (lx0*19 + lx1)/20.0
    ly = (ly0*19 + ly1)/20.0
    
    @lx = lx
    @ly = ly
    
    lx %= @bw
    ly %= @bh
    
    image @pg, lx, ly
    image @pg, lx - @bw, ly - @bh
    image @pg, lx - @bw, ly
    image @pg, lx, ly - @bh

  end
  
  def screen_cap_timestamp
    timestamp = Time.now.strftime("%Y.%m.%d.%H.%M.%S")
    p timestamp
    # save_frame("screencaps/#{timestamp}.png")
    @pg.save("../../#{timestamp}.png")
  end

  def key_pressed
    if key == 'p'
      screen_cap_timestamp
    end
    if key == 'l'
      load_program('l1')
    end
    if %w(1 2 3 4 5 6 7 8 9 0).include? key
      load_program("l#{key}")
    end
  end

  def mouse_pressed
    @mouse_look = true
    @mxi = mouse_x
    @myi = mouse_y
    @mx, @my = 0,0
  end
  
  def mouse_released
    @mouse_look = false
  end
  
  def mouse_dragged
    @mouse_look = true
    @mx = 3*(@mxi - mouse_x)
    @my = 3*(@myi - mouse_y)
    @mxi, @myi = mouse_x, mouse_y
  end

  def setup_program
    @n = 5
    @delta = 25.7

    set_initial_condition 'F'
    
    add_rule('F') do |m|
      move_forward if m
      @next_program += 'F[+F]F[-F]F'
    end
    
    add_rule('L') do |m| 
      move_forward if m
      @next_program += 'L+R+'
    end
    
    add_rule('R') do |m| 
      move_forward if m
      @next_program += '-L-'
    end
    
    add_rule('-') { |m| turn_left if m; @next_program += '-' }
    
    add_rule('+') { |m| turn_right if m; @next_program += '+' }
    
    add_rule('[') { |m| push_state if m; @next_program += '['}
    
    add_rule(']') { |m| pop_state if m; @next_program += ']'}
  end
  
  def load_program(filename)
    filename = "../../#{filename}"
    unless File.exists?(filename)
      p "no file #{filename}"
      return
    end
    File.open(filename, "r") do |f|
      f.readlines.each do |line|
        param, value = line.split(":")[0], line.split(":")[1].chomp
        case param
        when 'n'
          @n = value.to_i
        when 'delta'
          @delta = value.to_i
        when 'ic'
          set_initial_condition value
        else
          add_rule(param) do |m|
            move_forward if m
            @next_program += value
          end
        end
      end
    end
    @i = 0
    @alpha = 270
    @pg.begin_draw
    @pg.stroke 0
    @pg.fill 0
    @pg.rect 0,0,@bw, @bh
    @pg.end_draw
    @tree = Tree.new(self)
    execute_program
  end
  
  def execute_program
    @next_program = ''
    @current_program = @initial_condition
    (0..@n).each do |i|
      @current_program.each do |command|
        @rules[command].call(false)
        @tree.add_node(:x => @x, :y => @y) if i == @n
      end
      @current_program = @next_program.split('')
      @next_program = ''
    end
    @tree.draw
  end
  
end

class Node
  
  attr_reader :x, :y
  attr_accessor :children, :parent
  
  def initialize(app, opts)
    @app = app
    @x = opts[:x]
    @y = opts[:y]
    @parent = opts[:parent]
    @children = opts[:children]
    @children ||= []
  end
  
  def draw
    x0, y0 = @x, @y
    @children.each do |child|
      x1, y1 = child.x, child.y
      @app.line x0, y0, x1, y1
    end
    @app.ellipse x0, y0, 2, 2
  end
  
end

class Tree
  
  def initialize(app, nodes=[])
    @app = app
    @nodes = nodes
  end
  
  def add_node(opts)
    @nodes << Node.new(@app, opts)
  end
  
  def draw
    @nodes.each do |node|
      node.draw
    end
  end
  
end



Lsystem.new :title => "Lsystem", :width => 500, :height => 500