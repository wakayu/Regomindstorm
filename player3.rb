require_relative 'ev3/ev3'

class Player
  LEFT_MOTOR = "B"
  RIGHT_MOTOR = "C"
  WHEEL_SPEED = 20

  attr_reader :distance

  def initialize(port)
    @brick = EV3::Brick.new(EV3::Connections::Bluetooth.new(port))
    @brick.connect
    @busy = false
    @grabbing = false
  end

  # 前進する
  def run_forward(speed=WHEEL_SPEED)
    operate do
      @brick.step_velocity(speed, 260, 40, *wheel_motors)
      @brick.motor_ready(*wheel_motors)
    end
  end

  # 動きを止める
  def stop
    @brick.stop(true, *all_motors)
    @brick.run_forward(*all_motors)
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
end