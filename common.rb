require_relative 'lirc_handler'

class Common
  # event channels
  attr_reader :events

  # cache
  attr_reader :playlist, :mpd_status
  
  # connections
  attr_reader :mpd, :lirc
  
  def initialize
    @events = Struct.new(:mpd_song, :mpd_status, :mpd_playlist, :denon_status, :lcd_backlight, :lcd_status, :lcd_alerts).new
    @events.mpd_status    = EM::Channel.new
    @events.mpd_playlist  = EM::Channel.new
    @events.denon_status  = EM::Channel.new
    @events.lcd_backlight = EM::Channel.new
    @events.lcd_status    = EM::Channel.new
    @events.lcd_alerts    = EM::Channel.new

    
    @events.mpd_status.subscribe { |status| @mpd_status = status }    
    @events.mpd_playlist.subscribe { update_playlist }
    
    @mpd = MPD.new
    @mpd.connect
    puts "Connected to MPD"    
    @mpd.async_idle

    @lirc = EventMachine.connect_unix_domain "/var/run/lirc/lircd", LIRCHandler, self

    update_playlist
    update_status
    
  end
  
  def update_playlist
    puts "Updating playlist"
    @mpd.noidle_sync do |mpd|
      @playlist = mpd.queue.to_a
    end    
  end
  
  def update_status
    @mpd.noidle_sync do |mpd|
      @mpd_status = @mpd.status
    end
  end
  
  def mpd_song
    if @mpd_status[:song]
      @playlist[@mpd_status[:song]]
    else
      nil
    end
  end
  
  def lcd_backlight=(value)
    @events.lcd_backlight.push value
  end
  
  def lcd_touch
    @events.lcd_backlight.push nil
  end
  
  def lcd_status text
    @events.lcd_status.push text
  end
end