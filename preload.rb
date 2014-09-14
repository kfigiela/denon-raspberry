class Preload
  def initialize(common)
    # preload
    common.events.mpd_status do
      begin
        music_path = "/storage/music/annex/"
        status   = common.mpd_status
        song     = common.mpd_song
        playlist = common.playlist

        if status[:state] == :play    
          EM.system (%Q{vmtouch -f -t -m 200m #{(music_path + playlist[status[:nextsong]].file).shellescape} > /dev/null}) if status[:nextsong] and playlist[status[:nextsong]]
          EM.system (%Q{vmtouch -f -t -m 200m #{(music_path + song.file).shellescape} > /dev/null}) if common.mpd_song
        end
      rescue Exception => e
        puts "Preloading failed!"
        puts e.message
        puts e.backtrace.inspect
      end
    end
  end
end