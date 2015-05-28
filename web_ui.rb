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
  include MyOperations
    
  def initialize(common)
    @channels = {}
    @mpd = common.mpd
    @common = common

    start

    @common.events.mpd_status.subscribe { send_all }
    @common.events.denon_status.subscribe do |status|
      @last_status = status[1]
      send_all
    end
  end
    
  def start
    EM::WebSocket.run(:host => "0.0.0.0", :port => 8080) do |ws|
      ws.onopen { |handshake|
        @channels[ws.object_id] = ws
        puts "WebUI: WebSocket connection open"
        send_all
      }

      ws.onclose { 
        @channels.delete(ws.object_id)
        puts "WebUI: Connection closed" 
      }

      ws.onmessage { |msg|        
        puts "WebUI: recieved message: #{msg}"
        self.parse_command(msg)
      }
    end
  end
  
  def broadcast(msg) 
    @channels.each do |k,ws|
      ws.send msg
    end
  end
  def send_all
    broadcast({denon: @last_status, mpd: {status: @common.mpd_status, song: @common.mpd_song}}.to_json)
  end
end