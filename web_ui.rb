require 'em-websocket'
require 'json'

class Struct
  def to_map
    map = Hash.new
    self.members.each { |m| map[m] = self[m] }
    map
  end

  def to_json(*a)
    to_map.to_json(*a)
  end
end


class WebSocketUI
  include MPDOperations
    
  def initialize(mpd)
    @channels = {}
    @mpd = mpd
    @lirc = EventMachine.connect_unix_domain "/var/run/lirc/lircd", DevNull
    start
  end
  
  def ir_send(device = "AVR10", button)
    @lirc.send_data "SEND_ONCE #{device} #{button}\n"
  end  
  
  def start
    EM::WebSocket.run(:host => "0.0.0.0", :port => 8080) do |ws|
      ws.onopen { |handshake|
        @channels[ws.object_id] = ws
        puts "WebSocket connection open"
        send_all
      }

      ws.onclose { 
        @channels.delete(ws.object_id)
        puts "Connection closed" 
      }

      ws.onmessage { |msg|        
        puts "Recieved message: #{msg}"
        case msg
        when /ir:(.*)$/
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
      }
    end
  end
  
  def broadcast(msg) 
    @channels.each do |k,ws|
      ws.send msg
    end
  end
  def send_all
    broadcast({denon: @last_status, mpd: {status: @mpd_status, song: @mpd_song}}.to_json)
  end
  
  def on_status(what, status)
    @last_status = status
    send_all
  end
  
  def on_mpd(song, status)
    @mpd_status = status
    @mpd_song = song
    send_all    
  end
end