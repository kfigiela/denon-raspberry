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

  def preload(song, status)
    music_path = "/storage/music/annex/"
    if status[:state] == :play    
      commands = []
      commands << (%Q{vmtouch -f -t -m 200m #{(music_path + @mpd.queue[status[:nextsong]].file).shellescape} }) if status[:nextsong]
      commands << (%Q{vmtouch -f -t -m 200m #{(music_path + @mpd.current_song.file).shellescape}  })
      EM.defer { commands.each { |c| system(c) } }
    end
    
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
          
          preload(song, status)
          @lcd.song_screen(song,status)
          @lcd.status_screen(song,status)
        end
      end
    end
    send_idle
  end
end