class MPDIdle < EM::Connection
  def initialize(mpd, lcd)
    @mpd = mpd
    @lcd = lcd
  end
  
  def post_init
    @mpd.noidle do |mpd|
      song = mpd.current_song
      status = mpd.status
      
      @lcd.status_screen(song,status)
      @lcd.song_screen(song,status)
    end
  end
  
  def send_idle
    send_data "idle player options\n"
  end

  def receive_data(data)
    if data =~ /changed: (.*)\n/
      case $1
      when 'options'
        @mpd.noidle do |mpd|
          song = mpd.current_song
          status = mpd.status
          
          @lcd.status_screen(song,status)
        end
      when 'player'
        @mpd.noidle do |mpd|
          song = mpd.current_song
          status = mpd.status
          
          @lcd.song_screen(song,status)
          @lcd.status_screen(song,status)
        end
      end
    end
    send_idle
  end
end