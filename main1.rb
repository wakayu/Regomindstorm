require 'dxruby'
require_relative "map"
require_relative "player_sprite"

player = PlayerSprite.new(0,0)

begin
  
  signals = player.receive
  message = player.get_message(signals)
  puts "receive: #{message}"

  map = Map.new(message)
  current = map.start
  goal = map.goal

  # DXRubyでは、Window.loopの処理の最後に描画が行われるため、
  # フラグ管理して描画がスキップされないようにする。
  init = true          # 初回のフレームかどうか
  reach_goal = false   # ゴールに到達したか
  give_up = false      # ゴール到達不可能になったかどうか

  p "current: #{current}" 
  p "goal:    #{goal}"    
  
  Window.width   = 800
  Window.height  = 600

  bg_img = Image.load("images/map_chips4.png")

  Window.loop do
    break if Input.key_down? K_E
    if reach_goal
      puts "goal!"
      sleep 2
      break
    end
    if give_up
      puts "give up!"
      sleep 2
      break
    end
    if init
      init = false
    else
      route = map.calc_route(current, goal)
      p route #コンソールに結果を出す
      if route.length == 1
        if current == goal
          reach_goal = true
        else
          give_up = true
        end
      else
        player.move_to(route[1])
        current = route[1]
      end
    end
    map.draw
    player.draw
  end
ensure
  player.close
end
