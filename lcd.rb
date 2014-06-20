require 'ruby-mpd'
require 'socket'
require "i18n"
require "shellwords"


def word_wrap(text, col_width=16)
   text.gsub!( /(\S{#{col_width}})(?=\S)/, '\1 ' )
   text.gsub!( /(.{1,#{col_width}})(?:\s+|$)/, "\\1\n" )
   tmp = text.strip.split("\n")
   tmp.map {|l| l.center(col_width)}.join("")
end

class LCD < EM::Connection
  
  def post_init
    send_command "hello"
  end
  
  def receive_data(data)
    nil # just ignore
  end
  
  def send_command(commands)
    if commands.is_a? Enumerable
      send_data commands.map {|c| c + "\n"}.join
    else 
      send_data commands + "\n"
    end
  end
  
  def backlight=(brightness)
    @@backlight = brightness
    pin = 18 # gpio 
    system "gpio -g pwm #{pin} #{brightness}"
  end
  
  def backlight
    @@backlight
  end
  
  def display_alert(msg)
    send_data <<-EOM
screen_add lcd_alert
screen_set lcd_alert -cursor off -heartbeat off -backlight on -priority alert -timeout 80
widget_add lcd_alert txt scroller
widget_set lcd_alert txt 1 1 16 2 h 6 "#{msg}"
EOM
  end

  def display_screen(id, msg)
    send_data <<-EOM 
screen_add #{id}
screen_set #{id} -cursor off -heartbeat off -backlight on -priority foreground
widget_add #{id} txt scroller
widget_set #{id} txt 1 1 16 2 h 6 "#{msg}"
EOM
  end

  def remove_screen(id)
    send_command "screen_del #{id}"
  end

  

  def status_screen(song, status)
    return if song.nil?
    puts "song changed to #{song.artist} - #{song.title}"
    status_line = "%s %s%s %11s" % [
      {play: ">", pause: "|", stop: "S"}[status[:state]], 
      if status[:repeat] then "R" else " " end,
      if status[:random] then "Z" else " " end, 
      "#{status[:song]+1}/#{status[:playlistlength]}"
    ]
    title_line = I18n.transliterate((song.title or File.basename(song.file, ".*"))).center(16)

    send_data <<-EOM
screen_add mpd
screen_set mpd -timeout 80 -cursor off -heartbeat off -backlight on -priority input
widget_add mpd txt scroller
widget_set mpd txt 1 1 16 1 v 6 "#{status_line}"
widget_add mpd txt2 scroller
widget_set mpd txt2 1 2 16 2 h 6 "#{title_line}"
EOM
  end

  def song_screen(song, status)
    return if song.nil?

    if status[:state] == :stop or status[:state] == :pause
      remove_screen "mpd_info"
      send_data "screen_del mpd_info\n"
    else      
      artist = (I18n.transliterate (song.artist or '')).center(16)
      title = (I18n.transliterate (song.title or File.basename(song.file, ".*"))).center(16)

      send_data <<-EOM
screen_add mpd_info
screen_set mpd_info -cursor off -heartbeat off -backlight on -priority foreground
widget_add mpd_info artist scroller
widget_add mpd_info title scroller
widget_set mpd_info artist 1 1 16 1 h 6 "#{artist}"
widget_set mpd_info title 1 2 16 2 h 6 "#{title}"
EOM
    end
  end
end