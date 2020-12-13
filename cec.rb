class CEC < EM::Connection
  include MyOperations

  def initialize(common)
    @common = common
  end

  def receive_data data
    case data
    when /Key ([a-zA-Z0-9 ]+):/
      key = $1
      emulated_key =
        case key
        when "select" then :enter
        when "setup menu" then :network_setup
        when "exit" then :mode
        when "red" then :call
        when "green" then :add
        when "blue" then :clear
        when "Fast forward" then :next
        when "rewind" then :previous
        when "backward" then :rewind
        when "backward" then :rewind
        when "play" then :play!
        when "pause" then :pause!
        when "channel up" then :seek_forward
        when "channel down" then :seek_backward
        else key.to_sym
        end

        puts "CEC #{$1}"
      @common.denon.on_network_button(emulated_key)
    else
      puts data
    end
  end
end
