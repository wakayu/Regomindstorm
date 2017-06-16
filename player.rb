require_relative 'ev3/ev3'

class Player
  LEFT_MOTOR = "B"
  RIGHT_MOTOR = "C"
  DISTANCE_SENSOR = "1"
  WHEEL_SPEED = 20
  MAPPING = {
    "0" => [1,1],
    "1" => [1,2],
    "2" => [1,1,1],
    "3" => [1,1,2],
    "4" => [1,2,1],
    "5" => [1,2,2],
    "6" => [1,1,1,1],
    "7" => [1,1,1,2],
    "8" => [1,1,2,1],
    "9" => [1,2,1,1],
    "A" => [1,1,1,1,1],
    "B" => [1,1,2,2],
    "C" => [1,2,1,2],
    "D" => [1,2,2,1],
    
  }
  MAPPING_INV = MAPPING.invert
  UNIT = 1.5 # 通信の単位時間
  LIMIT = UNIT * 8


  attr_reader :distance

  def initialize(port)
    @brick = EV3::Brick.new(EV3::Connections::Bluetooth.new(port))
    @brick.connect
    @busy = false
    @grabbing = false
  end
 
  def get_message(signals)
      p "signals wa #{signals}"
      # ノイズ除去後の正味の信号
      net_signal_pairs = []
      # ノイズ除去その1
      # 0.0, 1.0 以外の値はノイズなので除外する
      signals.select!{|_, v| [0.0, 1.0].include?(v) }
      # ノイズ除去その2
      # 先頭が1.0以外の場合はノイズなので除外する
      signals.shift until signals[0][1] == 1.0
      pair_a = nil
      # ノイズ除去その3
      signals.each do |signal|
        # 0.0 が連続している場合はノイズなので除外する
        unless pair_a
          if signal[1] == 1.0
            pair_a = signal
          end
          next
        end
        # 1.0から0.0に切り替わるまでの時間が単位時間の3割未満の場合、
        # ノイズと判断して除外する
        if signal[0] - pair_a[0] < UNIT * 0.3
          pair_a = nil
          next
        end
        net_signal_pairs << [pair_a, signal]
        pair_a = nil
      end
      signal_pairs_per_char = [] # 文字単位で振り分けた信号
      signal_pairs = []          # 文字1つ分の信号を一時的に格納する変数
      net_signal_pairs.each.with_index do |signal_pair, i|
        if signal_pairs.empty?
          signal_pairs << signal_pair
          next
        end
        # 信号のペア間の間隔が単位時間の2倍以上であれば、文字の境目とみなす
        if signal_pair[0][0] - signal_pairs.last[1][0] < UNIT * 2.0
          signal_pairs << signal_pair
          if i == net_signal_pairs.size - 1
            signal_pairs_per_char << signal_pairs
          end
        else
          signal_pairs_per_char << signal_pairs
          signal_pairs = [signal_pair]
        end
      end

      # デバッグ用
      require 'pp'
      pp signal_pairs_per_char

      # 信号を文字にデコードする
      chars = signal_pairs_per_char.map{|signal_pairs|
        signals = signal_pairs.map{|s1, s2|
          (s2[0] - s1[0] < UNIT * 1.3) ? 1 : 2
        }
        # デバッグ用
        p signals
        MAPPING_INV[signals]
      }
      # 文字を連結して単語にする
      word = chars.join
      return word
  end

  def receive
      signals = []
      prev_time = Time.now
      prev_value = @brick.get_sensor(DISTANCE_SENSOR, 2)
      loop do
        value = @brick.get_sensor(DISTANCE_SENSOR, 2)
        now = Time.now
        # 値が変化したときに、そのときの時間とセンサーの値を記録する
        if now - prev_time > LIMIT
          break
        elsif value != prev_value
          prev_time = now
          prev_value = value
          # デバッグ用
          puts "\tnow: #{now}, value:#{value}"
          signals << [now, value]
        end
        sleep 0.1
      end
      return signals
  end


  # 前進する
  def run_forward(speed=WHEEL_SPEED)
    operate do
      @brick.step_velocity(speed, 260, 40, *wheel_motors)
      @brick.motor_ready(*wheel_motors)
    end
  end

  # バックする
  def run_backward(speed=WHEEL_SPEED)
    operate do
      @brick.reverse_polarity(*wheel_motors)
      @brick.step_velocity(speed, 260, 40, *wheel_motors)
      @brick.motor_ready(*wheel_motors)
    end
  end

  # 右に回る
  def turn_right(speed=WHEEL_SPEED)
    operate do
      @brick.reverse_polarity(RIGHT_MOTOR)
      @brick.step_velocity(speed, 130, 60, *wheel_motors)
      @brick.motor_ready(*wheel_motors)
    end
  end

  # 左に回る
  def turn_left(speed=WHEEL_SPEED)
    operate do
      @brick.reverse_polarity(LEFT_MOTOR)
      @brick.step_velocity(speed, 130, 60, *wheel_motors)
      @brick.motor_ready(*wheel_motors)
    end
  end

  def get_count(motor)
    @brick.get_count(motor)
  end

  # 動きを止める
  def stop
    @brick.stop(true, *all_motors)
    @brick.run_forward(*all_motors)
  end

  # ある動作中は別の動作を受け付けないようにする
  def operate
    unless @busy
      @busy = true
      yield(@brick)
      stop
      @busy = false
    end
  end

  # センサー情報の更新
  def update
    @distance = @brick.get_sensor(DISTANCE_SENSOR, 0)
  end

  # センサー情報の更新とキー操作受け付け
  def run
    update
    run_forward if Input.keyDown?(K_UP)
    run_backward if Input.keyDown?(K_DOWN)
    turn_left if Input.keyDown?(K_LEFT)
    turn_right if Input.keyDown?(K_RIGHT)
    stop if [K_UP, K_DOWN, K_LEFT, K_RIGHT, K_W, K_S].all?{|key| !Input.keyDown?(key) }
  end

  # 終了処理
  def close
    stop
    reset
    @brick.disconnect
  end

  def reset
    @brick.clear_all
  end

  # "～_MOTOR" という名前の定数すべての値を要素とする配列を返す
  def all_motors
    @all_motors ||= self.class.constants.grep(/_MOTOR\z/).map{|c| self.class.const_get(c) }
  end

  def wheel_motors
    [LEFT_MOTOR, RIGHT_MOTOR]
  end
end