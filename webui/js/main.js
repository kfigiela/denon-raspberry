var Button = React.createClass({
  handleClick: function(evt) {
    evt.preventDefault()
    this.props.onCommand(this.props.command)
  },
  render: function() {
    return <a href="#" onClick={this.handleClick} className="btn btn-default" {...this.props}>{this.props.children}</a>
  }
});

var Icon = React.createClass({
  render: function() {
    return <i className={"fa "+this.props.name}/>
  }
});

var ModeSelector =  React.createClass({
  modes: [
    {command:"ir:SRC_DRA_TUNER", icon:"fa-rss", name: "Tuner"}, 
    {command:"ir:SRC_DNP_INTERNET_RADIO", icon:"fa-signal", name:"Internet Radio"}, 
    {command:"ir:SRC_DNP_ONLINE_MUSIC", icon:"fa-music", name:"Music Player"}, 
    {command:"ir:SRC_DNP_MUSIC_SERVER", icon:"fa-toggle-down", name: "AirPlay"}, 
    {command:"ir:SRC_DCD_CD", icon:"fa-dot-circle-o", name: "CD"}, 
    {command:"ir:SRC_DRA_DIGITAL", icon:"fa-laptop", name: "Digital"}, 
    {command:"ir:SRC_DRA_ANALOG", icon:"fa-external-link-square", name: "Analog"}    
  ],
  
  sources: {
    network: {icon: "fa-music", name: "Network"}, 
    cd: {icon: "fa-dot-circle-o", name: "CD"}, 
    aux1: {icon: "fa-external-link-square", name: "Analog 1"}, 
    aux2: {icon: "fa-external-link-square", name: "Analog 2"}, 
    tuner: {icon: "fa-rss", name: "Tuner"}, 
    digital: {icon: "fa-laptop", name: "Digital"}
  },
    
  render: function() {
    var modeButtons =  this.modes.map(function (mode) {
      return (<li><Button key={mode.command} onCommand={this.props.onCommand} command={mode.command} className="btn-ws"><Icon name={mode.icon}/> {mode.name}</Button></li>)
    }.bind(this));
    return (
      <div>
        <a href="#" data-toggle="dropdown" className="navbar-brand dropdown-toggle"><span className="current"><Icon name={this.sources[this.props.data.denon.amp.source].icon}/> {this.sources[this.props.data.denon.amp.source].name}</span>   <b className="caret"></b></a>
        <ul className="dropdown-menu">
          {modeButtons}
        </ul>
      </div>
    );
  }
});

var Header = React.createClass({
  render: function() {
    var sleepStatus;
    
    if(this.props.data.denon.amp.sleep && (Date.parse(this.props.data.denon.amp.sleep) - Date.now()) > 0)
      sleepStatus =  Math.round((Date.parse(this.props.data.denon.amp.sleep) - Date.now()) / 60000) + " mins"
    else 
      sleepStatus = "off"
    
    return (
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
    );
  }
});

var CDMode = React.createClass({
  handleClick: function(evt) {
    evt.preventDefault()
    this.props.onCommand($(evt.currentTarget).data('command'))
  },
  render: function() {
    return (
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
    )
  }
});

var TunerMode = React.createClass({
  render: function() {
    var stationName;
    
    if(this.props.data.denon.amp.radio.current_preset && this.props.data.denon.amp.radio.presets[this.props.data.denon.amp.radio.current_preset])
      stationName = this.props.data.denon.amp.radio.presets[this.props.data.denon.amp.radio.current_preset].name
    else
      stationName = this.props.data.denon.amp.radio.current_frequency.toFixed(2) + " MHz";
      
    var stations = Object.keys(this.props.data.denon.amp.radio.presets).map(function(id){
      var station = this.props.data.denon.amp.radio.presets[id]
      var addClass;
      if(id == this.props.data.denon.amp.radio.current_preset)
        addClass = "btn-primary"
        
      return <Button onCommand={this.props.onCommand} key={"st_" + id} className={"col-xs-6 btn btn-default btn-lg " + addClass} command={"tuner:tune:" + id}>{station.name}</Button>
    }.bind(this));
    return (
      <div>
        <h1>{stationName}</h1>
        <div className="row btn-group">
        {stations}
        </div>
      </div>
    )
  }
});

var MusicMode = React.createClass({
  render: function() {
    return (
      <div>
        <div className="btn-group btn-group-lg btn-group-justified">
          <Button onCommand={this.props.onCommand} command="mpd:prev_album"><Icon name="fa-arrow-circle-left"/></Button>
          <Button onCommand={this.props.onCommand} command="mpd:prev"><Icon name="fa-fast-backward"/></Button>
          <Button onCommand={this.props.onCommand} command="mpd:pause"><Icon name={(this.props.data.mpd.status.state == "play")?"fa-pause":"fa-play"}/></Button>
          <Button onCommand={this.props.onCommand} command="mpd:next"><Icon name="fa-fast-forward"/></Button>
          <Button onCommand={this.props.onCommand} command="mpd:next_album"><Icon name="fa-arrow-circle-right"/></Button>
        </div>
      
        <h1>{this.props.data.mpd.song.artist}</h1>
        <h2>{this.props.data.mpd.song.title}</h2>
        <h4>{this.props.data.mpd.song.album}</h4>
      </div>
    )
  }
});

var InfoMode = React.createClass({
  render: function() {
    return (
      <h1 style={{textAlign: "center"}}><Icon name={this.props.icon + " fa-4x"}/><br/><br/> {this.props.children}</h1>
    )
  }
});

var Volume = React.createClass({
  handleClick: function(evt) {
    evt.preventDefault()
    this.props.onCommand($(evt.currentTarget).data('command'))
  },

  render: function() {
    var getVolume = function() {
      if(this.props.data.denon.amp.audio.mute) {
        return (<i className="fa fa-volume-off"/>)
      } else {
        return (this.props.data.denon.amp.audio.volume)
      }
    }.bind(this);
    
    return (
      <nav className="navbar navbar-fixed-bottom">
        <div className="container">
          <div className="btn-group btn-group-lg btn-group-justified">
            <Button onCommand={this.props.onCommand} command="ir:KEY_VOLUMEDOWN"><Icon name="fa-minus"/></Button>
            <Button onCommand={this.props.onCommand} command="ir:KEY_MUTE">{getVolume()}</Button>
            <Button onCommand={this.props.onCommand} command="ir:KEY_VOLUMEUP"><Icon name="fa-plus"/></Button>
          </div>
        </div>
      </nav>
    );
  }
});

var DenonUI = React.createClass({
  componentDidMount: function() {
    this.ws = new WebSocket("ws://10.0.42.42:8080")

    $(this.ws).on('open', function(){ console.log("connected") })
    
    this.ws.onmessage = function(m) {
      var status = JSON.parse(m.data)
      this.setState({data: status})
    }.bind(this);
  },
  handleCommand: function(cmd) {
    this.ws.send(cmd);
  },
  render: function() {
    if(this.state) {
      
      var currentMode;
      if(this.state.data.denon.amp.power == "on") {
        switch(this.state.data.denon.amp.source) {
          case "cd": {
            currentMode = <CDMode data={this.state.data} onCommand={this.handleCommand} />
            break
          }
          case "tuner": {
            currentMode = <TunerMode data={this.state.data} onCommand={this.handleCommand} />
            break
          }
          case "network": {
            switch(this.state.data.denon.mode) {
              case "radio": {
                currentMode = <MusicMode data={this.state.data} onCommand={this.handleCommand} />
                break;
              }
              case "music": {
                currentMode = <MusicMode data={this.state.data} onCommand={this.handleCommand} />
                break;
              }
              case "airplay": {
                currentMode = (<InfoMode icon="fa-toggle-down">AirPlay</InfoMode>)
                break;
              }            
              default: currentMode = <h1>Network player</h1>
            }
            break;
          }
          case "digital": {
            currentMode = (<InfoMode icon="fa-laptop fa-4x">Digital</InfoMode>)
            break
          }
          case "aux1": {
            currentMode = (<InfoMode icon="fa-external-link-square">Analog 1</InfoMode>)
            break
          }
          case "aux2": {
            currentMode = (<InfoMode icon="fa-external-link-square">Analog 2</InfoMode>)
            break
          }        
          default: { 
            currentMode = (<div>not supported</div>)
            break
          }
        }
      } else {
        currentMode = (<InfoMode icon="fa-power-off"><Button onCommand={this.handleCommand} command="ir:KEY_POWER" className="btn btn-lg btn-success btn-ws">Turn on!</Button></InfoMode>)
      }
      
      
      return (
        <div>
          <Header data={this.state.data} onCommand={this.handleCommand}/>
          {currentMode}
          <Volume data={this.state.data} onCommand={this.handleCommand}/>
        </div>
      );
    } else {
      return (<div>connecting…</div>)
    }
  }
});

React.render(<DenonUI/>, document.getElementById('app'));

