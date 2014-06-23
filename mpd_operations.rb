module MPDOperations
  def load_playlist(name, pos = nil)
    @mpd.noidle do |mpd|
      mpd.clear
      mpd.playlists.find { |p| p.name == name }.load
      mpd.play(pos)
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
end