require 'bundler/setup' 

require 'em/pure_ruby'
require_relative 'denon'


class DemoDenon < Denon
  def on_network_button(id)
    puts "Button #{id} pressed and the source is Network"
  end
  
  def on_cd_button(id)
    puts "Button #{id} pressed and the source is CD"
  end
  
  def on_display_brightness(brightness)
    puts "Display brightness set to #{brightness}"
  end
  
  def on_cd_function(function)
    puts "Set CD function to #{function}"
  end

  def on_network_function(function)
    puts "Set Network function to #{function}"
  end
  
  def on_volume(vol)
    puts "Volume is #{vol}"
  end
  
  def on_mute(status)
    puts "Mute status is #{status}"
  end
  
  def on_sleep_timer(time)
    puts "Sleep timer set to #{time}"
  end
  
  def on_source(source)
    puts "Source set to #{source}"
  end
  
  def on_amp_on
    puts "Amp is on"
  end
  
  def on_amp_off
    puts "Amp is off"
  end
 
end


EventMachine.run do
  denon = EventMachine.open_serial '/dev/ttyAMA0', 115200, 8, 1, 0, DemoDenon
end