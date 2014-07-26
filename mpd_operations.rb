require 'ruby-mpd'
require 'benchmark'

module MPDOperations
  def playlist
    @playlist
  end
  
  def load_playlist(name, pos = nil)
    @mpd.noidle do |mpd|
      mpd.clear
      mpd.playlists.find { |p| p.name == name }.load
      mpd.play(pos)
    end
  end 

  def load_playlist_by_index(index, pos = nil)
    @mpd.noidle do |mpd|
      mpd.clear
      playlists = mpd.playlists
      playlists.sort_by! { |p| p.name }
      playlists[index].load if playlists[index]
      mpd.play(pos)
    end
  end 
  
  def mpd_status(song, status)
    @mpd_song = song
    @mpd_status = status
  end
  
  def ensure_status
    unless @mpd_song
      @mpd.noidle do |mpd|        
        @mpd_song = mpd.current_song
      end
    end

    unless @mpd_status
      @mpd.noidle do |mpd|        
        @mpd_status = mpd.status
      end
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
  
  def preload_playlist
    @mpd.noidle_sync do |mpd|
      @playlist = mpd.queue.to_a
    end
  end
  
  
  def mpd_next_album
    preload_playlist unless @playlist
    ensure_status
    
    @mpd.noidle do |mpd|
      idx = @playlist[(@mpd_status[:song])..(@mpd_status[:playlistlength])].find_index{|s| s.album != @mpd_song.album }
      mpd.play @mpd_status[:song] + idx if idx
    end
  end
  
  def mpd_prev_album
    preload_playlist unless @playlist
    ensure_status
    
    @mpd.noidle do |mpd|
      if @mpd_status[:song] > 0
        current_song = @playlist[@mpd_status[:song]-1]
        idx = @playlist[0...(@mpd_status[:song])].rindex {|s| s.album != current_song.album }
        mpd.play (idx+1) if idx
      end
    end
  end
end