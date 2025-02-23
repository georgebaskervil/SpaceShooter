# frozen_string_literal: true

require 'gosu'

# Bullet class for efficient attribute access
class Bullet
  attr_accessor :x, :y, :active

  def initialize
    @active = false
  end
end

# Enemy class for efficient attribute access
class Enemy
  attr_accessor :x, :y, :active

  def initialize
    @active = false
  end
end

# Main game window class
class SpaceShooter < Gosu::Window
  def initialize
    super(800, 600, false, 16.6667)  # 800x600 window, 60 FPS
    self.caption = "Space Shooter"

    # Player initial position and movement
    @player_x = 375.0  # Float for precision
    @player_y = 500
    @velocity_x = 0.0
    @acceleration = 0.5  # Acceleration per frame
    @max_speed = 8.0     # Maximum speed in pixels per frame
    @damping = 0.9       # Deceleration factor when no input

    # Object pools
    @bullet_pool = Array.new(20) { Bullet.new }  # Max 20 bullets
    @enemy_pool = Array.new(10) { Enemy.new }    # Max 10 enemies, 6 active

    # Game state
    @score = 0
    @lives = 3
    @last_spawn_time = Gosu.milliseconds
    @last_shot_time = Gosu.milliseconds
    @space_pressed = false
    @game_over = false

    # Speeds and intervals
    @bullet_speed = 12
    @enemy_speed = 3
    @spawn_interval = 1000  # Enemy spawn every 1 second
    @shot_cooldown = 250    # Shooting cooldown in milliseconds

    # Performance monitoring
    @fps = 0
    @frame_count = 0
    @last_fps_time = Gosu.milliseconds

    # Font for text rendering
    @font = Gosu::Font.new(20)
  end

  def update
    return if @game_over

    # **Player Movement with Acceleration**
    if button_down?(Gosu::KbLeft)
      @velocity_x -= @acceleration
    elsif button_down?(Gosu::KbRight)
      @velocity_x += @acceleration
    else
      @velocity_x *= @damping  # Slow down when no input
    end

    # Clamp velocity to max speed
    @velocity_x = @velocity_x.clamp(-@max_speed, @max_speed)

    # Update player position and clamp to screen bounds
    @player_x += @velocity_x
    @player_x = @player_x.clamp(0.0, 750.0)

    # **Shooting (on press, not hold)**
    if button_down?(Gosu::KbSpace) && !@space_pressed && Gosu.milliseconds - @last_shot_time > @shot_cooldown
      spawn_bullet
      @last_shot_time = Gosu.milliseconds
      @space_pressed = true
    elsif !button_down?(Gosu::KbSpace)
      @space_pressed = false
    end

    # **Update Bullets**
    @bullet_pool.each do |bullet|
      if bullet.active
        bullet.y -= @bullet_speed
        bullet.active = false if bullet.y < 0
      end
    end

    # **Spawn Enemies with Minimum Distance**
    if Gosu.milliseconds - @last_spawn_time > @spawn_interval && @enemy_pool.count { |e| e.active } < 6
      spawn_enemy
      @last_spawn_time = Gosu.milliseconds
    end

    # **Update Enemies**
    @enemy_pool.each do |enemy|
      if enemy.active
        enemy.y += @enemy_speed
        if enemy.y > 600
          enemy.active = false
          @lives -= 1
          @game_over = true if @lives <= 0
        end
      end
    end

    # **Build Spatial Grid for Collision Detection**
    grid = Hash.new { |h, k| h[k] = [] }
    @enemy_pool.each do |enemy|
      if enemy.active
        cell_x = (enemy.x / 80).floor.clamp(0, 9)  # 10x10 grid (80x60 cells)
        cell_y = [0, (enemy.y / 60).floor].max.clamp(0, 9)
        grid[[cell_x, cell_y]] << enemy
      end
    end

    # **Collision Detection with Spatial Partitioning**
    @bullet_pool.each do |bullet|
      next unless bullet.active
      bullet_cell_x = (bullet.x / 80).floor.clamp(0, 9)
      bullet_cell_y = (bullet.y / 60).floor.clamp(0, 9)
      catch :hit do
        (-1..1).each do |dx|
          (-1..1).each do |dy|
            check_cell_x = (bullet_cell_x + dx).clamp(0, 9)
            check_cell_y = (bullet_cell_y + dy).clamp(0, 9)
            grid[[check_cell_x, check_cell_y]].each do |enemy|
              if enemy.active && collision?(bullet, enemy)
                bullet.active = false
                enemy.active = false
                @score += 1
                throw :hit  # Exit after first hit
              end
            end
          end
        end
      end
    end

    # **FPS Counter**
    @frame_count += 1
    if Gosu.milliseconds - @last_fps_time >= 1000
      @fps = @frame_count
      @frame_count = 0
      @last_fps_time = Gosu.milliseconds
    end
  end

  def draw
    if @game_over
      Gosu::Font.new(40).draw_text("Game Over", 300, 250, 0)
      @font.draw_text("Final Score: #{@score}", 300, 300, 0)
    else
      Gosu.draw_rect(@player_x, @player_y, 50, 50, Gosu::Color::BLUE)
      @bullet_pool.each { |b| Gosu.draw_rect(b.x, b.y, 5, 10, Gosu::Color::WHITE) if b.active }
      @enemy_pool.each { |e| Gosu.draw_rect(e.x, e.y, 40, 40, Gosu::Color::RED) if e.active }
      @font.draw_text("Score: #{@score}", 10, 10, 0)
      @font.draw_text("Lives: #{@lives}", 10, 30, 0)
      @font.draw_text("FPS: #{@fps}", 10, 50, 0)
    end
  end

  # **Spawn Bullet from Pool**
  def spawn_bullet
    bullet = @bullet_pool.find { |b| !b.active }
    if bullet
      bullet.x = @player_x + 22.5  # Center bullet on player
      bullet.y = @player_y
      bullet.active = true
    end
  end

  # **Spawn Enemy from Pool with Distance Check**
  def spawn_enemy
    enemy = @enemy_pool.find { |e| !e.active }
    if enemy
      spawn_x = rand(760)
      spawn_possible = @enemy_pool.none? do |e|
        e.active && (e.x - spawn_x).abs < 100 && e.y < 100
      end
      if spawn_possible
        enemy.x = spawn_x
        enemy.y = -40
        enemy.active = true
      end
    end
  end

  # **Collision Detection**
  def collision?(bullet, enemy)
    bullet.x < enemy.x + 40 && bullet.x + 5 > enemy.x &&
    bullet.y < enemy.y + 40 && bullet.y + 10 > enemy.y
  end
end

# Start the game
window = SpaceShooter.new
window.show