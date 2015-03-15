require 'json'

class UdpUI < EventMachine::Connection
  include MPDOperations
    
  def initialize(common)
    @mpd = common.mpd
    @common = common
  end
  
  def ir_send(device = "AVR10", button)
    @common.lirc.send_data "SEND_ONCE #{device} #{button}\n"
  end  
  
  def receive_data(data)
    case data
    when /^ir:(.*)$/
      ir_send "Denon_RC-1163", $1
    when /cd_ir:(.*)$/
      ir_send "AVR10", $1
    when /tuner:tune:(\d)$/
      ir_send "Denon_RC-1163", "KEY_#{$1}"
    when /tuner:tune:1(\d)$/
      ir_send "Denon_RC-1163", "KEY_10"
      EM.add_timer 0.1 do
        ir_send "Denon_RC-1163", "KEY_#{$1}"
      end
    when "mpd:pause"
      mpd_pause
    when "mpd:next"
      mpd :next
    when "mpd:prev"
      mpd :previous
    when "mpd:next_album"
      mpd_next_album
    when "mpd:prev_album"
      mpd_prev_album
    when "lamp"
      EM.defer { system "toggle_lamp" }
    else
      puts "whaat? #{msg}"
    end
  end
end