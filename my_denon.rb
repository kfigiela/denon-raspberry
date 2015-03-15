require_relative 'mpd_operations'

TIOCSTI=0x00005412

class DevNull < EM::Connection
  def receive_data data
  end
end

module MyOperations
  def tty_send(key)
    File.open('/dev/tty2','w') do |tty|
      key.chars { |char| tty.ioctl(TIOCSTI, char) }
    end
  end

  def enable_airplay
    EM.system "systemctl start shairplay"
    @common.lcd_touch
  end

  def disable_airplay
    EM.system "systemctl stop shairplay"
    @common.lcd_touch
  end

  def enable_music
    @common.mpd.noidle do |mpd|
      mpd.enableoutput 0
      mpd.play
    end
  end

  def disable_music
    @common.mpd.noidle do |mpd|
      if mpd.current_song.time.nil? # for radio streams
        mpd.stop
      end
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
    @mode = :music
    
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
  
  def on_number_key(num)
    num = (if num == 0 then 10 else num end) - 1

    case @mode
    when :music
      load_playlist_by_index num
    when :radio
      @common.mpd.noidle do |mpd|
        mpd.play(num)
      end
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
      on_number_key 1
    when :num2
      on_number_key 2
    when :num3
      on_number_key 3
    when :num4
      on_number_key 4
    when :num5
      on_number_key 5
    when :num6
      on_number_key 6
    when :num7
      on_number_key 7
    when :num8
      on_number_key 8
    when :num9
      on_number_key 9
    when :num0
      on_number_key 0
    when :clear
      @common.mpd.noidle do |mpd|
        mpd.clear
      end
    when :info
      @common.events.actions.push :info
    when :num10
      @common.events.lcd_alerts.push ["Toggling display...", ""]
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

  def change_mode(mode)
    old_mode = @mode
    @mode = mode
    puts "#{old_mode} -> #{mode}"
    
    return if old_mode == mode

    if old_mode == :airplay
      disable_airplay
    end

    if (mode != :music and mode != :radio) and (old_mode == :music or old_mode == :radio)
      disable_music
    end
    
    if old_mode == :music
      @common.mpd.noidle do |mpd|
        mpd.playlists.find { |p| p.name == ".musicplaylist" }.destroy
        mpd.save ".musicplaylist"
        @music_pos = mpd.current_song.pos
      end
    end

    if old_mode == :radio      
      @common.mpd.noidle do |mpd|
        @radio_station = @common.mpd_status[:song]
        mpd.clear
        mpd.playlists.find { |p| p.name == ".musicplaylist" }.load
        mpd.play(@music_pos)
      end
    end

    case mode
    when nil
      nil
    when :radio
      enable_music
      
      mpd_toggle :repeat, true
      mpd_toggle :single, true
      
      load_playlist "Radio", @radio_station
    when :music
      mpd_toggle :repeat, false
      mpd_toggle :single, false
      
      enable_music
    when :airplay
      enable_airplay
    end
    
    @common.lcd_status({radio: "Radio", music: "Music", airplay: "AirPlay"}[mode])
  end

  def on_network_function(function)
    super
    case function
    when :internet_radio
      change_mode :radio
    when :online_music
      change_mode :music
    when :music_server
      change_mode :airplay
    end
  end
  
  def on_cd_function(function)
    super
    case function
    when :cd
      ir_send :AVR10, :CD_PLAY
    end
  end
  
  def on_source(source)
    super
    if source == :network
      change_mode (@mode or :music)
    else
      change_mode nil
    end
    
    unless (source == :cd or source == :analog1)
      stop_cd
    end
  end
  
  def on_amp_off
    super
    change_mode nil
    stop_cd
    @common.lcd_backlight = 0
  end
end
