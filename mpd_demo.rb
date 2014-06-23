require 'bundler/setup'

require 'eventmachine'
require 'serialport'

require_relative 'mpd_idle'
require_relative 'denon'
require_relative 'mpd_operations'


module MyOperations
  def enable_airplay
    EM.defer { system "service shairplay start" }
  end

  def disable_airplay
    EM.defer { system "pgrep shairplay && sudo service shairplay stop" }
  end

  def enable_music
    @mpd.noidle do |mpd|
      mpd.enableoutput 0
      mpd.play
    end
  end

  def disable_music
    @mpd.noidle do |mpd|
      mpd.disableoutput 0
    end
  end
end

class MPDDenon < Denon
  include MPDOperations
  include MyOperations
  
  def initialize(mpd)
    super()
    @mpd = mpd
  end

  
  def on_display_brightness(brigtness)
    super
  end  
  
  def on_network_button(button)
    super
    case button
    when :next
      mpd :next      
    when :previous
      mpd :previous
    when :forward
      mpd_next_album
    when :rewind
      mpd_prev_album
    when :up
      nil
    when :down
      nil
    when :left
      nil
    when :right
      nil
    when :enter
      nil
    when :mode
      nil
    when :play_pause
      mpd_pause
    when :play
      mpd :play
    when :stop
      mpd :stop
    when :repeat
      mpd_toggle :repeat
    when :random
      mpd_toggle :random
    when :num1
      load_playlist "Anathema"
    when :num2
      load_playlist "Riverside"
    when :num3
      load_playlist "Sigur Rós".force_encoding('UTF-8')
    when :num4
      load_playlist "Soundtrack"
    when :num5
      load_playlist "Kizomba"
    when :clear
      send_keys "c"
    when :info
      nil
    when :program
      nil
    end
  end
  
  
  def on_cd_button(button)
    super
    # Same button choice as in on_network_button
  end

  def on_network_function(function)
    super
    case function
    when :online_music
      disable_airplay
      enable_music
    when :music_server
      disable_music
      enable_airplay
    end
  end
  
  def on_source(source)
    super
    case source
    when :network
      enable_music
      mpd :play
    else
      disable_music
      disable_airplay
    end
  end
  
  def on_amp_off
    super
    disable_music
    disable_airplay
  end
end


EventMachine.run do
  mpd = MPD.new
  mpd.connect
  puts "Connected to MPD"
  mpd.async_idle
  
  sp = SerialPort.open("/dev/ttyAMA0", 115200, 8, 1, SerialPort::NONE)
  denon = EventMachine.attach sp, MPDDenon, mpd
end
