require 'ruby-mpd'
require 'socket'
require "i18n"
require "shellwords"
require_relative "hd44780/hd44780"

def word_wrap(text, col_width=16)
   text.gsub!( /(\S{#{col_width}})(?=\S)/, '\1 ' )
   text.gsub!( /(.{1,#{col_width}})(?:\s+|$)/, "\\1\n" )
   tmp = text.strip.split("\n")
   tmp.map {|l| l.center(col_width)}.join("")
end

def word_wrap2(text, col_width=16)
   text.gsub!( /(\S{#{col_width}})(?=\S)/, '\1 ' )
   text.gsub!( /(.{1,#{col_width}})(?:\s+|$)/, "\\1\n" )
   tmp = text.strip.split("\n")
   tmp.map {|l| l.center(col_width)}
end


class LCD  
  def initialize
    # @lcd = I2C_HD44780.new
    # setup_udc
    HD44780.init
    @counter = 0
    EM.add_periodic_timer(1) { refresh_screen; @counter += 1 }
    @line1 = @line2 = [""]
  end
  
  def setup_udc
    @lcd.set_udc 0, [0x18, 0x14, 0x12, 0x11, 0x12, 0x14, 0x18, 0x00] # play
    @lcd.set_udc 1, [0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x00] # pause
  end
  
  def backlight=(brightness)
    HD44780.backlight = (brightness > 0)
  end

  def touch
    unless HD44780.backlight
      HD44780.backlight = true
      @backlight_timer.cancel if @backlight_timer
      @backlight_timer = EventMachine::Timer.new 10 do
        HD44780.backlight = false
      end
    end
  end
  
  def display_alert(msg)
    HD44780.puts msg.ljust(16), 0
  end

  def display_screen(id, msg)
#     send_data <<-EOM
# screen_add #{id}
# screen_set #{id} -cursor off -heartbeat off -backlight on -priority foreground
# widget_add #{id} txt scroller
# widget_set #{id} txt 1 1 16 2 h 6 "#{msg}"
# EOM
  end

  def remove_screen(id)
    # send_command "screen_del #{id}"
  end

  

  def status_screen(song, status)
    # if song.nil?
#       remove_screen "mpd"
#     else
#       #touch
#       puts "song changed to #{song.artist} - #{song.title}"
#       status_line = "%s %s%s %11s" % [
#         {play: ">", pause: "|", stop: "S"}[status[:state]],
#         if status[:repeat] then "R" else " " end,
#         if status[:random] then "Z" else " " end,
#         "#{status[:song]+1}/#{status[:playlistlength]}"
#       ]
#       title_line = I18n.transliterate((song.title or File.basename(song.file, ".*"))).center(16)
#
#       send_data <<-EOM
# screen_add mpd
# screen_set mpd -timeout 80 -cursor off -heartbeat off -backlight on -priority alert
# widget_add mpd txt string
# widget_set mpd txt 1 1 "#{status_line}"
# widget_add mpd txt2 string
# widget_set mpd txt2 1 2 "#{title_line}"
# EOM
#    end
  end

  def puts string, line
    HD44780.puts string, line
  end

  def puts_sync string, line
    HD44780.puts string, line
  end
  
  def song_screen(song, status)
    @song = song
    @status = status
    update_screen
  end
  
  def update_screen
    return unless @status and @song
    status = @status
    song = @song
    if status[:state] == :stop or status[:state] == :pause or song.nil?
      # EM.defer do
        @line1 = ["\1               "]
        @line2 = [Time.now.strftime("%H:%M:%S").ljust(16)]
      # end
    else   
      #touch   
      artist = word_wrap2 (I18n.transliterate (song.artist or ''))
      # title = (I18n.transliterate (song.title or File.basename(song.file, ".*"))).center(16)
      title = word_wrap2(I18n.transliterate (song.title or File.basename(song.file, ".*")))
      # EM.defer do
      @line1 = artist
      @line2 = title
      # end    
    end
    @counter = 0
    refresh_screen
  end

  def refresh_screen
    if @status[:state] == :stop or @status[:state] == :pause or @song.nil?
      @line2 = [Time.now.strftime("%H:%M:%S").ljust(16)]
    end
    
    HD44780.puts @line1[(@counter/2) % @line1.length].ljust(16), 0
    HD44780.puts @line2[(@counter/2) % @line2.length].ljust(16), 1
  end
end
