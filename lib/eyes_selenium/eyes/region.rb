class Applitools::Region
  attr_accessor :left, :top, :width, :height

  def initialize(left, top, width, height)
    @left = left.round
    @top = top.round
    @width = width.round
    @height = height.round
  end

  EMPTY = Applitools::Region.new(0, 0, 0, 0)

  def make_empty
    @left = EMPTY.left
    @top = EMPTY.top
    @width = EMPTY.width
    @height = EMPTY.height
  end

  def empty?
     self.left == EMPTY.left && self.top == EMPTY.top && self.width == EMPTY.width && self.height == EMPTY.height
  end

  def right
    left + width
  end

  def bottom
    top + height
  end

  def intersecting?(other)
    ((left <= other.left && other.left <= right) || (other.left <= left && left <= other.right)) \
    && ((top <= other.top && other.top <= bottom) || (other.top <= top && top <=other.bottom))
  end

  def intersect(other)
    if !intersecting?(other)
      make_empty and return
    end
    i_left = (left >= other.left) ? left : other.left
    i_right = (right <= other.right) ? right : other.right
    i_top = (top >= other.top) ? top : other.top
    i_bottom = (bottom <= other.bottom) ? bottom : other.bottom

    self.left = i_left
    self.top = i_top
    self.width = i_right - i_left
    self.height = i_bottom - i_top
  end

  def contains?(other_left, other_top)
    other_left >= left && other_left <= right && \
    other_top >= top && other_top <= bottom
  end

  def middle_offset
    mid_x = width / 2
    mid_y = height / 2
    Selenium::WebDriver::Point.new(mid_x.round, mid_y.round)
  end

  def to_hash
    {
      left: left, top: top, height: height, width: width
    }
  end

  def to_s
    "(#{left}, #{top}), #{width} x #{height}"
  end
end
