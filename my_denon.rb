require_relative 'mpd_operations'

TIOCSTI=0x00005412

class DevNull < EM::Connection
  def receive_data data
  end
end

module MyOperations
  def tty_send(key)
    File.open('/dev/tty1','w') do |tty|
      key.chars { |char| tty.ioctl(TIOCSTI, char) }
    end
  end

  def enable_airplay
    EM.system "systemctl start shairplay"
    @common.lcd_status "AirPlay"
    @common.lcd_touch
  end

  def disable_airplay
    EM.system "systemctl stop shairplay"
    @common.lcd_status ""
    @common.lcd_touch
  end

  def enable_music
    @common.lcd_status "MPD"      
    @common.mpd.noidle do |mpd|
      mpd.enableoutput 0
      mpd.play
    end
  end

  def disable_music
    @common.lcd_status ""      
    @common.mpd.noidle do |mpd|
      mpd.disableoutput 0
    end
  end
  
  def stop_cd
    ir_send :AVR10, :CD_STOP
  end
  
  def ir_send(device = "AVR10", button)
    @common.lirc.send_data "SEND_ONCE #{device} #{button}\n"
  end  
end

class MyDenon < Denon
  include MPDOperations
  include MyOperations
  
  def initialize(common)    
    @common = common
    
    @status = if File.exists?('status.bin')
      begin
        File.open('status.bin') { |file| Marshal.load(file) } 
      rescue Exception => e
        puts "Failed reading state"
        puts e.message
        Status.new
      end
    else
        Status.new
    end    
    on_status(:boot)
  end

  def on_status(what)
    File.write('status.bin', Marshal.dump(@status))
    @common.events.denon_status.push [what, @status]
  end
  
  def on_display_brightness(brigtness)
    super
    @common.lcd_backlight = case brigtness
    when :bright
      1023
    when :dim 
      400
    when :dark
      200
    when :off
      0
    end
  end  
  
  def on_network_button(button)
    super
    @common.lcd_touch
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
      tty_send "\e[A"
    when :down
      tty_send "\e[B"
    when :left
      tty_send "\e[5~"
    when :right
      tty_send "\e[6~"
    when :enter
      tty_send "\n"
    when :mode
      tty_send "\t"
    when :play_pause
      mpd_pause
    when :play # for alarm clock
      disable_airplay
      enable_music      
    when :stop
      mpd :stop
    when :repeat
      mpd_toggle :repeat
    when :random
      mpd_toggle :random
    when :num1
      load_playlist_by_index 0
    when :num2
      load_playlist_by_index 1
    when :num3
      load_playlist_by_index 2
    when :num4
      load_playlist_by_index 3
    when :num5
      load_playlist_by_index 4
    when :num6
      load_playlist_by_index 5
    when :num7
      load_playlist_by_index 6
    when :num8
      load_playlist_by_index 7
    when :num9
      load_playlist_by_index 8
    when :num0
      load_playlist_by_index 9
    when :clear
      tty_send "c"
    when :info
      EM.system("toggle_display")
    end
  end
  
  
  def on_cd_button(button)
    super
    case button
    when :next
      ir_send :AVR10, :CD_NEXT
    when :previous
      ir_send :AVR10, :CD_PREV
    when :forward
      ir_send :AVR10, :CD_FWD
    when :rewind
      ir_send :AVR10, :CD_BKW
    when :play_pause
      ir_send :AVR10, :CD_PAUSE
    when :play
      ir_send :AVR10, :CD_PLAY
    when :stop
      ir_send :AVR10, :CD_STOP
    when :repeat
      ir_send :AVR10, :CD_AB
    when :random
      ir_send :AVR10, :CD_INTRO
    end
  end

  def on_digital_button(button)
    super
    def mediakey(id)
      EM.system "ssh -n mormegil mediakey #{id.to_s}"
    end  
    
    case button
    when :next
      mediakey :next
    when :previous
      mediakey :prev
    when :play_pause
      mediakey :playpause
    when :play
      mediakey :playpause
    when :stop
      mediakey :playpause
    end
  end

  def on_analog1_button(button)
    on_cd_button(button)
  end

  def on_network_function(function)
    super
    case function
    when :online_music, :internet_radio
      disable_airplay
      enable_music
    when :music_server
      disable_music
      enable_airplay
    end
  end
  
  def on_source(source)
    super
    if source == :network
      enable_music
      mpd :play
    else
      disable_music
      disable_airplay
    end
    
    # if source == :cd
    #   nil
    # else
    #   stop_cd
    # end
  end
  
  def on_amp_off
    super
    disable_music
    disable_airplay
    stop_cd
    @common.lcd_backlight = 0
  end
end
