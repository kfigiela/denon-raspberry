class MPDIdle < EM::Connection
  def initialize(mpd, lcd, denon, ui)
    @mpd = mpd
    @lcd = lcd
    @denon = denon
    @ui = ui
  end
  
  def post_init
    @mpd.noidle do |mpd|
      song = mpd.current_song
      status = mpd.status
      @ui.on_mpd(song, status)
      @denon.mpd_status(song, status)
      @lcd.status_screen(song,status)
      @lcd.song_screen(song,status)
    end
  end
  
  def send_idle
    send_data "idle player options playlist\n"
  end

  def preload(song, status)
    music_path = "/storage/music/annex/"
    if status[:state] == :play    
      commands = []
      commands << (%Q{vmtouch -f -t -m 200m #{(music_path + @denon.playlist[status[:nextsong]].file).shellescape} > /dev/null}) if status[:nextsong] and @denon.playlist[status[:nextsong]]
      commands << (%Q{vmtouch -f -t -m 200m #{(music_path + song.file).shellescape} > /dev/null}) if song
      EM.defer { commands.each { |c| system(c) } }
    end
  rescue Exception => e
    puts "Preloading failed!"
    puts e.message
    puts e.backtrace.inspect
  end

  def receive_data(data)
    if data =~ /changed: (.*)\n/
      case $1
      when 'options'
        @denon.preload_playlist unless @denon.playlist        
        @mpd.noidle do |mpd|
          # song = mpd.current_song
          song = @denon.playlist[status[:song]]
          status = mpd.status
          
          @lcd.status_screen(song,status)
          @ui.on_mpd(song, status)          
        end
      when 'player'
        @denon.preload_playlist unless @denon.playlist
        @mpd.noidle do |mpd|
          # song = mpd.current_song
          status = mpd.status
          if status.is_a? Hash
            song = @denon.playlist[status[:song]]
            @lcd.song_screen(song,status)
            preload(song, status)
            @denon.mpd_status(song, status)
            # @lcd.status_screen(song,status)
            @ui.on_mpd(song, status)
          else
            p status
          end
        end
      when 'playlist'
        @denon.preload_playlist
      end
    end
    send_idle
  end
end