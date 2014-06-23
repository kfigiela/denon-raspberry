TIOCSTI=0x00005412

class DevNull < EM::Connection
  def receive_data data
  end
end

class MyDenon < Denon
  def initialize(mpd, lcd)
    super()
    @lirc = EventMachine.connect_unix_domain "/var/run/lirc/lircd", DevNull
    @rewind = nil
    @mpd = mpd
    @lcd = lcd
  end
  
  def tty_send(key)
    File.open('/dev/tty1','w') do |tty|
      key.chars { |char| tty.ioctl(TIOCSTI, char) }
    end
  end

  def load_playlist(name, pos = nil)
    @mpd.noidle do |mpd|
      mpd.clear
      mpd.playlists.find { |p| p.name == name }.load
      mpd.play(pos)
    end
  end 

  def mpd(action)
    @mpd.noidle do |mpd|
      mpd.send(action)
    end
  end

  def mpd_toggle(action)
    @mpd.noidle do |mpd|
      mpd.send("#{action.to_s}=".to_sym, (not mpd.status[action.to_sym]))
    end
  end

  def mpd_pause
    @mpd.noidle do |mpd|
      if mpd.playing?
        mpd.pause = 1
      else
        mpd.play
      end
    end
  end
  
  
  def mpd_next_album
    @mpd.noidle do |mpd|
      current_song = mpd.current_song
      status = mpd.status
      idx = mpd.queue((status[:song])..(status[:playlistlength])).find_index{|s| s.album != current_song.album }
      mpd.play status[:song] + idx if idx
    end
  end
  
  def mpd_prev_album
    @mpd.noidle do |mpd|
      status = mpd.status
      if status[:song] > 0
        current_song = mpd.queue[status[:song]-1]
        idx = (mpd.queue(0...(status[:song])).rindex {|s| s.album != current_song.album })
        mpd.play (idx+1) if idx
      end
    end
  end

  # def send_keys(keys)
  #   EM.defer { system(%Q{tmux send-keys -t "console:0" #{keys}}) }
  # end
  #
  # def start_rewind(dir)
  #   puts "start..."
  #   if @rewind #and @rewind == dir
  #     puts "already rewind #{@step}"
  #     @step = 2 if @step < 2
  #   else
  #     puts 'start rewind'
  #     # stop_rewind
  #     @rewind = dir
  #     # EM.defer {
  #       system("irsend SEND_START AVR10 CD_#{dir}; echo '               OK'")
  #       puts "Started"
  #     # }
  #     @rewind_timer.cancel if @rewind_timer
  #     @step = 2
  #     @rewind_timer = EM::PeriodicTimer.new 0.1 do
  #       puts "Timer #{@step}"
  #       if @step < 1
  #         stop_rewind
  #       else
  #         @step = @step - 1
  #       end
  #     end
  #   end
  # end
  #
  # def stop_rewind
  #   if @rewind
  #     dir = @rewind
  #     @rewind_timer.cancel if @rewind_timer
  #     EM.defer {
  #       system("irsend SEND_STOP AVR10 CD_#{dir}")
  #     }
  #     puts "stop rewind"
  #     @rewind_timer = nil
  #     @rewind = nil
  #   end
  # end
  
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
  
  def ir_send(device = "AVR10", button)
    # EM.add_timer 0.1 do
    @lirc.send_data "SEND_ONCE #{device} #{button}\n"
    # end
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
    @lcd.backlight = 0
  end
end
