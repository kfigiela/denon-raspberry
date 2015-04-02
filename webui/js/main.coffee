Button = React.createClass
  handleClick: (evt) -> 
    evt.preventDefault()
    this.props.onCommand(this.props.command)
  render: ->
    <a href="#" onClick={this.handleClick} className="btn btn-default" {...this.props}>{this.props.children}</a>


Icon = React.createClass
  render: ->
    <i className={"fa "+this.props.name}/>

 ModeSelector =  React.createClass
  modes: [
      {command:"ir:SRC_DRA_TUNER", icon:"fa-rss", name: "Tuner"},
      {command:"ir:SRC_DNP_INTERNET_RADIO", icon:"fa-signal", name:"Internet Radio"},
      {command:"ir:SRC_DNP_ONLINE_MUSIC", icon:"fa-music", name:"Music Player"},
      {command:"ir:SRC_DNP_MUSIC_SERVER", icon:"fa-toggle-down", name: "AirPlay"},
      {command:"ir:SRC_DCD_CD", icon:"fa-dot-circle-o", name: "CD"},
      {command:"ir:SRC_DRA_DIGITAL", icon:"fa-laptop", name: "Digital"},
      {command:"ir:SRC_DRA_ANALOG", icon:"fa-external-link-square", name: "Analog"}
  ]
  network_modes: {
      radio: {icon:"fa-signal", name:"Internet Radio"},
      music: {icon:"fa-music", name:"Music Player"},
      airplay: {icon:"fa-toggle-down", name: "AirPlay"},
      null: {icon:"fa-rss", name: "Network Player"},
  }
  sources: {
    network: {icon: "fa-music", name: "Network"},
    cd: {icon: "fa-dot-circle-o", name: "CD"},
    aux1: {icon: "fa-external-link-square", name: "Analog 1"},
    aux2: {icon: "fa-external-link-square", name: "Analog 2"},
    tuner: {icon: "fa-rss", name: "Tuner"},
    digital: {icon: "fa-laptop", name: "Digital"}
  }

  render: ->
    modeButtons =  this.modes.map (mode) =>
      (<li key={mode.command}><Button onCommand={this.props.onCommand} command={mode.command} className="btn-ws"><Icon name={mode.icon}/> {mode.name}</Button></li>)

    currentSource = 
      if(this.props.data.denon.amp.power == "on")
        if(this.props.data.denon.amp.source != "network")
          this.sources[this.props.data.denon.amp.source]
        else
          this.network_modes[this.props.data.denon.mode]
      else
        {icon: "fa-power-off", name: "Off"}

    document.title = currentSource.name + " | " + this.props.data.denon.amp.audio.volume + " 🔊"

    <div>
      <a href="#" data-toggle="dropdown" className="navbar-brand dropdown-toggle"><Icon name={currentSource.icon}/> {currentSource.name} <b className="caret"></b></a>
      <ul className="dropdown-menu">
        {modeButtons}
      </ul>
    </div>


Header = React.createClass
  render: ->
    sleepStatus = if(this.props.data.denon.amp.sleep && (Date.parse(this.props.data.denon.amp.sleep) - Date.now()) > 0)
        Math.round((Date.parse(this.props.data.denon.amp.sleep) - Date.now()) / 60000) + " mins"
      else
        "off"

    <nav className="navbar">
      <div className="container">
        <div className="navbar-header">
          <button type="button" data-toggle="collapse" data-target=".navbar-collapse" className="navbar-toggle">
            <Icon name="fa-bars"/>
          </button>
          <ModeSelector data={this.props.data} onCommand={this.props.onCommand} />
        </div>
        <div className="navbar-collapse collapse">
          <ul className="nav navbar-nav navbar-right">
            <li><Button onCommand={this.props.onCommand} command="ir:KEY_POWER" className="btn-ws"><Icon name="fa-power-off"/> Power ({this.props.data.denon.amp.power})</Button></li>
            <li><Button onCommand={this.props.onCommand} command="ir:KEY_DISPLAYTOGGLE" className="btn-ws"><Icon name="fa-sun-o"/> Display ({this.props.data.denon.amp.display_brightness})</Button></li>
            <li><Button onCommand={this.props.onCommand} command="ir:KEY_SLEEP" className="btn-ws"><Icon name="fa-clock-o"/> Sleep ({sleepStatus})</Button></li>
          </ul>
        </div>
      </div>
    </nav>

CDMode = React.createClass
  handleClick: (evt) ->
    evt.preventDefault()
    this.props.onCommand($(evt.currentTarget).data('command'))

  render: ->
    <div>
      <div className="btn-group btn-group-lg btn-group-justified">
        <Button command="cd_ir:CD_PLAY"  onCommand={this.props.onCommand}><Icon name="fa-play"/></Button>
        <Button command="cd_ir:CD_PAUSE" onCommand={this.props.onCommand}><Icon name="fa-pause"/></Button>
        <Button command="cd_ir:CD_STOP"  onCommand={this.props.onCommand}><Icon name="fa-stop"/></Button>
      </div>
      <div className="btn-group btn-group-lg btn-group-justified">
        <Button command="cd_ir:CD_BKW"  onCommand={this.props.onCommand}><Icon name="fa-backward"/></Button>
        <Button command="cd_ir:CD_PREV" onCommand={this.props.onCommand}><Icon name="fa-fast-backward"/></Button>
        <Button command="cd_ir:CD_NEXT" onCommand={this.props.onCommand}><Icon name="fa-fast-forward"/></Button>
        <Button command="cd_ir:CD_FWD"  onCommand={this.props.onCommand}><Icon name="fa-forward"/></Button>
      </div>
    </div>

TunerMode = React.createClass
  render: ->
    stationName = if(this.props.data.denon.amp.radio.current_preset && this.props.data.denon.amp.radio.presets[this.props.data.denon.amp.radio.current_preset])
        this.props.data.denon.amp.radio.presets[this.props.data.denon.amp.radio.current_preset].name
      else
        this.props.data.denon.amp.radio.current_frequency.toFixed(2) + " MHz"

    stations = Object.keys(this.props.data.denon.amp.radio.presets).map (id) => 
      station = this.props.data.denon.amp.radio.presets[id]
      addClass = if this.props.data.denon.amp.radio.current_preset == id then "btn-primary" else ""

      <Button onCommand={this.props.onCommand} key={"st_" + id} className={"col-xs-6 btn btn-default btn-lg " + addClass} command={"tuner:tune:" + id}>{station.name}</Button>
    
    <div>
      <h1>{stationName}</h1>
      <div className="row btn-group">
      {stations}
      </div>
    </div>

MusicMode = React.createClass
  render: ->
    currentSong = if this.props.data.mpd.song
      <div>
        <h1>{this.props.data.mpd.song.artist}</h1>
        <h2>{this.props.data.mpd.song.title}</h2>
        <h4>{this.props.data.mpd.song.album}</h4>
      </div>
    else
      <h1>Stopped</h1>
      
    <div>
      <div className="btn-group btn-group-lg btn-group-justified">
        <Button onCommand={this.props.onCommand} command="mpd:prev_album"><Icon name="fa-arrow-circle-left"/></Button>
        <Button onCommand={this.props.onCommand} command="mpd:prev"><Icon name="fa-fast-backward"/></Button>
        <Button onCommand={this.props.onCommand} command="mpd:pause"><Icon name={ if (this.props.data.mpd.status.state == "play") then "fa-pause" else "fa-play"}/></Button>
        <Button onCommand={this.props.onCommand} command="mpd:next"><Icon name="fa-fast-forward"/></Button>
        <Button onCommand={this.props.onCommand} command="mpd:next_album"><Icon name="fa-arrow-circle-right"/></Button>
      </div>

      {currentSong}
    </div>

InfoMode = React.createClass
  render: -> <h1 style={{textAlign: "center"}}><Icon name={this.props.icon + " fa-4x"}/><br/><br/> {this.props.children}</h1>

Volume = React.createClass
  handleClick: (evt) ->
    evt.preventDefault()
    this.props.onCommand($(evt.currentTarget).data('command'))

  render: ->
    getVolume = =>
      if(this.props.data.denon.amp.audio.mute)
        <i className="fa fa-volume-off"/>
      else
        this.props.data.denon.amp.audio.volume

    <nav className="navbar navbar-fixed-bottom">
      <div className="container">
        <div className="btn-group btn-group-lg btn-group-justified">
          <Button onCommand={this.props.onCommand} command="ir:KEY_VOLUMEDOWN"><Icon name="fa-minus"/></Button>
          <Button onCommand={this.props.onCommand} command="ir:KEY_MUTE">{getVolume()}</Button>
          <Button onCommand={this.props.onCommand} command="ir:KEY_VOLUMEUP"><Icon name="fa-plus"/></Button>
        </div>
      </div>
    </nav>

DenonUI = React.createClass
  componentDidMount: ->
    this.ws = new WebSocket("ws://10.0.42.42:8080")
    this.ws.onmessage = (m) => 
      status = JSON.parse(m.data)
      this.setState({data: status})

  handleCommand: (cmd) ->
    this.ws.send(cmd)

  render: ->
    if(this.state)
      currentMode = if(this.state.data.denon.amp.power == "on")
        switch this.state.data.denon.amp.source
          when "cd" then <CDMode data={this.state.data} onCommand={this.handleCommand} />
          when "tuner" then <TunerMode data={this.state.data} onCommand={this.handleCommand} />
          when "network"
            switch(this.state.data.denon.mode)
              when "radio" then <MusicMode data={this.state.data} onCommand={this.handleCommand} />
              when "music" then <MusicMode data={this.state.data} onCommand={this.handleCommand} />
              when "airplay" then <InfoMode icon="fa-toggle-down">AirPlay</InfoMode>
              else <h1>Network player</h1>
          when "digital" then <InfoMode icon="fa-laptop fa-4x">Digital</InfoMode>
          when "aux1" then <InfoMode icon="fa-external-link-square">Analog 1</InfoMode>
          when "aux2" then <InfoMode icon="fa-external-link-square">Analog 2</InfoMode>
          else <div>not supported</div>
      else
        <InfoMode icon="fa-power-off"><Button onCommand={this.handleCommand} command="ir:KEY_POWER" className="btn btn-lg btn-success btn-ws">Turn on!</Button></InfoMode>

      <div>
        <Header data={this.state.data} onCommand={this.handleCommand}/>
        {currentMode}
        <Volume data={this.state.data} onCommand={this.handleCommand}/>
      </div>
    else
      <div>connecting…</div>

React.render(<DenonUI/>, document.getElementById('app'))

