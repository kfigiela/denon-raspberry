require 'ruby-mpd'
require 'benchmark'

module MPDOperations
  def load_playlist(name, pos = nil)
    @common.mpd.noidle do |mpd|
      mpd.clear
      mpd.playlists.find { |p| p.name == name }.load
      mpd.play(pos)
    end
  end 

  def load_playlist_by_index(index, pos = 0)
    @common.mpd.noidle do |mpd|
      mpd.stop
      mpd.clear
      playlists = mpd.playlists
      playlists.reject! {|p| p.name =~ /^\./}.sort_by! { |p| p.name }
      if playlists[index]
        @common.events.lcd_alerts.push ["Playlist:", playlists[index].name]
        playlists[index].load
        mpd.play(pos) if pos
      end
    end
  end 



  def mpd(action)
    @common.mpd.noidle do |mpd|
      mpd.send(action)
    end
  end

  def mpd_toggle(action, val = nil)
    @common.mpd.noidle do |mpd|
      val = (not mpd.status[action.to_sym]) if val.nil?
      mpd.send("#{action.to_s}=".to_sym, val)
    end
  end

  def mpd_pause
    @common.mpd.noidle do |mpd|
      if mpd.playing?
        if mpd.current_song.time.nil? # for radio streams
          mpd.stop
        else
          mpd.pause = 1
        end
      else
        mpd.play
      end
    end
  end
  
  
  def mpd_next_album
    @common.mpd.noidle do |mpd|
      idx = @common.playlist[(@common.mpd_status[:song])..(@common.mpd_status[:playlistlength])].find_index{|s| s.album != @common.mpd_song.album }
      if idx
        @common.events.lcd_alerts.push ["Album:", @common.playlist[@common.mpd_status[:song] + idx].album]
        mpd.play @common.mpd_status[:song] + idx
      end
    end
  end
  
  def mpd_prev_album
    @common.mpd.noidle do |mpd|
      if @common.mpd_status[:song] > 0
        current_song = @common.playlist[@common.mpd_status[:song]-1]
        idx = @common.playlist[0...(@common.mpd_status[:song])].rindex {|s| s.album != current_song.album }
        if idx
          @common.events.lcd_alerts.push ["Album:", @common.playlist[idx+1].album]
          mpd.play (idx+1) 
        end
      end
    end
  end
end