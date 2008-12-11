require 'rubygems'
require 'gosu'
require 'pp'

class ZOrder
  Background, Board, Shape = 0, 1, 2
end

SHAPE_PATTERNS = eval(IO.read('shapes.txt'))

class Array
  #iterate non-zero cell
  def each_cell_n
    each_cell do |x,y,val|
      yield x,y,val if val.nonzero?
    end
  end

  def each_cell
    for y in 0...self.size
      row = self[y]
      for x in 0...row.size
        cell = row[x]
        yield  x, y, cell
      end
    end
  end
end

class Shape
  attr_accessor :x, :y
#   attr_accessor :grids

  def initialize(board, img, grids)
    @board = board
    @image = img
    
    @x = Board::Columns/2 - 2
    @y = 0

    @grids = grids
    @rotate = 0
  end

  def fixed
    @grids[@rotate].each_cell_n do |x, y, val|
      #using arr.dup for assignment for ruby's bug(?)
      row = @board.cells[@y+y].dup
      row[@x+x] = val
      @board.cells[@y+y] = row
    end
    #    pp  @board.cells
  end
  
  def columns
    max = 0
    @grids[@rotate].each_cell_n do |x,y|
      max = x if x > max
    end
    max
  end

  def adjoint(dir)
    @grids[@rotate].each_cell_n do |x,y|
      case dir
      when :bottom
        return true if @y+y+1 >= Board::Rows
        return true unless @board.cells[@y+y+1][@x+x] and @board.cells[@y+y+1][@x+x].zero?
      when :left
        return true if @x+x == 0
        return true unless @board.cells[@y+y][@x+x-1].zero?
      when :right
        return true if @x+x+1 >= Board::Columns
        return true unless @board.cells[@y+y][@x+x+1] and @board.cells[@y+y][@x+x+1].zero?
      end
    end

    return false
  end

  def overlap
    @grids[@rotate].each_cell_n do |x,y|
      return true unless @board.cells[@y+y][@x+x].zero?
    end
  end

  def drop
    unless adjoint(:bottom)
      @y += 1
    end
  end

  def move_left
    unless adjoint(:left)
      @x -= 1
    end
  end

  def move_right
    unless adjoint(:right)
      @x += 1
    end
  end

  def rotate
    @rotate += 1
    @rotate %= 4

    #check if out of border
    n = @x + self.columns - Board::Columns
    @x -= (n+1) if n >= 0
  end

  def draw
    @grids[@rotate].each_cell_n do |x, y, val|
      @image.draw((@x+x)*@image.width, (@y+y)*@image.height, ZOrder::Shape)
    end
  end
end

class Board
  Columns = 12
  Rows = 18
  
  attr_accessor :cells
  
  def initialize(img, columns, rows)
    @image = img
    
    @cells = [[0]*Columns]*Rows
    #    @cells[-1] = [1]*@width
  end

  def check_full
    for y in 0...@cells.size
      row = @cells[y]
      if row.all?{ |val| val.nonzero?} 
        y.downto(1){ |i| @cells[i] = @cells[i-1].dup }
        @cells[0] = Array.new(Columns, 0)
      end
    end
  end

  def draw
    @cells.each_cell_n do |x,y|
      @image.draw(x*@image.width, y*@image.height, ZOrder::Board)
    end
  end
end

class GameWindow < Gosu::Window
  InitInterval = 10
  Pixels = 25
  
  def initialize
    super((Board::Columns+6) * Pixels, Board::Rows * Pixels, false) 
    self.caption = "Tetris"
    
    @image = Gosu::Image.new(self, "block.png")

    @ticks = 0
    @interval = 5
    @drop_ticks = 0
    @drop_interval = InitInterval

    @pause = false

    @running = true
    self.start
  end

  def start
    @board = Board.new(@image, Board::Columns, Board::Rows)
    @next_shape = random_shape
    shape_shift
  end
  
  def random_shape
    s = Shape.new(@board, @image, SHAPE_PATTERNS[rand(7)])

    #init shape in preview area
    s.x = Board::Columns + (self.width / @image.width - Board::Columns - s.columns) / 2 
    s.y = 1
    s
  end

  def shape_shift
    @shape = @next_shape
    @shape.x = Board::Columns / 2 - 2
    @shape.y = 0
    @next_shape = random_shape
  end

  def shape_fixed
    @shape.fixed
    @board.check_full

    shape_shift   
    @action = nil
  end
  
  def update
    return if @pause or !@running

    if @ticks >= @interval
      case @action
      when :rotate
        @shape.rotate
        @action = nil
      when :left
        @shape.move_left
      when :right
        @shape.move_right
      when :speedup
        @drop_interval = 1
        @action = nil
      when :speednormal
        @drop_interval = InitInterval
        @action = nil
      end

      if @drop_ticks >= @drop_interval
        if @shape.adjoint(:bottom)
          shape_fixed
        else
          @shape.drop
        end
        @drop_ticks = 0
      end
      @drop_ticks += 1
      
      @ticks = 0
    end
    @ticks += 1
  end

  def draw_border
    x = @image.width*Board::Columns
    y = @image.width*Board::Rows
    c = Gosu.yellow
    #   cc = Gosu.red
    draw_line(x, 0, c, x, y, c, ZOrder::Background)
  end
  
  def draw
    draw_border

    if @running 
      @board.draw
      @shape.draw
      @next_shape.draw
    end
  end
  
  def button_down(id)
    close if id == Gosu::Button::KbEscape
    @pause = !@pause if id == Gosu::Button::KbSpace 
    return if @pause

    case id
    when Gosu::Button::KbUp
      @action = :rotate
    when Gosu::Button::KbLeft
      @action = :left
    when Gosu::Button::KbRight
      @action = :right
    when Gosu::Button::KbDown
      @action = :speedup
    when Gosu::Button::KbF1
      @running = !@running
      start if @running
    end
  end

  def button_up(id)
    case id
    when Gosu::Button::KbDown
      @action = :speednormal
    when Gosu::Button::KbLeft
      @action = nil
    when Gosu::Button::KbRight
      @action = nil
    when Gosu::Button::KbDown
      @action = nil
    end
  end
  
end

if $0 == __FILE__
  win = GameWindow.new
  win.show
end
