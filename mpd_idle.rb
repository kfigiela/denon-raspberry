class MPDIdle < EM::Connection
  def initialize(common)
    @common = common
  end
  
  def post_init
    @common.mpd.noidle do |mpd|
      song = mpd.current_song
      status = mpd.status
    end
  end
  
  def send_idle
    send_data "idle player options playlist\n"
  end

  def receive_data(data)
    if data =~ /changed: (.*)\n/
      case $1
      when 'options'
        @common.mpd.noidle do |mpd|
          status = mpd.status
          @common.common.events.mpd_status.push status
        end
      when 'player'
        @common.mpd.noidle do |mpd|
          status = mpd.status
          if status.is_a? Hash
            @common.events.mpd_status.push status
          else
            p status
          end
        end
      when 'playlist'
        @common.events.mpd_playlist.push nil
      end
    end
    send_idle
  end
end