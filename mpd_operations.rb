require 'ruby-mpd'
require 'benchmark'

module MPDOperations
  def playlist
    @playlist
  end
  
  def load_playlist(name, pos = nil)
    @common.mpd.noidle do |mpd|
      mpd.clear
      mpd.playlists.find { |p| p.name == name }.load
      mpd.play(pos)
    end
  end 

  def load_playlist_by_index(index, pos = nil)
    @common.mpd.noidle do |mpd|
      mpd.clear
      playlists = mpd.playlists
      playlists.sort_by! { |p| p.name }
      playlists[index].load if playlists[index]
      mpd.play(pos)
    end
  end 



  def mpd(action)
    @common.mpd.noidle do |mpd|
      mpd.send(action)
    end
  end

  def mpd_toggle(action)
    @common.mpd.noidle do |mpd|
      mpd.send("#{action.to_s}=".to_sym, (not mpd.status[action.to_sym]))
    end
  end

  def mpd_pause
    @common.mpd.noidle do |mpd|
      if mpd.playing?
        mpd.pause = 1
      else
        mpd.play
      end
    end
  end
  
  def preload_playlist
    @common.mpd.noidle_sync do |mpd|
      @playlist = mpd.queue.to_a
    end
  end
  
  
  def mpd_next_album
    @common.mpd.noidle do |mpd|
      idx = @common.playlist[(@common.mpd_status[:song])..(@common.mpd_status[:playlistlength])].find_index{|s| s.album != @common.mpd_song.album }
      mpd.play @common.mpd_status[:song] + idx if idx
    end
  end
  
  def mpd_prev_album
    @common.mpd.noidle do |mpd|
      if @common.mpd_status[:song] > 0
        current_song = @common.playlist[@common.mpd_status[:song]-1]
        idx = @common.playlist[0...(@common.mpd_status[:song])].rindex {|s| s.album != current_song.album }
        mpd.play (idx+1) if idx
      end
    end
  end
end