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
    send_data "idle player options playlist mixer\n"
  end

  def receive_data(data)
    if data =~ /changed: (.*)\n/
      case $1
      when 'options'
        @common.mpd.noidle do |mpd|
          status = mpd.status
          @common.events.mpd_status.push status
        end
      when 'mixer'
        puts "MIXER"
        @common.mpd.noidle do |mpd|
          volume = mpd.volume
          @common.events.mpd_volume.push volume
        end
      when 'player'
        @common.mpd.noidle do |mpd|
          status = mpd.status
          if status.is_a? Hash
            @common.events.mpd_status.push status
          else
            puts "bad status"
            p status
          end
        end
      when 'playlist'
        @common.mpd.noidle do |mpd|
          status = mpd.status
          @common.events.mpd_status.push status
        end
        @common.events.mpd_playlist.push nil
      else 
        puts "unknown #{$1}"
      end
    end
    send_idle
  end
end
