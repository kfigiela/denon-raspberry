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
  def initialize(common)
    # @lcd = I2C_HD44780.new
    # setup_udc
    @common = common
    HD44780.init
    @counter = 0
    EM.add_periodic_timer(1) { refresh_screen; @counter += 1 }
    @line1 = @line2 = [""]
    @status = "Hello!"
    
    @common.events.mpd_status.subscribe { update_screen }
    @common.events.lcd_backlight.subscribe { |brightness| if brightness.nil? then touch else self.backlight = brightness end}
    @common.events.lcd_status.subscribe { |text| @status = text; update_screen }
    update_screen
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

  def puts string, line
    HD44780.puts string, line
  end

  def puts_sync string, line
    HD44780.puts string, line
  end
  

  def update_screen
    status = @common.mpd_status
    song = @common.mpd_song

    return unless status and song

    if status[:state] == :stop or status[:state] == :pause or song.nil?
      # EM.defer do
        @line1 = ["\1 #{@status.rjust 14}"]
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
    if @common.mpd_status[:state] == :stop or @common.mpd_status[:state] == :pause or @common.mpd_song.nil?
      @line2 = [Time.now.strftime("%H:%M:%S").ljust(16)]
    end
    
    HD44780.puts @line1[(@counter/2) % @line1.length].ljust(16), 0
    HD44780.puts @line2[(@counter/2) % @line2.length].ljust(16), 1
  end
end
