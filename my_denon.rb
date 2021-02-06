	
require_relative 'mpd_operations'

TIOCSTI=0x00005412

class DevNull < EM::Connection
  def receive_data data
  end
end

module MyOperations
  def tty_send(key)
    puts key.inspect
    File.open('/dev/tty2','w') do |tty|
      key.chars { |char| tty.ioctl(TIOCSTI, char) }
    end
  end

  def enable_airplay
    EM.system "systemctl start shairport-sync" # raspotify"
    @common.lcd_touch
  end

  def disable_airplay
    EM.system "systemctl stop shairport-sync" # raspotify"
    @common.lcd_touch
  end

  def enable_passthrough
    EM.system "amixer cset name='Tx Source' 'S/PDIF RX'"
  end

  def disable_passthrough
    EM.system "amixer cset name='Tx Source' AIF"
  end

  def enable_music
    @common.mpd.noidle do |mpd|
      mpd.enableoutput 0
      mpd.play
    end
  end

  def disable_music
    @common.mpd.noidle do |mpd|
      if mpd.current_song and mpd.current_song.time.nil? # for radio streams
        mpd.stop
      end
      mpd.disableoutput 0
    end
  end

  def stop_cd
    ir_send :HKHD7325, :KEY_STOP
  end
  def stop_tape
    ir_send :SONY_DECK, :KEY_STOP
  end

  def ir_send(device = "HKHD7325", button)
    @common.lirc_tx.send_data "SEND_ONCE #{device} #{button}\n"
    puts "SEND_ONCE #{device} #{button}"
  end

  def parse_command(data)
    case data
    when /^ir:(.*)$/
      ir_send "Denon_RC-1163", $1
    when /cd_ir:(.*)$/
      ir_send "HKHD7325", $1
    when /^denon:(.*)$$/
      @common.denon.send $1.to_sym
    when /tuner:tune:([12]?\d)$/
      @common.denon.send_number $1.to_i
    when "mpd:pause"
      mpd_pause
    when "mpd:next"
      mpd :next
    when "mpd:prev"
      mpd :previous
    when "mpd:next_album"
      mpd_next_album
    when "mpd:prev_album"
      mpd_prev_album
    when /^source:(.*)$/
      @common.denon.source = $1.to_sym
    else
      puts "whaat? #{data}"
    end
  end

  def general_command(button)
    case @common.denon.source
    when :network
      on_network_button button
    when :cd
      on_cd_button button
    end
  end
end

class MyDenon < Denon
  include MPDOperations
  include MyOperations

  class MyStatus < Struct.new(:amp, :mode, :last_mode)
    def initialize
      super
      self.amp = ::Denon::Status.new
      self.mode = :music
      self.last_mode = :music
    end
  end

  def initialize(common)
    @common = common

    @my_status = if File.exists?('status.bin')
      begin
        File.open('status.bin') { |file| Marshal.load(file) }
      rescue Exception => e
        puts "Failed reading state"
        puts e.message
        MyStatus.new
      end
    else
        MyStatus.new
    end

    @status = @my_status.amp

    on_status(:boot)
  end

  def on_status(what)
    File.write('status.bin', Marshal.dump(@my_status))
    @common.events.denon_status.push [what, @my_status]
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

    case @my_status.mode
    when :music
      load_playlist_by_index num
    when :radio
      @common.mpd.noidle do |mpd|
        begin
          mpd.play(num)
        rescue MPD::ServerArgumentError # index does not exist in playlist
          mpd.stop
        end
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
      tty_send "\r"
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
      tty_send " "
    when :add
      puts "add -> tty"
      tty_send " "
    when :call
      tty_send "\e[3~"
    when :network_setup
      #
    # CEC-only
    when :pause!
      mpd_pause!
    when :play!
      mpd_play!
    when :seek_forward
      mpd_seek "+15"
    when :seek_backward
      mpd_seek "-15"
    end
  end


  def on_cd_button(button)
    super
    case button
    when :next
      ir_send :HKHD7325, :KEY_NEXT
    when :previous
      ir_send :HKHD7325, :KEY_PREV
    when :forward
      ir_send :HKHD7325, :KEY_FWD
    when :rewind
      ir_send :HKHD7325, :KEY_BKW
    when :play_pause
      ir_send :HKHD7325, :KEY_PAUSE
    when :play
      ir_send :HKHD7325, :KEY_PLAY
    when :stop
      ir_send :HKHD7325, :KEY_STOP
    when :repeat
      ir_send :HKHD7325, :KEY_AGAIN
    when :num10
      ir_send :HKHD7325, :AB
    when :program
      ir_send :HKHD7325, :DISPLAY
    when :info
      ir_send :HKHD7325, :KEY_TIME
    when :random
      ir_send :HKHD7325, :RANDOM
    when :num1
      ir_send :HKHD7325, :KEY_1
    when :num2
      ir_send :HKHD7325, :KEY_2
    when :num3
      ir_send :HKHD7325, :KEY_3
    when :num4
      ir_send :HKHD7325, :KEY_4
    when :num5
      ir_send :HKHD7325, :KEY_5
    when :num6
      ir_send :HKHD7325, :KEY_6
    when :num7
      ir_send :HKHD7325, :KEY_7
    when :num8
      ir_send :HKHD7325, :KEY_8
    when :num9
      ir_send :HKHD7325, :KEY_9
    when :num0
      ir_send :HKHD7325, :KEY_0
    end
  end

  def on_digital_button(button)
    super
    def mediakey(id)
      # EM.system "ssh -n narsil.lan mediakey #{id.to_s}"
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
    super
    case button
    when :next
      ir_send :SONY_DECK, :KEY_PAUSE
    when :forward
      ir_send :SONY_DECK, :KEY_FWD
    when :rewind
      ir_send :SONY_DECK, :KEY_BKW
    when :play_pause
      ir_send :SONY_DECK, :KEY_PLAY
    when :play
      ir_send :SONY_DECK, :KEY_PLAY
    when :stop
      ir_send :SONY_DECK, :KEY_STOP
    when :info
      ir_send :SONY_DECK, :MEMORY
    end
  end


  def on_analog2_button(button)
    super
    case button
    when :up
      ir_send :PANASONIC, :KEY_UP
    when :down
      ir_send :PANASONIC, :KEY_DOWN
    when :right
      ir_send :PANASONIC, :KEY_RIGHT
    when :left
      ir_send :PANASONIC, :KEY_LEFT
    when :enter
      ir_send :PANASONIC, :KEY_ENTER
    when :random
      ir_send :PANASONIC, :KEY_STOP
    when :mode
      ir_send :PANASONIC, :KEY_MENU
    when :search
      ir_send :PANASONIC, :KEY_BACK
    when :num1
      ir_send :PANASONIC, :KEY_EXIT
    when :num2
      ir_send :PANASONIC, :KEY_APPS
    when :num3
      ir_send :PANASONIC, :KEY_FAVORITE
    when :num4
      ir_send :PANASONIC, :KEY_PICTURE
    when :num5
      ir_send :PANASONIC, :KEY_SUBTITLE
    when :num6
      ir_send :PANASONIC, :KEY_HOME
    when :num7
      ir_send :PANASONIC, :KEY_CHANNELDOWN
    when :num8
      ir_send :PANASONIC, :KEY_VOLUMEUP
    when :num9
      ir_send :PANASONIC, :KEY_CHANNELUP
    when :num0
      ir_send :PANASONIC, :KEY_VOLUMEDOWN
    when :play_pause
      ir_send :PANASONIC, :KEY_PAUSE
    when :stop
      ir_send :PANASONIC, :KEY_STOP
    when :rewind
      ir_send :PANASONIC, :KEY_REWIND
    when :forward
      ir_send :PANASONIC, :KEY_FASTFORWARD
    when :previous
      ir_send :PANASONIC, :KEY_PREVIOUS
    when :next
      ir_send :PANASONIC, :KEY_NEXT
    when :random
      ir_send :PANASONIC, :KEY_OPTION
    when :info
      ir_send :PANASONIC, :KEY_INFO
    when :program
      ir_send :PANASONIC, :KEY_FAVORITE
    when :num10
      ir_send :PANASONIC, :KEY_POWER
    when :add
      ir_send :PANASONIC, :KEY_POWER
    when :call
      ir_send :PANASONIC, :KEY_APPS
    when :network_setup
      ir_send :PANASONIC, :KEY_BACK
    end
  end

  def change_mode(mode)
    old_mode = @my_status.mode
    @my_status.mode = mode
    @my_status.last_mode = mode unless mode.nil?

    puts "Change mode: #{old_mode.inspect} -> #{mode.inspect}"

    return if old_mode == mode

    if old_mode == :airplay
      disable_airplay
    end

    if (mode != :music and mode != :radio) and (old_mode == :music or old_mode == :radio)
      disable_music
    end

    if old_mode == :music
      @common.mpd.noidle do |mpd|
        p = mpd.playlists.find { |p| p.name == ".musicplaylist" }
        p.destroy unless p.nil?
        mpd.save ".musicplaylist"
        @music_pos = if mpd.current_song then mpd.current_song.pos else nil end
      end
    end

    if old_mode == :radio
      @common.mpd.noidle do |mpd|
        @radio_station = @common.mpd_status[:song]
        mpd.clear
        mpd.playlists.find { |p| p.name == ".musicplaylist" }.load
        begin
          mpd.play(@music_pos)
        rescue Exception => e
          p e
        end
      end
    end

    if mode != :passthrough
      disable_passthrough
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
    when :passthrough
      enable_passthrough
    end

    mode_name = {radio: "Radio", music: "Music", airplay: "AirPlay", passthrough: "Passthrough"}[mode]
    # EM.system %Q{sudo -u kfigiela tmux display-message -c /dev/pts/1 "Mode: #{mode_name}"}
    @common.lcd_status(mode_name)
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
    when :network_usb
      change_mode :passthrough
    end
  end

  def on_cd_function(function)
    super
    case function
    when :cd
      ir_send :HKHD7325, :KEY_PLAY
    end
  end

  def on_source(source)
    super
    if source == :network
      change_mode (@my_status.last_mode or :music)
    else
      change_mode nil
    end

    unless (source == :cd)
      stop_cd
    end
    unless (source == :analog1)
      stop_tape
    end

    @common.lcd_status({aux1: "Switch", aux2: "TV", cd: "CD", digital: "Mac", tuner: "Tuner", network: "Net"}[source]) if source != :network
  end

  def on_amp_off
    super
    change_mode nil
    stop_cd
    stop_tape
    @common.lcd_backlight = 0
  end

  def on_volume(vol)
    super
    @common.mpd.noidle do |mpd|
      mpd.volume = vol*2
    end
    # EM.system %Q{sudo -u kfigiela tmux display-message -c /dev/pts/1 "Volume #{vol}"}
  end
end
