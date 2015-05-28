require 'json'

class UdpUI < EventMachine::Connection
  include MPDOperations
  include MyOperations
    
  def initialize(common)
    @mpd = common.mpd
    @common = common
  end
  
  def receive_data(data)
    parse_command(data)
  end
end