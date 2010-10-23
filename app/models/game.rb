class Game < ActiveRecord::Base
  #################
  ### Callbacks ###
  #################

  after_save :generate_thumbnail, :if => :update_thumbnail

  def generate_thumbnail
    GameThumb.generate(id, board_size, black_positions, white_positions) unless Rails.env.test?
  end

  ####################
  ### Associations ###
  ####################

  belongs_to :black_player,   :class_name => "User"
  belongs_to :white_player,   :class_name => "User"
  belongs_to :current_player, :class_name => "User"

  ###################
  ### Validations ###
  ###################

  attr_accessible :komi, :handicap, :board_size, :chosen_color, :chosen_opponent, :opponent_username

  validates_inclusion_of :board_size, :in => [9, 13, 19],     :allow_nil => true
  validates_inclusion_of :handicap,   :in => (0..9).to_a,     :allow_nil => true
  validates_inclusion_of :komi,       :in => [0.5, 5.5, 6.5], :allow_nil => true
  validate               :opponent_found

  def opponent_found
    if chosen_opponent == "user" && (black_player.blank? || white_player.blank?)
      errors.add(:opponent_username, "not found")
    end
  end

  ##############
  ### Scopes ###
  ##############

  scope :finished,   where("finished_at is not null")
  scope :unfinished, where("finished_at is null")
  scope :recent,     order("updated_at desc")

  ########################
  ### Instance Methods ###
  ########################

  attr_accessor :chosen_color, :creator, :chosen_opponent, :opponent_username, :update_thumbnail

  def black_positions_list
    if black_positions && @black_positions_list && @black_positions_list.size != black_positions.size / 2
      @black_positions_list = nil
    end
    @black_positions_list ||= black_positions.to_s.scan(/[a-s]{2}/)
  end

  def white_positions_list
    if white_positions && @white_positions_list && @white_positions_list.size != white_positions.size / 2
      @white_positions_list = nil
    end
    @white_positions_list ||= white_positions.to_s.scan(/[a-s]{2}/)
  end

  # todo: This method needs to be tested better
  def prepare
    opponent = nil
    if chosen_opponent == "user"
      opponent = User.find_by_username(opponent_username)
    end
    color = chosen_color.blank? ? %w[black white].sample : chosen_color
    case color
    when "black"
      self.black_player = creator
      self.white_player = opponent
    when "white"
      self.black_player = opponent
      self.white_player = creator
    end
    GameEngine.run(attributes.symbolize_keys) do |engine|
      if handicap.to_i.nonzero?
        self.black_positions = engine.positions(:black)
        self.current_player = white_player
      else
        self.current_player = black_player
      end
    end
    self.update_thumbnail = true
  end

  # todo: This method needs to be tested better
  def move(position, user)
    raise GameEngine::OutOfTurn if user.try(:id) != current_player_id
    GameEngine.update_game_attributes_with_move(attributes.symbolize_keys, position).each do |name, value|
      self.send("#{name}=", value)
    end
    self.update_thumbnail = true # todo: this could be made smarter
    # Check current_player again, fetching from database to prevent async double move problem
    # This should probably be moved into a database lock so no updates happen between here and the save
    raise GameEngine::OutOfTurn if user.try(:id) != Game.find(id, :select => "current_player_id").current_player_id
    save!
  end

  def queue_computer_move
    if !finished? && !current_player
      if PRIVATE_CONFIG["background_process"] && !Rails.env.test?
        Stalker.enqueue("Game.move", :id => id)
      else
        move(nil, nil)
      end
    end
  end

  def moves_after(index)
    (moves.to_s.split('-')[index..-1] || []).join('-')
  end

  def last_move
    moves.to_s.split("-").last.to_s
  end

  def last_position
    last_move[/^[a-s]{2}/]
  end

  def finished?
    finished_at
  end

  def profile_for(color)
    Profile.new(color).tap do |profile|
      if color.to_sym == :white
        profile.handicap_or_komi = "#{komi} komi"
      else
        profile.handicap_or_komi = "#{handicap} handicap"
      end
      profile.score = send("#{color}_score")
      profile.user = send("#{color}_player")
      if profile.user == current_player
        profile.current = true
      else
        case last_move
        when "PASS" then profile.last_status = "passed"
        when "RESIGN" then profile.last_status = "resigned"
        end
      end
    end
  end

  def profiles
    [profile_for(:white), profile_for(:black)]
  end

  def profiles_with_current_first
    profiles.sort_by { |p| p.current ? 0 : 1 }
  end
end
