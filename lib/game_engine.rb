class GameEngine
  class Error < StandardError; end
  class IllegalMove < Error; end
  class OutOfTurn < Error; end

  def self.run(options = {}, &block)
    Go::GTP.run_gnugo do |gtp|
      gtp.boardsize(options[:board_size]) unless options[:board_size].to_s.empty?
      gtp.fixed_handicap(options[:handicap]) if options[:handicap].to_i.nonzero?
      gtp.komi(options[:komi]) unless options[:komi].to_s.empty?
      yield GameEngine.new(gtp, options)
    end
  end

  def initialize(gtp, options = {})
    @resigned = nil
    @gtp = gtp
    @board_size = options[:board_size] || 19
    @handicap = options[:handicap] || 0
  end

  def replay(moves)
    colors = [:black, :white].cycle
    colors.next if first_color.to_sym == :white
    moves.to_s.split("-").each do |move|
      play(colors.next, (move =~ /[A-Z]/ ? move : move[0..1]))
    end
  end

  def play(color, vertex)
    if vertex == "RESIGN"
      @resigned = color
    else
      @gtp.play(color, gnugo_point(vertex))
    end
    raise IllegalMove unless @gtp.success?
  end

  def move(color, vertex = nil)
    raise IllegalMove if over?
    if %w[PASS RESIGN].include? vertex
      play(color, vertex)
      vertex
    else
      other_stones = @gtp.list_stones(opposite(color))
      if vertex
        play(color, vertex)
      else
        vertex = sgf_point(@gtp.genmove(color))
        @resigned = color if vertex == "RESIGN"
      end
      captured = other_stones - @gtp.list_stones(opposite(color))
      sgf_point(vertex) + captured.map { |v| sgf_point(v) }.join
    end
  end

  def positions(color)
    @gtp.list_stones(color).map { |v| sgf_point(v) }.join
  end

  def captures(color)
    @gtp.captures(color)
  end

  def black_score
    score_for(:black)
  end

  def white_score
    score_for(:white)
  end

  def over?
    @resigned || @gtp.over?
  end

  def first_color
    @handicap > 0 ? :white : :black
  end

  private

  def score_for(color)
    if @resigned
      @resigned.to_sym == color.to_sym ? 0 : 1
    else
      @gtp.final_score[/^#{color.to_s[0].upcase}\+([\d\.]+)$/, 1].to_f
    end
  end

  def opposite(color)
    color.to_sym == :black ? :white : :black
  end

  def point(vertex)
    args = [vertex]
    if vertex =~ /\A[A-HJ-T](?:1\d|[1-9])\z/
      args << {:board_size => @board_size}
    end
    Go::GTP::Point.new(*args)
  end

  def gnugo_point(vertex)
    if %w[PASS RESIGN].include? vertex.to_s.upcase
      vertex.to_s.upcase
    else
      point(vertex).to_gnugo(@board_size)
    end
  end

  def sgf_point(vertex)
    if %w[PASS RESIGN].include? vertex.to_s.upcase
      vertex.to_s.upcase
    else
      point(vertex).to_sgf
    end
  end
end
