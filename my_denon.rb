class MyDenon < Denon  

  def lcd=(lcd)
    @lcd = lcd
  end
  
  def mpd=(mpd)
    @mpd = mpd
  end
  
  def load_playlist(name)
    @mpd.noidle do |mpd|
      mpd.clear
      mpd.playlists.find { |p| p.name == name }.load
      mpd.play
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
      case mpd.status[:state]
      when :play
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

  def send_keys(keys)
    EM.defer do
      system(%Q{tmux send-keys -t "console:0" #{keys}})
    end
  end

  def enable_airplay
    EM::defer do 
      system "service shairplay start"
    end
    @lcd.display_screen 'airplay', "AirPlay"
  end

  def disable_airplay
    EM::defer do
      system "pgrep shairplay && sudo service shairplay stop"
    end
    @lcd.remove_screen 'airplay'
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
  
  def on_display_brightness(brigtness)
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
      send_keys "Up"
    when :down
      send_keys "Down"
    when :left
      send_keys "PgUp"
    when :right
      send_keys "PgDn"
    when :enter
      send_keys "Enter"
    when :mode
      send_keys "Tab"
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
      EM.defer do
        system("sudo toggle_display")
      end
    when :program
      EM.defer do 
        system("loadalbum; sudo sync; sudo hdparm -y /dev/sda")
      end
    end
  end

  def on_network_function(function)
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
    disable_music
    disable_airplay
    @lcd.backlight = 0
  end
end