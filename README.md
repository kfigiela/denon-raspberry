Denon DRA-F109 integration with Raspberry Pi
===============

App for integrating Denon DRA-F109 stereo receiver with Raspberry Pi. See the blog posts:

 * http://kfigiela.github.io/2014/06/15/denon-remote-connector/
 * http://kfigiela.github.io/2014/06/20/denon-meets-raspberrypi/
 
Also, thread at Raspberry Pi forum: http://www.raspberrypi.org/forums/viewtopic.php?f=35&t=80037


## Repository contents

* `demo.rb` – demo example of Denon DRA-F109 protocol parser
* `main.rb` – main executable for my setup (covers Denon, MPD, lcdproc and ncmpcpp integration)
* `denon.rb` – Denon protocol parser
* `my_denon.rb` – logic of DRA-F109 integration in my setup
* `lcd.rb` – logic for LCD screen
* `mpd.rb` – monkeypatch `ruby-mpd` to add idle support
* `mpd_idle.rb` – MPD idle with EventMachine for LCD updates
* 
## How to use

* Clone repo
* `bundle install`
* `ruby demo.rb`
