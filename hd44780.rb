#!/usr/bin/env ruby

require "i2c"
# require "i2c/driver/i2c-dev"

class I2C_HD44780
  # commands
  LCD_CLEARDISPLAY = 0x01
  LCD_RETURNHOME = 0x02
  LCD_ENTRYMODESET = 0x04
  LCD_DISPLAYCONTROL = 0x08
  LCD_CURSORSHIFT = 0x10
  LCD_FUNCTIONSET = 0x20
  LCD_SETCGRAMADDR = 0x40
  LCD_SETDDRAMADDR = 0x80

  # flags for display entry mode
  LCD_ENTRYRIGHT = 0x00
  LCD_ENTRYLEFT = 0x02
  LCD_ENTRYSHIFTINCREMENT = 0x01
  LCD_ENTRYSHIFTDECREMENT = 0x00

  # flags for display on/off control
  LCD_DISPLAYON = 0x04
  LCD_DISPLAYOFF = 0x00
  LCD_CURSORON = 0x02
  LCD_CURSOROFF = 0x00
  LCD_BLINKON = 0x01
  LCD_BLINKOFF = 0x00

  # flags for display/cursor shift
  LCD_DISPLAYMOVE = 0x08
  LCD_CURSORMOVE = 0x00
  LCD_MOVERIGHT = 0x04
  LCD_MOVELEFT = 0x00

  # flags for function set
  LCD_8BITMODE = 0x10
  LCD_4BITMODE = 0x00
  LCD_2LINE = 0x08
  LCD_1LINE = 0x00
  LCD_5x10DOTS = 0x04
  LCD_5x8DOTS = 0x00

  # flags for backlight control
  LCD_BACKLIGHT = 0x08
  LCD_NOBACKLIGHT = 0x00
  
  En = 0b00000100 # Enable bit
  Rw = 0b00000010 # Read/Write bit
  Rs = 0b00000001 # Register select bit
  
  def initialize
    # @device = I2CDevice.new(address: 0x27, driver: I2CDevice::Driver::I2CDev.new("/dev/i2c-1"))
    @device = I2C::Dev.create("/dev/i2c-1")
    write(0x03)
    sleep(0.0045)
    write(0x03)
    sleep(0.0045)
    write(0x03)
    sleep(0.0045)
    write(0x02)
    sleep(0.0001)

    write(LCD_FUNCTIONSET | LCD_2LINE | LCD_5x8DOTS | LCD_4BITMODE)
    write(LCD_DISPLAYCONTROL | LCD_DISPLAYON)
    write(LCD_CLEARDISPLAY)
    write(LCD_ENTRYMODESET | LCD_ENTRYLEFT)
    @backlight = true
    @mutex = Mutex.new
    
    Kernel::sleep(0.2)
  end
  
  def backlight
    @backlight
  end

  def backlight= value
    unless backlight == value
      @backlight = value
      write 0x80
    end
  end
  
  def backlight_mask
    if @backlight
      LCD_BACKLIGHT
    else
      0
    end
  end
  
  # clocks EN to latch command
  def strobe(data)
    @device.write(0x27, ((data & ~En) | backlight_mask))
    sleep(0.0000001)
    @device.write(0x27, data | En | backlight_mask)
    sleep(0.0000001)
    @device.write(0x27, ((data & ~En) | backlight_mask))
    sleep(0.0000001)
  end

  def write_four_bits(data)
    strobe(data)
  end

  # write a command to lcd
  def write(cmd, mode=0)
    write_four_bits(mode | (cmd & 0xF0))
    write_four_bits(mode | ((cmd << 4) & 0xF0))
    sleep(0.000050)
  end
  

  # put string function
  def puts_sync(string, line)
    write [0x80, 0xC0, 0x94, 0xD4][line-1]
    string.each_char { |c| write(c.ord, Rs) }
  end


  # put string function
  def puts(string, line)
    @mutex.synchronize do 
      write [0x80, 0xC0, 0x94, 0xD4][line-1]
      string.each_char { |c| write(c.ord, Rs) }
    end
  end
  
  def put_lines a, b
    @mutex.synchronize do 
      write 0x80
      a.each_char { |c| write(c.ord, Rs) }
      write 0xc0
      b.each_char { |c| write(c.ord, Rs) }
    end
  end
  
  # clear lcd and set to home
  def clear
    @mutex.synchronize do 
      write(LCD_CLEARDISPLAY)
      write(LCD_RETURNHOME)
    end
  end
  
  def set_udc(index, data)
    @mutex.synchronize do 
      write(0x40 + ((index & 0x07) << 3))
      data.each { |d| write(d, Rs)}
    end
  end
end
