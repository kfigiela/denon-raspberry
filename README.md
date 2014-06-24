Denon DRA-F109 integration with Raspberry Pi
===============

App for integrating Denon DRA-F109 stereo receiver with Raspberry Pi. See the blog posts:

 * http://kfigiela.github.io/2014/06/15/denon-remote-connector/
 * http://kfigiela.github.io/2014/06/20/denon-meets-raspberrypi/
 
Also, thread at Raspberry Pi forum: http://www.raspberrypi.org/forums/viewtopic.php?f=35&t=80037


## Repository contents

### Executables
* `demo.rb` – demo example of Denon DRA-F109 protocol parser
* `mpd_demo.rb` – basic MPD support with AirPlay switching support
* `main.rb` – main executable for my setup (covers Denon, MPD, lcdproc, ncmpcpp integration, IR blaster for CD player)


### Other files

* `denon.rb` – Denon protocol parser
* `my_denon.rb` – logic of DRA-F109 integration in my setup
* `lcd.rb` – logic for lcdproc screen
* `mpd.rb` – monkeypatch `ruby-mpd` to add idle support
* `mpd_idle.rb` – MPD idle with EventMachine for LCD updates and preloading audio files to memory
* 
## How to use

* Clone repo
* `bundle install`
* `ruby demo.rb` or `ruby mpd_demo.rb`
