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
    EM.defer { system "service shairplay start" }
    @lcd.display_screen 'airplay', "AirPlay"
    @lcd.touch
  end

  def disable_airplay
    EM.defer { system "pgrep shairplay && sudo service shairplay stop" }
    @lcd.remove_screen 'airplay'
    @lcd.touch    
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
  
  def stop_cd
    ir_send :AVR10, :CD_STOP
  end
  
  def ir_send(device = "AVR10", button)
    @lirc.send_data "SEND_ONCE #{device} #{button}\n"
  end  
end

class MyDenon < Denon
  include MPDOperations
  include MyOperations
  
  def initialize(mpd, lcd, ui)    
    @lirc = EventMachine.connect_unix_domain "/var/run/lirc/lircd", DevNull
    @mpd = mpd
    @lcd = lcd
    @ui = ui
    
    @status = if File.exists?('status.bin')
      begin
        File.open('status.bin') { |file| Marshal.load(file) } 
      rescue Exception => e
        puts "Failer reading state"
        puts e.message
        Status.new
      end
    else
        Status.new
    end    
    on_status(:boot)
    EM.defer do
      system "gpio -g mode 27 out"
      system "gpio -g write 27 0"
    end
  end

  def on_status(what)
    File.write('status.bin', Marshal.dump(@status))
    @ui.on_status(what, @status)
  end
  
  def on_display_brightness(brigtness)
    super
    @lcd.backlight = case brigtness
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
    @lcd.touch
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
    when :play
      mpd :play
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
      EM.defer { system("sudo toggle_display") }
    when :program
      EM.defer { system("loadalbum; sudo sync; sudo hdparm -y /dev/sda") }
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
    if source == :network
      enable_music
      mpd :play
    else
      disable_music
      disable_airplay
    end
    
    if source == :cd
      nil
    else
      stop_cd
    end
  end
  
  def on_amp_off
    super
    disable_music
    disable_airplay
    stop_cd
    @lcd.backlight = 0
  end
end
