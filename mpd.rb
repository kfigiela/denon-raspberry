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
   @idle_lock ||= Mutex.new
   
   EM.defer do
     @idle_lock.synchronize do
       self.send_command 'noidle'
       yield self
       self.async_idle
     end
   end
 end
 
 def noidle_sync
   @idle_lock ||= Mutex.new
   
   @idle_lock.synchronize do
     self.send_command 'noidle'
     yield self
     self.async_idle
   end
 end
 
 class Song
   def as_json
     {title: title, artist: artist, album: album}
   end
   def to_json(*a)
     as_json.to_json(*a)
   end
 end
end