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
   if tmp.length == 0
     ["-".center(16)]    
   elsif tmp.length == 1     
     tmp.map {|l| l.center(col_width)}
   elsif tmp.length == 2
     [tmp[0].ljust(col_width), tmp[-1].rjust(col_width)]
   else 
     [tmp[0].ljust(col_width)] + tmp[1...-1].map { |l| l.center(col_width) } + [tmp[-1].rjust(col_width)]
   end
end


class LCD  
  def initialize(common)
    # @lcd = I2C_HD44780.new
    setup_udc
    @common = common
    @prev_mpd_status = @common.mpd_status
    HD44780.init
    @counter = 0
    EM.add_periodic_timer(1) { refresh_screen; @counter += 1 }
    @line1 = @line2 = [""]
    @status = nil

    @mode = 0
    @total_modes = 2
    
    @common.events.mpd_status.subscribe { check_mpd_alerts; update_screen; }
    @common.events.lcd_backlight.subscribe { |brightness| if brightness.nil? then touch else self.backlight = brightness end}
    @common.events.lcd_status.subscribe { |text| @status = text; update_screen }
    @common.events.lcd_alerts.subscribe { |line1, line2| display_alert(line1, line2) }
    @common.events.actions.subscribe do |action|
      case action
      when :info
        @mode = (@mode + 1) % @total_modes
        Kernel.puts "Display mode #{@mode}"
        update_screen
      end
    end
    
    update_screen
  end
  
  def setup_udc
    # HD44780.set_udc 1, [0x18, 0x14, 0x12, 0x11, 0x12, 0x14, 0x18, 0x00] # play
    HD44780.set_udc 0, [0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x00] # pause
  end
  
  def backlight=(brightness)
    @backlight_timer.cancel if @backlight_timer    
    HD44780.backlight = (brightness > 0)
  end

  def touch
    unless HD44780.backlight
      HD44780.backlight = true
      @backlight_timer.cancel if @backlight_timer
      @backlight_timer = EventMachine::Timer.new 10 do
        HD44780.backlight = false
        @backlight_timer = nil
      end
    end
  end
  
  def display_alert(line1, line2 = "")
    @alert_timer.cancel if @alert_timer    
    @alert_timer = EventMachine::Timer.new 4 do
      @alert_timer = nil
      update_screen
    end
    @line1 = [(I18n.transliterate line1.to_s)]
    @line2 = [(I18n.transliterate line2.to_s)]
    EM.system %Q{sudo -u kfigiela tmux display-message -c /dev/pts/1 "#{line1.to_s} #{line2.to_s}"}
    update_screen
  end

  def puts string, line
    HD44780.puts string, line
  end

  def puts_sync string, line
    HD44780.puts string, line
  end
  

  def check_mpd_alerts
    # if @common.mpd_status[:random] != @prev_mpd_status[:random]
    #   display_alert("Random #{if @common.mpd_status[:random] then "On" else "Off" end}")
    # end
    # if @common.mpd_status[:repeat] != @prev_mpd_status[:repeat]
    #   display_alert("Repeat #{if @common.mpd_status[:repeat] then "On" else "Off" end}")
    # end
    @prev_mpd_status = @common.mpd_status
  end

  def update_screen
    status = @common.mpd_status
    song = @common.mpd_song

    if @alert_timer
      # do nothing
    elsif status[:state] == :stop or status[:state] == :pause or song.nil?
        @line1 = ["\0 #{(@status or "---").rjust 14}"]
        @line2 = [Time.now.strftime("%H:%M:%S").ljust(16)]
    else
      case @mode
      when 0
        artist = word_wrap2 (I18n.transliterate (song.artist or song.name or ""))
        title = word_wrap2 (I18n.transliterate (song.title or File.basename(song.file, ".*")))
        @line1 = artist
        @line2 = title
      when 1
        @line1 = ["#{song.length.rjust(6)} " + "#{status[:song]+1}/#{status[:playlistlength]}".rjust(9)]
        @line2 = word_wrap2 (I18n.transliterate (song.title or File.basename(song.file, ".*")))
      end
    end
    @counter = 0
    refresh_screen
  end

  def refresh_screen
    if (@common.mpd_status[:state] == :stop or @common.mpd_status[:state] == :pause or @common.mpd_song.nil?) and @alert_timer.nil?
      @line2 = [Time.now.strftime("%H:%M:%S").ljust(16)]
    end
    
    HD44780.puts @line1[(@counter/2) % @line1.length].ljust(16), 0
    HD44780.puts @line2[(@counter/2) % @line2.length].ljust(16), 1
  end
end
