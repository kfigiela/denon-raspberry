require 'ruby-mpd'

class MPD
  def idle(*subsystems)
    self.send_command('idle',*subsystems)
  end
  
  def async_idle
    raise ConnectionError, "Not connected to the server!" if !@socket
    @mutex.synchronize do
      begin
        @socket.puts convert_command('idle', 'mixer')
      rescue Errno::EPIPE
        reconnect
        retry
      end
   end    
 end
 def noidle
   self.send_command 'noidle'
   yield self
   self.async_idle
 end
end