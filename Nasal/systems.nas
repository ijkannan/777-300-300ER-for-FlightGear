#777 systems
#Syd Adams
#2021 Isaak Dieleman: Fuel jettison + x-feed
var SndOut = props.globals.getNode("sim/sound/Ovolume",1);
var chronometer = aircraft.timer.new("instrumentation/clock/ET-sec",1);
var elapsetime = aircraft.timer.new("instrumentation/clock/elapsetime-sec",1);
var vmodel = substr(getprop("sim/aero"), 3);
var aux_tanks = ((vmodel == "-200LR") or (vmodel == "-200F"));
var prevtime = 0;
var curtime = 0;
if(vmodel == "-200F")
{
    aircraft.livery.init("Aircraft/777/Models/Liveries-F");
}
else
{
    aircraft.livery.init("Aircraft/777/Models/Liveries"~substr(vmodel,0,4));
}

# Version checking, derived from acconfig of A320
# This version check warns the user about FG version being too low, but does not prevent users from still using it.
var versionCheck = func(){
    var fgfsMin = split(".", getprop("/sim/minimum-flightgear-version"));
    var fgfsVer = split(".", getprop("/sim/version/flightgear"));
	if (fgfsVer[0] < fgfsMin[0] or fgfsVer[1] < fgfsMin[1]) {
		return 0;
	} else if (fgfsVer[1] == fgfsMin[1]) {
		if (fgfsVer[2] < fgfsMin[2]) {
			return 0;
		} else {
			return 1;
		}
	} else {
		return 1;
	}
}
if(!versionCheck()) settimer(func(){
    setprop("sim/messages/copilot", "Your FlightGear version is below the minimum required version "~getprop("/sim/minimum-flightgear-version")~ " for this aircraft. You can still try to use this aircraft model but certain things could be broken.");
    }, 3);



#EFIS specific class
# ie: var efis = EFIS.new("instrumentation/efis");
var EFIS = {
    new : func(prop1){
        var m = { parents : [EFIS]};
        m.mfd_mode_list=["APP","VOR","MAP","PLAN"];

        m.efis = props.globals.initNode(prop1);
        m.mfd = m.efis.initNode("mfd");
        m.pfd = m.efis.initNode("pfd");
        m.eicas = m.efis.initNode("eicas");
        m.mfd_mode_num = m.mfd.initNode("mode-num",2,"INT");
        m.mfd_display_mode = m.mfd.initNode("display-mode",m.mfd_mode_list[2]);
        m.std_mode = m.efis.initNode("inputs/setting-std",0,"BOOL");
        m.previous_set = m.efis.initNode("inhg-previous",29.92);
        m.kpa_mode = m.efis.initNode("inputs/kpa-mode",0,"BOOL");
        m.kpa_output = m.efis.initNode("inhg-kpa",29.92);
        m.kpa_prevoutput = m.efis.initNode("inhg-kpa-previous",29.92);
        m.temp = m.efis.initNode("fixed-temp",0);
        m.alt_meters = m.efis.initNode("inputs/alt-meters",0,"BOOL");
        m.fpv = m.efis.initNode("inputs/fpv",0,"BOOL");
        m.nd_centered = m.efis.initNode("inputs/nd-centered",0,"BOOL");

        m.mins_mode = m.efis.initNode("inputs/minimums-mode",0,"BOOL");
        m.mins_mode_txt = m.efis.initNode("minimums-mode-text","RADIO","STRING");
        m.minimums = m.efis.initNode("minimums",250,"INT");
        m.minimums_baro= m.efis.initNode("minimums-baro",250,"INT");
        m.minimums_radio= m.efis.initNode("minimums-radio",250,"INT");
        m.mk_minimums = props.globals.getNode("instrumentation/mk-viii/inputs/arinc429/decision-height");
        m.tfc = m.efis.initNode("inputs/tfc",0,"BOOL");
        m.wxr = m.efis.initNode("inputs/wxr",0,"BOOL");
        m.range = m.efis.initNode("inputs/range-nm",0);
        m.sta = m.efis.initNode("inputs/sta",0,"BOOL");
        m.wpt = m.efis.initNode("inputs/wpt",0,"BOOL");
        m.arpt = m.efis.initNode("inputs/arpt",0,"BOOL");
        m.data = m.efis.initNode("inputs/data",0,"BOOL");
        m.pos = m.efis.initNode("inputs/pos",0,"BOOL");
        m.terr = m.efis.initNode("inputs/terr",0,"BOOL");
        m.rh_vor_adf = m.efis.initNode("inputs/rh-vor-adf",0,"INT");
        m.lh_vor_adf = m.efis.initNode("inputs/lh-vor-adf",0,"INT");
        m.nd_plan_wpt = m.efis.initNode("inputs/plan-wpt-index", 0, "INT");

        m.wptIndexL = setlistener("instrumentation/efis/inputs/plan-wpt-index", func m.update_nd_plan_center());

        m.kpaL = setlistener("instrumentation/altimeter/setting-inhg", func m.calc_kpa());

        m.eicas_msg_alert   = m.eicas.initNode("msg/alert"," ","STRING");
        m.eicas_msg_caution = m.eicas.initNode("msg/caution"," ","STRING");
        m.eicas_msg_advisory = m.eicas.initNode("msg/advisory"," ","STRING");
        m.eicas_msg_info    = m.eicas.initNode("msg/info"," ","STRING");
        m.update_radar_font();
        m.update_nd_center();
        setprop("instrumentation/transponder/mode-switch",0);
        setprop("controls/lighting/overhead-intencity",0.5);
        setprop("controls/lighting/CB-intencity",0.5);
        setprop("controls/lighting/panel-flood-intencity",0.5);
        setprop("controls/lighting/dome-intencity",0.5);
        return m;
    },
#### convert inhg to kpa ####
    calc_kpa : func{
        var kp = getprop("instrumentation/altimeter/setting-inhg");
        kp = kp * 33.8637526;
        me.kpa_output.setValue(kp);
        kp = getprop("instrumentation/efis/inhg-previous");
        kp = kp * 33.8637526;
        me.kpa_prevoutput.setValue(kp);
        },
#### update temperature display ####
    update_temp : func{
        var tmp = getprop("environment/temperature-degc");
        if(tmp < 0.00){
            tmp = -1 * tmp;
        }
        me.temp.setValue(tmp);
    },
######### Controller buttons ##########
    ctl_func : func(md,val){
        controls.click(3);
        if(md=="range")
        {
            var rng = me.range.getValue();
            if(val ==1){
                rng =rng * 2;
                if(rng > 640) rng = 640;
            }elsif(val =-1){
                rng =rng / 2;
                if(rng < 10) rng = 10;
            }
            me.range.setValue(rng);
        }
        elsif(md=="dh")
        {
            if(me.mins_mode.getValue())
            {
                if(val==0)
                {
                    var num=250;
                }
                else
                {
                    var num = me.minimums_baro.getValue();
                    num+=val;
                    if(num<0)num=0;
                    if(num>12000)num=12000;
                }
                me.minimums_baro.setValue(num);
            }
            else
            {
                if(val==0)
                {
                    var num=250;
                }
                else
                {
                    var num =me.minimums_radio.getValue();
                    num+=val;
                    if(num<0)num=0;
                    if(num>2500)num=2500;
                }
                me.minimums_radio.setValue(num);
            }
            me.minimums.setValue(num);
            me.mk_minimums.setValue(num);
        }
        elsif(md=="mins")
        {
            me.mins_mode.setValue(val);
            if (val)
            {
                me.mins_mode_txt.setValue("BARO");
                me.minimums.setValue(me.minimums_baro.getValue());
            }
            else
            {
                me.mins_mode_txt.setValue("RADIO");
                me.minimums.setValue(me.minimums_radio.getValue());
            }
        }
        elsif(md=="display")
        {
            var num =me.mfd_mode_num.getValue();
            num+=val;
            if(num<0)num=0;
            if(num>3)num=3;
            me.mfd_mode_num.setValue(num);
            me.mfd_display_mode.setValue(me.mfd_mode_list[num]);

            # for all modes except plan, acft is up. For PLAN,
            # north is up.
            var isPLAN = (num == 3);
            setprop("instrumentation/nd/aircraft-heading-up", !isPLAN);
            setprop("instrumentation/nd/user-position", isPLAN);
            me.nd_plan_wpt.setValue(getprop("autopilot/route-manager/current-wp"));

            me.update_nd_center();
            me.update_nd_plan_center();
        }
        elsif(md=="rhvor")
        {
            var num =me.rh_vor_adf.getValue();
            num+=val;
            if(num>1)num=1;
            if(num<-1)num=-1;
            me.rh_vor_adf.setValue(num);
        }
        elsif(md=="lhvor")
        {
            var num =me.lh_vor_adf.getValue();
            num+=val;
            if(num>1)num=1;
            if(num<-1)num=-1;
            me.lh_vor_adf.setValue(num);
        }
        elsif(md=="center")
        {
            if(me.mfd_mode_num.getValue() == 3)
            {
                var index = me.nd_plan_wpt.getValue() + 1;
                if(index >= getprop("autopilot/route-manager/route/num")) index = getprop("autopilot/route-manager/current-wp");
                me.nd_plan_wpt.setValue(index);
            }
            else
            {
                var num =me.nd_centered.getValue();
                num = 1 - num;
                me.nd_centered.setValue(num);
                me.update_radar_font();
                me.update_nd_center();
            }
        }
        else
        {
            print("Unsupported mode: ",md);
        }
    },
    update_radar_font : func {
        var fnt=[12,13];
        var linespacing = 0.01;
        var num = me.nd_centered.getValue();
        setprop("instrumentation/radar/font/size",fnt[num]);
        setprop("instrumentation/radar/font/line-spacing",linespacing);
    },
    update_nd_center : func {
        # PLAN mode is always centered
        var isPLAN = (me.mfd_mode_num.getValue() == 3);
        if (isPLAN or me.nd_centered.getValue())
        {
            setprop("instrumentation/nd/y-center", 0.5);
        } else {
            setprop("instrumentation/nd/y-center", 0.15);
        }
    },

    update_nd_plan_center : func {
        # find wpt lat, lon
        var index = me.nd_plan_wpt.getValue();
        if(index >= 0)
        {
            var lat = getprop("autopilot/route-manager/route/wp[" ~ index ~ "]/latitude-deg");
            var lon = getprop("autopilot/route-manager/route/wp[" ~ index ~ "]/longitude-deg");
            if(lon!=nil) setprop("instrumentation/nd/user-longitude-deg", lon);
            if(lat!=nil) setprop("instrumentation/nd/user-latitude-deg", lat);
        }
    },
#### update EICAS messages ####
    update_eicas : func(alertmsgs,cautionmsgs,advisorymsgs,infomsgs) {
        var msg="";
        for(var i=0; i<size(alertmsgs); i+=1)
        {
            msg = msg ~ alertmsgs[i] ~ "\n";
        }
        me.eicas_msg_alert.setValue(msg);
        for(var i=0; i<size(cautionmsgs); i+=1)
        {
            msg = msg ~ cautionmsgs[i] ~ "\n";
        }
        me.eicas_msg_caution.setValue(msg);
        for(var i=0; i<size(advisorymsgs); i+=1)
        {
            msg = msg ~ advisorymsgs[i] ~ "\n";
        }
        me.eicas_msg_advisory.setValue(msg);
        for(var i=0; i<size(infomsgs); i+=1)
        {
            msg = msg ~ infomsgs[i] ~ "\n";
        }
        me.eicas_msg_info.setValue(msg);
    },
};
##############################################
##############################################

##########################

var Wiper = {
    new : func {
        var m = { parents : [Wiper] };
        m.direction = 0;
        m.delay_count = 0;
        m.spd_factor = 0;
        m.node = props.globals.getNode(arg[0],1);
        m.power = props.globals.getNode(arg[1],1);
        if(m.power.getValue()==nil)
            m.power.setDoubleValue(0);
        m.spd = m.node.getNode("arc-sec",1);
        if(m.spd.getValue()==nil)
            m.spd.setDoubleValue(1);
        m.delay = m.node.getNode("delay-sec",1);
        if(m.delay.getValue()==nil)
            m.delay.setDoubleValue(0);
        m.position = m.node.getNode("position-norm", 1);
        m.position.setDoubleValue(0);
        m.switch = m.node.getNode("switch", 1);
        if (m.switch.getValue() == nil)
            m.switch.setBoolValue(0);
        return m;
    },
    active: func{
        if(me.power.getValue()<=5)return;
        var spd_factor = 1/me.spd.getValue();
        var pos = me.position.getValue();
        if(!me.switch.getValue()){
            if(pos <= 0.000)return;
        }
        if(pos >=1.000){
            me.direction=-1;
        }elsif(pos <=0.000){
            me.direction=0;
            me.delay_count+=getprop("sim/time/delta-sec");
            if(me.delay_count >= me.delay.getValue()){
                me.delay_count=0;
                me.direction=1;
            }
        }
        var wiper_time = spd_factor*getprop("sim/time/delta-sec");
        pos +=(wiper_time * me.direction);
        me.position.setValue(pos);
    }
};
#####################

var Efis = EFIS.new("instrumentation/efis");
var Efis2 = EFIS.new("instrumentation/efis[1]");
var LHeng=Engine.new(0);
var RHeng=Engine.new(1);
var wiper = Wiper.new("controls/electric/wipers","systems/electrical/bus-volts");

setlistener("sim/signals/fdm-initialized", func {
    SndOut.setDoubleValue(0.15);
    chronometer.stop();
    props.globals.initNode("instrumentation/clock/ET-display",0,"INT");
    props.globals.initNode("instrumentation/clock/time-display",0,"INT");
    props.globals.initNode("instrumentation/clock/time-knob",0,"INT");
    props.globals.initNode("instrumentation/clock/et-knob",0,"INT");
    props.globals.initNode("instrumentation/clock/set-knob",0,"INT");

    balance_fuel();
    setprop("instrumentation/comm/power-btn",0);
    setprop("instrumentation/comm[1]/power-btn",0);
    setprop("instrumentation/comm[2]/power-btn",0);
    setprop("instrumentation/comm/power-good",0);
    setprop("instrumentation/comm[1]/power-good",0);
    setprop("instrumentation/comm[2]/power-good",0);
    setprop("instrumentation/comm/volume",0.5);
    setprop("instrumentation/comm[1]/volume",0.5);
    setprop("instrumentation/comm[2]/volume",0.5);
    setprop("controls/hydraulics/system/LENG_switch", 0);
    setprop("controls/hydraulics/system[2]/RENG_switch", 0);
    setprop("controls/hydraulics/system[1]/C1ELEC-switch", 0);
    setprop("controls/hydraulics/system[1]/C2ELEC-switch", 0);
    setprop("controls/hydraulics/system/LACMP-switch", 0);
    setprop("controls/hydraulics/system[1]/C1ADP-switch", 0);
    setprop("controls/hydraulics/system[1]/C2ADP-switch", 0);
    setprop("controls/hydraulics/system[2]/RACMP-switch", 0);
    setprop("controls/fuel/tank[0]/boost-pump-switch[0]",0);
    setprop("controls/fuel/tank[0]/boost-pump-switch[1]",0);
    setprop("controls/fuel/tank[0]/boost-pump[2]", 0);
    setprop("controls/fuel/tank[0]/m-boost-pump[2]", 0);
    setprop("controls/fuel/tank[0]/boost-pump[3]", 0);
    setprop("controls/fuel/tank[0]/m-boost-pump[3]", 0);
    setprop("controls/fuel/tank[2]/boost-pump-switch[0]",0);
    setprop("controls/fuel/tank[2]/boost-pump-switch[1]",0);
    setprop("controls/fuel/tank[1]/boost-pump-switch[0]",0);
    setprop("controls/fuel/tank[1]/boost-pump-switch[1]",0);
    setprop("controls/fuel/tank[1]/m-boost-pump[0]", 0);
    setprop("controls/fuel/tank[1]/m-boost-pump[1]", 0);
    setprop("controls/fuel/tank[2]/boost-pump[2]", 0);
    setprop("controls/fuel/tank[2]/m-boost-pump[2]", 0);
    setprop("autopilot/route-manager/cruise/speed-kts",320);
    setprop("autopilot/route-manager/cruise/speed-mach",0.840);
    setprop("controls/engines/autostart",1);
    setprop("controls/engines/engine/eec-switch",1);
    setprop("controls/engines/engine[1]/eec-switch",1);
#Fuel Jettison
    setprop("controls/fuel/b-jtsnarm", 1);
    setprop("controls/fuel/tank[0]/b-nozzle", 1);
    setprop("controls/fuel/tank[2]/b-nozzle", 1);
    setprop("controls/fuel/tank[0]/jettisoning", 0);
    setprop("controls/fuel/tank[2]/jettisoning", 0);
    setprop("controls/fuel/tank[0]/nozzlestate", "Disarmed");
    setprop("controls/fuel/tank[2]/nozzlestate", "Disarmed");
    setprop("controls/fuel/FuelToRemain-knob", 0.0);
    setprop("controls/fuel/FuelToRemain-hover", 0);
    setprop("controls/fuel/FuelToRemain-rate", 0);
    setprop("controls/fuel/tank[0]/nozzle-valve", 0);
    setprop("controls/fuel/tank[1]/nozzle-valve[0]", 0);
    setprop("controls/fuel/tank[1]/nozzle-valve[1]", 0);
    setprop("controls/fuel/tank[2]/nozzle-valve", 0);
# APU nozzles
    setprop("controls/APU/valve[0]/opened", 0);
    setprop("controls/APU/valve[1]/opened", 0);

#XFD valve
    setprop("controls/fuel/b-xfdfwd-vlv", 1);
    setprop("controls/fuel/b-xfdaft-vlv", 1);
    setprop("controls/fuel/xfeedfwd-valve/opened", 0);
    setprop("controls/fuel/xfeedaft-valve/opened", 0);
    setprop("controls/fuel/xfd-off-l", 0);
    setprop("controls/fuel/xfd-off-r", 0);
    setprop("controls/fuel/imbalance", 0);
    setprop("controls/fuel/imbalance-1", 0);

#Cabin signs
    setprop("controls/cabin/NoSmoking-knob", -1);
    setprop("controls/cabin/SeatBelt-knob", -1);

#Anti-Ice
    setprop("controls/anti-ice/window-heat-ls-switch", 0);
    setprop("controls/anti-ice/window-heat-lf-switch", 0);
    setprop("controls/anti-ice/window-heat-rf-switch", 0);
    setprop("controls/anti-ice/window-heat-rs-switch",0);

#Switches
    setprop("controls/flight/thrust-asym-switch", 1);
    setprop("controls/flight/adiru-switch", 0);
    setprop("controls/switches/fire/cargo-fwd-switch", 0);
    setprop("controls/switches/fire/cargo-aft-switch", 0);
    setprop("controls/switches/fire/apu-discharged", 1);
    settimer(start_updates,1);
    readSettings();
    writeSettings();
});

var systems_running = 0;
var start_updates = func {
    if (getprop("position/gear-agl-ft")>30)
    {
        # airborne startup
        Startup();
        b777.afds.current_wp_local = getprop("sim/gui/dialogs/route-manager/selection");
        setprop("controls/gear/brake-parking",0);
        setprop("controls/lighting/taxi-lights",0);
        setprop("instrumentation/afds/ap-modes/pitch-mode", "TO/GA");
        setprop("instrumentation/afds/ap-modes/roll-mode", "TO/GA");
        setprop("instrumentation/afds/inputs/vertical-index", 10);
        setprop("instrumentation/afds/inputs/lateral-index", 9);
        setprop("instrumentation/afds/inputs/at-armed", 1);
        setprop("instrumentation/afds/inputs/at-armed[1]", 1);
        setprop("instrumentation/afds/inputs/AP", 1);
        setprop("autopilot/internal/airport-height", 0);
        setprop("engines/engine[0]/run",1);
        setprop("engines/engine[1]/run",1);
        setprop("autopilot/settings/target-speed-kt", getprop("sim/presets/airspeed-kt"));
        b777.afds.input(1,1);
        setprop("autopilot/settings/counter-set-altitude-ft", getprop("sim/presets/altitude-ft"));
        setprop("autopilot/settings/actual-target-altitude-ft", getprop("sim/presets/altitude-ft"));
        b777.afds.input(0,2);
        setprop("controls/flight/rudder-trim", 0);
        setprop("controls/flight/elevator-trim", 0.125);
        setprop("controls/flight/aileron-trim", 0);
        setprop("instrumentation/weu/state/takeoff-mode",0);
        if(var vbaro = getprop("environment/metar/pressure-inhg"))
        {
            setprop("instrumentation/altimeter/setting-inhg", vbaro);
        }
        # set ILS frequency
        var cur_runway = getprop("sim/presets/runway");
        if(cur_runway != "")
        {
            var runways = airportinfo(getprop("sim/presets/airport-id")).runways;
            var r =runways[cur_runway];
            if (r != nil and r.ils != nil)
            {
                setprop("instrumentation/nav/frequencies/selected-mhz", (r.ils.frequency / 100));
            }
        }
    }

    # start update_systems loop - but start it once only
    if (!systems_running)
    {
        systems_running = 1;
        update_systems();
    }
}

setlistener("sim/signals/reinit", func {
    SndOut.setDoubleValue(0.15);
    Shutdown();
});

#setlistener("autopilot/route-manager/route/num", func(wp){
#    var wpt= wp.getValue() -1;
#
#    if(wpt>-1){
#    setprop("instrumentation/groundradar/id",getprop("autopilot/route-manager/route/wp["~wpt~"]/id"));
#    }else{
#    setprop("instrumentation/groundradar/id",getprop("sim/tower/airport-id"));
#    }
#},1,0);

setlistener("sim/current-view/internal", func(vw){
    if(vw.getValue()){
        SndOut.setDoubleValue(0.3);
    }else{
        SndOut.setDoubleValue(1.0);
    }
},1,0);

controls.autostart = func() {
    var run = !(getprop("engines/engine[0]/run") or getprop("engines/engine[1]/run"));
    if(run){
        Startup();
    }else{
        Shutdown();
    }
}

setlistener("instrumentation/clock/et-knob", func(et){
    var tmp = et.getValue();
    if(tmp == -1){
        chronometer.reset();
    }elsif(tmp==0){
        chronometer.stop();
    }elsif(tmp==1){
        chronometer.start();
    }
},0,0);

setlistener("instrumentation/transponder/mode-switch", func(transponder_switch){
    var mode = transponder_switch.getValue();
    var tcas_mode = 1;
    if (mode == 3) tcas_mode = 2;
    if (mode == 4) tcas_mode = 3;
    setprop("instrumentation/tcas/inputs/mode",tcas_mode);
},0,0);

setlistener("instrumentation/tcas/outputs/traffic-alert", func(traffic_alert){
    var alert = traffic_alert.getValue();
    # any TCAS alert enables the traffic display
    if (alert) setprop("instrumentation/efis/inputs/tfc",1);
},0,0);

setlistener("controls/flight/speedbrake", func(spd_brake){
    var brake = spd_brake.getValue();
    # do not update lever when in AUTO position
    if ((brake==0) and (getprop("controls/flight/speedbrake-lever")==2))
    {
        setprop("controls/flight/speedbrake-lever",0);
    }
    elsif ((brake==1)
           and ((getprop("controls/flight/speedbrake-lever")==0)
           or (getprop("controls/flight/speedbrake-lever")==1)))
    {
        setprop("controls/flight/speedbrake-lever",2);
    }
},0,0);

setlistener("controls/flight/speedbrake-lever", func(spd_lever){
    var lever = spd_lever.getValue();
    if (lever>=1)
    {
        setprop("controls/flight/speedbrake", (lever - 1));
    }
},0,0);

controls.toggleAutoSpoilers = func() {
    # 0=spoilers retracted, 1=auto, 2=extended
    if (getprop("controls/flight/speedbrake-lever")==0)
        setprop("controls/flight/speedbrake-lever",1);
    else
    {
        setprop("controls/flight/speedbrake-lever",0);
        setprop("controls/flight/speedbrake",0);
    }
}

setlistener("controls/flight/flaps", func { controls.click(6) } );
setlistener("controls/gear/gear-down", func { controls.click(8) } );
setlistener("controls/flight/air-sensing-sw", func(air_switch) {
    if(air_switch.getValue())
    {
        elapsetime.start();
    }
    else
    {
        elapsetime.stop();
    }
},0,0);

setlistener("controls/engines/engine/cutoff-switch", func
{
    if((getprop("controls/engines/engine/cutoff-switch") == 1)
        and (getprop("controls/engines/engine[1]/cutoff-switch") == 1))
    {
        elapsetime.reset();
    }
},0,0);

setlistener("controls/engines/engine[1]/cutoff-switch", func
{
    if((getprop("controls/engines/engine/cutoff-switch") == 1)
        and (getprop("controls/engines/engine[1]/cutoff-switch") == 1))
    {
        elapsetime.reset();
    }
},0,0);

controls.gearDown = func(v) {
    if (v < 0) {
        if(!getprop("gear/gear[1]/wow"))setprop("controls/gear/gear-down", 0);
    } elsif (v > 0) {
      setprop("controls/gear/gear-down", 1);
    }
}

controls.toggleLandingLights = func()
{
    var state = getprop("controls/lighting/landing-light[1]");
    setprop("controls/lighting/landing-light[0]",!state);
    setprop("controls/lighting/landing-light[1]",!state);
    setprop("controls/lighting/landing-light[2]",!state);
    setprop("controls/lighting/landing-lights",!state);
}

var balance_fuel = func{
    var capwing = getprop("consumables/fuel/tank[0]/capacity-gal_us");
# make the fuel quantity balancing
    var total_fuel = 0;
    var capcenter = 0;
    var j = 3;
    if(aux_tanks)
    {
        j = 6;
        capcenter = getprop("consumables/fuel/tank[1]/capacity-gal_us");
    }
    for(var i = 0; i < j; i += 1)
    {
        total_fuel += getprop("consumables/fuel/tank["~i~"]/level-gal_us");
    }
    if(j == 6)
    {
        if(total_fuel > ((capwing * 2) + capcenter))
        {
            var capaux = ((total_fuel -  ((capwing * 2) + capcenter)) / 3);
            setprop("consumables/fuel/tank[3]/level-gal_us", capaux);
            setprop("consumables/fuel/tank[4]/level-gal_us", capaux);
            setprop("consumables/fuel/tank[5]/level-gal_us", capaux);
            total_fuel -= (capaux * 3);
        }
        else
        {
            setprop("consumables/fuel/tank[3]/level-gal_us", 0);
            setprop("consumables/fuel/tank[4]/level-gal_us", 0);
            setprop("consumables/fuel/tank[5]/level-gal_us", 0);
        }
    }
    if(total_fuel > (capwing * 2))
    {
        setprop("consumables/fuel/tank[0]/level-gal_us", capwing);
        setprop("consumables/fuel/tank[1]/level-gal_us", (total_fuel - (capwing * 2)));
        setprop("consumables/fuel/tank[2]/level-gal_us", capwing);
    }
    else
    {
        setprop("consumables/fuel/tank[0]/level-gal_us", (total_fuel / 2));
        setprop("consumables/fuel/tank[1]/level-gal_us", 0);
        setprop("consumables/fuel/tank[2]/level-gal_us", (total_fuel / 2));
    }
}

var Startup = func{
    setprop("sim/model/armrest",1);
    setprop("controls/electric/battery-switch",1);
    setprop("sim/autostart", 1);
    setprop("services/ext-pwr/enable", 1);
    setprop("services/ext-pwr/primary", 1);
    setprop("controls/electric/external-power", 1);
    setprop("systems/electrical/PRI-EPC", 1);
    setprop("controls/fuel/tank[0]/boost-pump-switch[0]",1);
    setprop("controls/fuel/tank[0]/boost-pump-switch[1]",1);
    setprop("controls/fuel/tank[2]/boost-pump-switch[0]",1);
    setprop("controls/fuel/tank[2]/boost-pump-switch[1]",1);
    setprop("controls/fuel/tank[0]/boost-pump[0]",1);
    setprop("controls/fuel/tank[0]/boost-pump[1]",1);
    setprop("controls/fuel/tank[2]/boost-pump[0]",1);
    setprop("controls/fuel/tank[2]/boost-pump[1]",1);
    setprop("controls/electric/engine[0]/generator",1);
    setprop("controls/electric/engine[1]/generator",1);
    setprop("controls/electric/engine[0]/bus-tie",1);
    setprop("controls/electric/engine[1]/bus-tie",1);
    setprop("systems/electrical/outputs/avionics",1);
    setprop("controls/electric/inverter-switch",1);
    setprop("controls/lighting/instrument-norm",0.8);
    setprop("controls/lighting/nav-lights",1);
    setprop("controls/lighting/beacon",1);
    setprop("controls/lighting/wing-lights",1);
    setprop("controls/lighting/taxi-lights",0);
    setprop("controls/lighting/logo-lights",1);
    setprop("controls/lighting/strobe",1);
    setprop("fcs/pfc-enable", 1); # PFCs in AUTO
    setprop("controls/lighting/landing-light[0]",1);
    setprop("controls/lighting/landing-light[1]",1);
    setprop("controls/lighting/landing-light[2]",1);
	setprop("controls/lighting/landing-lights",1);
    setprop("controls/engines/engine[0]/cutoff",0);
    setprop("controls/engines/engine[1]/cutoff",0);
    setprop("engines/engine[0]/out-of-fuel",0);
    setprop("engines/engine[1]/out-of-fuel",0);
    setprop("controls/flight/elevator-trim",0.125);
    setprop("controls/flight/aileron-trim",0);
    setprop("controls/flight/rudder-trim",0);
    setprop("instrumentation/transponder/mode-switch",4); # transponder mode: TA/RA
    setprop("controls/hydraulics/system/LENG_switch", 1);
    setprop("controls/hydraulics/system[2]/RENG_switch", 1);
    setprop("controls/hydraulics/system[1]/C1ELEC-switch", 1);
    setprop("controls/hydraulics/system[1]/C2ELEC-switch", 1);
    setprop("controls/hydraulics/system/LACMP-switch", 1);
    setprop("controls/hydraulics/system[1]/C1ADP-switch", 1);
    setprop("controls/hydraulics/system[1]/C2ADP-switch", 1);
    setprop("controls/hydraulics/system[2]/RACMP-switch", 1);
    setprop("controls/anti-ice/window-heat-ls-switch", 1);
    setprop("controls/anti-ice/window-heat-lf-switch", 1);
    setprop("controls/anti-ice/window-heat-rf-switch", 1);
    setprop("controls/anti-ice/window-heat-rs-switch",1);
    setprop("controls/flight/adiru-switch", 1);
    setprop("controls/flight/thrust-asym-switch", 1);
    setprop("controls/cabin/NoSmoking-knob", 0);
    setprop("controls/cabin/SeatBelt-knob", 0);
    # give fuel and electrical systems some time to setup the engine supplies
    var StartupEnd = maketimer(2, func() {
        setprop("engines/engine[0]/run",1);
        setprop("engines/engine[1]/run",1);
        setprop("sim/autostart", 0);
        setprop("services/ext-pwr/enable", 0);
        setprop("services/ext-pwr/primary", 0);
        setprop("controls/electric/external-power", 0);
        setprop("systems/electrical/PRI-EPC", 0);
        StartupEnd.stop();
    });
    StartupEnd.start();
}



var Shutdown = func{
    setprop("controls/gear/brake-parking",1);
    setprop("controls/electric/APU-generator",0);
    setprop("systems/electrical/outputs/avionics",0);
    setprop("controls/electric/battery-switch",0);
    setprop("controls/electric/inverter-switch",0);
    setprop("controls/lighting/instruments-norm",0);
    setprop("controls/lighting/nav-lights",0);
    setprop("controls/lighting/beacon",0);
    setprop("controls/lighting/strobe",0);
    setprop("controls/lighting/wing-lights",0);
    setprop("controls/lighting/taxi-lights",0);
    setprop("controls/lighting/logo-lights",0);
    setprop("controls/lighting/cabin-lights",0);
	setprop("controls/lighting/landing-lights",0);
    setprop("controls/lighting/landing-light[0]",0);
    setprop("controls/lighting/landing-light[1]",0);
    setprop("controls/lighting/landing-light[2]",0);
    setprop("controls/engines/engine[0]/cutoff",1);
    setprop("controls/engines/engine[1]/cutoff",1);
    setprop("controls/fuel/tank[0]/boost-pump-switch[0]",0);
    setprop("controls/fuel/tank[0]/boost-pump-switch[1]",0);
    setprop("controls/fuel/tank[1]/boost-pump-switch[0]",0);
    setprop("controls/fuel/tank[1]/boost-pump-switch[1]",0);
    setprop("controls/fuel/tank[2]/boost-pump-switch[0]",0);
    setprop("controls/fuel/tank[2]/boost-pump-switch[1]",0);
    setprop("controls/flight/elevator-trim",0.125);
    setprop("controls/flight/aileron-trim",0);
    setprop("controls/flight/rudder-trim",0);
    setprop("controls/flight/speedbrake-lever",0);
    setprop("sim/model/armrest",0);
    setprop("instrumentation/transponder/mode-switch",0); # transponder mode: off
    setprop("controls/engines/StartIgnition-knob[0]",0);
    setprop("controls/engines/StartIgnition-knob[1]",0);
    setprop("engines/engine[0]/run",0);
    setprop("engines/engine[1]/run",0);
    setprop("engines/engine[0]/rpm",0);
    setprop("engines/engine[1]/rpm",0);
    setprop("engines/engine[0]/n2rpm",0);
    setprop("engines/engine[1]/n2rpm",0);
    setprop("engines/engine[0]/fuel-flow_pph",0);
    setprop("engines/engine[1]/fuel-flow_pph",0);
    setprop("instrumentation/weu/state/takeoff-mode",1);
    setprop("controls/hydraulics/system/LENG_switch", 0);
    setprop("controls/hydraulics/system[2]/RENG_switch", 0);
    setprop("controls/hydraulics/system[1]/C1ELEC-switch", 0);
    setprop("controls/hydraulics/system[1]/C2ELEC-switch", 0);
    setprop("controls/hydraulics/system/LACMP-switch", 0);
    setprop("controls/hydraulics/system[1]/C1ADP-switch", 0);
    setprop("controls/hydraulics/system[1]/C2ADP-switch", 0);
    setprop("controls/hydraulics/system[2]/RACMP-switch", 0);
    setprop("controls/anti-ice/window-heat-ls-switch", 0);
    setprop("controls/anti-ice/window-heat-lf-switch", 0);
    setprop("controls/anti-ice/window-heat-rf-switch", 0);
    setprop("controls/anti-ice/window-heat-rs-switch",0);
    setprop("controls/flight/adiru-switch", 0);
    setprop("controls/cabin/NoSmoking-knob", -1);
    setprop("controls/cabin/SeatBelt-knob", -1);
}

var click_reset = func(propName) {
    setprop(propName,0);
}

controls.click = func(button) {
    if (getprop("sim/freeze/replay-state"))
        return;
    var propName="sim/sound/click"~button;
    setprop(propName,1);
    settimer(func { click_reset(propName) },0.4);
}

controls.elevatorTrim = func(speed) {
    if (!getprop("instrumentation/afds/inputs/AP")) {
        controls.slewProp("/controls/flight/elevator-trim", speed * 0.045);
    } else {
        setprop("/instrumentation/afds/inputs/AP", 0);
    }
}

switch_ind = func() {
# update time variables for time sensitive usecases
prevtime = curtime;
curtime = getprop("sim/time/elapsed-sec");
var deltatime = curtime - prevtime;

# Battery switch
    if(getprop("controls/electric/battery-switch") == 0)
    {
        if(bat.getValue() > 24)
        {
            setprop("controls/electric/b_batt", 0);
        }
        else
        {
            setprop("controls/electric/b_batt", 1);
        }
    }
    else
    {
        setprop("controls/electric/b_batt", 1);
        }
# Primary external power switch
    if(primary_external.getValue() == 1)
    {
        if(pri_epc.getValue() == 1)
        {
            setprop("controls/electric/b_ext_power_p", 2);
        }
        else
        {
            setprop("controls/electric/b_ext_power_p", 1);
        }
    }
    else
    {
        pri_epc.setValue(0);
        setprop("controls/electric/b_ext_power_p", 0);
    }
# Secondary external power switch
    if(secondary_external.getValue() == 1)
    {
        if(sec_epc.getValue() == 0)
        {
            setprop("controls/electric/b_ext_power_s", 1);
        }
        else
        {
            setprop("controls/electric/b_ext_power_s", 2);
        }
    }
    else
    {
        sec_epc.setValue(0);
        setprop("controls/electric/b_ext_power_s", 0);
    }
# Left generator switch
    if(cpt_flt_inst.getValue() < 24)
    {
        setprop("controls/electric/b-lidg", 1);
    }
    elsif(getprop("controls/electric/engine/gen-switch") == 0)
    {
        setprop("controls/electric/b-lidg", 0);
    }
    else
    {
        if(lidg.get_output_volts() > 80)
        {
            setprop("controls/electric/b-lidg", 1);
        }
        else
        {
            setprop("controls/electric/b-lidg", 0);
        }
    }
# Right generator switch
    if(cpt_flt_inst.getValue() < 24)
    {
        setprop("controls/electric/b-ridg", 1);
    }
    elsif(getprop("controls/electric/engine[1]/gen-switch") == 0)
    {
        setprop("controls/electric/b-ridg", 0);
    }
    else
    {
        if(ridg.get_output_volts() > 80)
        {
            setprop("controls/electric/b-ridg", 1);
        }
        else
        {
            setprop("controls/electric/b-ridg", 0);
        }
    }
# Left backup generator switch
    if(cpt_flt_inst.getValue() < 24)
    {
        setprop("controls/electric/b-lbugen", 1);
    }
    elsif(getprop("controls/electric/engine/gen-bu-switch") == 0)
    {
        setprop("controls/electric/b-lbugen", 0);
    }
    else
    {
        setprop("controls/electric/b-lbugen", 1);
    }
# Right backup generator switch
    if(cpt_flt_inst.getValue() < 24)
    {
        setprop("controls/electric/b-rbugen", 1);
    }
    elsif(getprop("controls/electric/engine[1]/gen-bu-switch") == 0)
    {
        setprop("controls/electric/b-rbugen", 0);
    }
    else
    {
        setprop("controls/electric/b-rbugen", 1);
    }
# Left BTR switch
    if(bat.getValue() < 24)
    {
        setprop("controls/electric/b-lbus-tie", 1);
    }
    else
    {
        if(getprop("controls/electric/engine/bus-tie") == 0)
        {
            setprop("controls/electric/b-lbus-tie", 0);
        }
        else
        {
            setprop("controls/electric/b-lbus-tie", 1);
        }
    }
# Right BTR switch
    if(bat.getValue() < 24)
    {
        setprop("controls/electric/b-rbus-tie", 1);
    }
    else
    {
        if(getprop("controls/electric/engine[1]/bus-tie") == 0)
        {
            setprop("controls/electric/b-rbus-tie", 0);
        }
        else
        {
            setprop("controls/electric/b-rbus-tie", 1);
        }
    }
# APU generator switch
    if(bat.getValue() < 24)
    {
        setprop("controls/electric/b-apugen", 1);
    }
    else
    {
        if(ac_tie_bus.getValue() > 80)
        {
            if(getprop("controls/APU/apu-gen-switch") == 0)
            {
                setprop("controls/electric/b-apugen", 0);
            }
            else
            {
                setprop("controls/electric/b-apugen", 1);
            }
        }
        else
        {
            if(getprop("controls/APU/run") == 1)
            {
                setprop("controls/electric/b-apugen", 0);
            }
            else
            {
                setprop("controls/electric/b-apugen", 1);
            }
        }
    }
# Fuel control panel indication
# LH boost #1 + LH DC APU Pump
    if  (((!getprop("consumables/fuel/tank[0]/empty") and (l_xfr.getValue() > 80))
        and
            ((getprop("controls/fuel/tank/boost-pump-switch")
            or
            (getprop("controls/APU/running") and
            (getprop("controls/fuel/tank[1]/boost-pump[0]") != 1) and
            (getprop("consumables/fuel/tank[1]/empty")))
        )))
        or getprop("sim/autostart"))
    {
        if (getprop("controls/APU/running")) {
            setprop("controls/APU/valve[0]/opened", 1);
        }
        setprop("controls/fuel/tank[0]/boost-pump[0]", 1);
        setprop("controls/fuel/tank[0]/m-boost-pump[0]", 1);
        setprop("controls/fuel/tank[0]/boost-pump[3]", 0);
        setprop("controls/fuel/tank[0]/m-boost-pump[3]", 0);
        setprop("controls/APU/valve[1]/opened", 0);
    }
    elsif   ((l_xfr.getValue() > 80) and
            !getprop("controls/fuel/tank[1]/empty") and
            (getprop("controls/fuel/tank[1]/boost-pump[0]") == 1) and
            getprop("controls/APU/running"))
    {
        setprop("controls/fuel/tank[0]/boost-pump[0]", 0);
        setprop("controls/fuel/tank[0]/m-boost-pump[0]", 0);
        setprop("controls/fuel/tank[0]/boost-pump[3]", 0);
        setprop("controls/fuel/tank[0]/m-boost-pump[3]", 0);
        setprop("controls/APU/valve[0]/opened", 1);
        setprop("controls/APU/valve[1]/opened", 0);
    }
    elsif   ((l_xfr.getValue() > 80) and
            !getprop("controls/fuel/tank[1]/empty") and
            getprop("controls/APU/running"))
    {
        setprop("controls/fuel/tank[0]/boost-pump[0]", 1);
        setprop("controls/fuel/tank[0]/m-boost-pump[0]", 1);
        setprop("controls/fuel/tank[0]/boost-pump[3]", 0);
        setprop("controls/fuel/tank[0]/m-boost-pump[3]", 0);
        setprop("controls/APU/valve[1]/opened", 0);
    }
    elsif   (!getprop("consumables/fuel/tank[0]/empty") and
            (getprop("controls/fuel/tank[0]/boost-pump[0]") != 1) and
            (getprop("controls/fuel/tank[1]/boost-pump[0]") != 1) and
            (hot_bat.getValue() > 24) and
            getprop("controls/APU/running"))
    {
        setprop("controls/fuel/tank[0]/boost-pump[3]", 1);
        setprop("controls/fuel/tank[0]/m-boost-pump[3]", 1);
        setprop("controls/APU/valve[1]/opened", 1);
    }
    elsif (getprop("consumables/fuel/tank[0]/empty") and getprop("controls/fuel/tank[0]/boost-pump-switch[0]"))
    {
        setprop("controls/fuel/tank[0]/boost-pump[3]", 0);
        setprop("controls/fuel/tank[0]/m-boost-pump[3]", 0);
        setprop("controls/APU/valve[0]/opened", 0);
        setprop("controls/APU/valve[1]/opened", 0);
        setprop("controls/fuel/tank[0]/boost-pump[0]", 0);
        setprop("controls/fuel/tank[0]/m-boost-pump[0]", 2);
    }
    else
    {
        setprop("controls/fuel/tank[0]/boost-pump[0]", 0);
        setprop("controls/fuel/tank[0]/m-boost-pump[0]", 0);
        setprop("controls/fuel/tank[0]/boost-pump[3]", 0);
        setprop("controls/fuel/tank[0]/m-boost-pump[3]", 0);
        setprop("controls/APU/valve[0]/opened", 0);
        setprop("controls/APU/valve[1]/opened", 0);
    }
    if((getprop("controls/fuel/tank[0]/boost-pump[0]") == 0)
        and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/fuel/tank[0]/b-boost-pump[0]", 0);
    }
    else
    {
        setprop("controls/fuel/tank[0]/b-boost-pump[0]", 1);
    }
# LH boost #2
    if((!getprop("consumables/fuel/tank[0]/empty")
            and getprop("controls/fuel/tank/boost-pump-switch[1]")
            and (l_xfr.getValue() > 80))
        or getprop("sim/autostart"))
    {
        setprop("controls/fuel/tank[0]/boost-pump[1]", 1);
        setprop("controls/fuel/tank[0]/m-boost-pump[1]", 1);
    }
    elsif (getprop("consumables/fuel/tank[0]/empty") and getprop("controls/fuel/tank[0]/boost-pump-switch[1]"))
    {
        setprop("controls/fuel/tank[0]/boost-pump[1]", 0);
        setprop("controls/fuel/tank[0]/m-boost-pump[1]", 2);
    }
    else
    {
        setprop("controls/fuel/tank[0]/boost-pump[1]", 0);
        setprop("controls/fuel/tank[0]/m-boost-pump[1]", 0);
    }
    if((getprop("controls/fuel/tank[0]/boost-pump[1]") == 0)
        and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/fuel/tank[0]/b-boost-pump[1]", 0);
    }
    else
    {
        setprop("controls/fuel/tank[0]/b-boost-pump[1]", 1);
    }
# RH boost #1
    if(!getprop("consumables/fuel/tank[2]/empty")
            and getprop("controls/fuel/tank[2]/boost-pump-switch[0]")
            and (l_xfr.getValue() > 80))
    {
        setprop("controls/fuel/tank[2]/boost-pump[0]", 1);
        setprop("controls/fuel/tank[2]/m-boost-pump[0]", 1);
    }
    elsif (getprop("consumables/fuel/tank[2]/empty") and getprop("controls/fuel/tank[2]/boost-pump-switch[0]"))
    {
        setprop("controls/fuel/tank[2]/boost-pump[0]", 0);
        setprop("controls/fuel/tank[2]/m-boost-pump[0]", 2);
    }
    else
    {
        setprop("controls/fuel/tank[2]/boost-pump[0]", 0);
        setprop("controls/fuel/tank[2]/m-boost-pump[0]", 0);
    }
    if((getprop("controls/fuel/tank[2]/boost-pump[0]") == 0)
        and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/fuel/tank[2]/b-boost-pump[0]", 0);
    }
    else
    {
        setprop("controls/fuel/tank[2]/b-boost-pump[0]", 1);
    }
#RH boost #2
    if(!getprop("consumables/fuel/tank[2]/empty")
            and getprop("controls/fuel/tank[2]/boost-pump-switch[1]")
            and (l_xfr.getValue() > 80))
    {
        setprop("controls/fuel/tank[2]/boost-pump[1]", 1);
        setprop("controls/fuel/tank[2]/m-boost-pump[1]", 1);
    }
    elsif (getprop("consumables/fuel/tank[2]/empty") and getprop("controls/fuel/tank[2]/boost-pump-switch[1]"))
    {
        setprop("controls/fuel/tank[2]/boost-pump[1]", 0);
        setprop("controls/fuel/tank[2]/m-boost-pump[1]", 2);
    }
    else
    {
        setprop("controls/fuel/tank[2]/boost-pump[1]", 0);
        setprop("controls/fuel/tank[2]/m-boost-pump[1]", 0);
    }
    if((getprop("controls/fuel/tank[2]/boost-pump[1]") == 0)
        and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/fuel/tank[2]/b-boost-pump[1]", 0);
    }
    else
    {
        setprop("controls/fuel/tank[2]/b-boost-pump[1]", 1);
    }
#CTR boost #1
    if((!getprop("consumables/fuel/tank[1]/empty")
            or (aux_tanks
            and (!getprop("consumables/fuel/tank[3]/empty")
                or !getprop("consumables/fuel/tank[4]/empty")
                or !getprop("consumables/fuel/tank[5]/empty"))))
            and getprop("controls/fuel/tank[1]/boost-pump-switch[0]")
            and (l_xfr.getValue() > 80))
    {
        setprop("controls/fuel/tank[1]/boost-pump[0]", 1);
        setprop("controls/fuel/tank[1]/m-boost-pump[0]", 1);
    }
    elsif (getprop("controls/fuel/tank[1]/boost-pump-switch[0]"))
    {
        setprop("controls/fuel/tank[1]/boost-pump[0]", 0);
        setprop("controls/fuel/tank[1]/m-boost-pump[0]", 2);
    }
    else
    {
        setprop("controls/fuel/tank[1]/boost-pump[0]", 0);
        setprop("controls/fuel/tank[1]/m-boost-pump[0]", 0);
    }
    if((getprop("controls/fuel/tank[1]/boost-pump[0]") == 0)
        and (cpt_flt_inst.getValue() > 24)
        and getprop("controls/fuel/tank[1]/boost-pump-switch[0]") #Ctr Boost Pump Press lights are inhibited when switch in OFF position
        and (!getprop("consumables/fuel/tank[1]/empty")
            or (aux_tanks
            and (!getprop("consumables/fuel/tank[3]/empty")
                or !getprop("consumables/fuel/tank[4]/empty")
                or !getprop("consumables/fuel/tank[5]/empty")))))
    {
        setprop("controls/fuel/tank[1]/b-boost-pump[0]", 0);
    }
    else
    {
        setprop("controls/fuel/tank[1]/b-boost-pump[0]", 1);
    }
#CTR boost #2
    if((!getprop("consumables/fuel/tank[1]/empty")
            or (aux_tanks
            and (!getprop("consumables/fuel/tank[3]/empty")
                or !getprop("consumables/fuel/tank[4]/empty")
                or !getprop("consumables/fuel/tank[5]/empty"))))
            and getprop("controls/fuel/tank[1]/boost-pump-switch[1]")
            and (l_xfr.getValue() > 80))
    {
        setprop("controls/fuel/tank[1]/boost-pump[1]", 1);
        setprop("controls/fuel/tank[1]/m-boost-pump[1]", 1);
    }
    elsif (getprop("controls/fuel/tank[1]/boost-pump-switch[1]"))
    {
        setprop("controls/fuel/tank[1]/boost-pump[1]", 0);
        setprop("controls/fuel/tank[1]/m-boost-pump[1]", 2);
    }
    else
    {
        setprop("controls/fuel/tank[1]/boost-pump[1]", 0);
        setprop("controls/fuel/tank[1]/m-boost-pump[1]", 0);
    }
    if((getprop("controls/fuel/tank[1]/boost-pump[1]") == 0)
        and (cpt_flt_inst.getValue() > 24)
        and getprop("controls/fuel/tank[1]/boost-pump-switch[1]") #Ctr Boost Pump Press lights are inhibited when switch in OFF position
        and (!getprop("consumables/fuel/tank[1]/empty")
            or (aux_tanks
            and (!getprop("consumables/fuel/tank[3]/empty")
                or !getprop("consumables/fuel/tank[4]/empty")
                or !getprop("consumables/fuel/tank[5]/empty")))))
    {
        setprop("controls/fuel/tank[1]/b-boost-pump[1]", 0);
    }
    else
    {
        setprop("controls/fuel/tank[1]/b-boost-pump[1]", 1);
    }

#FUEL Jettison

    # Calculate Fuel To Remain in auto mode: Dump Fuel until below maximum landing weight.
    if (getprop("controls/fuel/jettison-arm-switch")) {
        if (getprop("controls/fuel/jettison-FTR-manual")) {
            setprop("controls/fuel/JettManMLW", "MAN");
            setprop("controls/fuel/FuelToRemain-rate", getprop("controls/fuel/FuelToRemain-knob") * 1000 * deltatime);
            setprop("controls/fuel/FuelToRemain-hover", getprop("controls/fuel/FuelToRemain-knob") * 1000);
            setprop("controls/fuel/FuelToRemain-lbs", getprop("controls/fuel/FuelToRemain-lbs") + getprop("controls/fuel/FuelToRemain-rate"));
        } else {
            setprop("controls/fuel/FuelToRemain-lbs", getprop("sim/max-landing-weight") - getprop("yasim/zero-fuel-weight-lbs"));
            setprop("controls/fuel/JettManMLW", "MLW");
        }

        # Stand pipes in both main tanks prohibit jettisoning down to a level below 5200kg/11464lbs in each tank
        if (getprop("controls/fuel/FuelToRemain-lbs") < 22928) {
            setprop("controls/fuel/FuelToRemain-lbs", 22928);

        }
        setprop("controls/fuel/FuelToRemain-norm", sprintf("%.4f", (getprop("controls/fuel/FuelToRemain-lbs") / getprop("consumables/fuel/tank[1]/density-ppg")) / (getprop("consumables/fuel/tank[0]/capacity-gal_us") + getprop("consumables/fuel/tank[1]/capacity-gal_us") + getprop("consumables/fuel/tank[2]/capacity-gal_us"))));

        if (getprop("consumables/fuel/total-fuel-lbs") > getprop("controls/fuel/FuelToRemain-lbs")) {
            setprop("controls/fuel/jettison-timeremain-min", (getprop("consumables/fuel/total-fuel-lbs") - getprop("controls/fuel/FuelToRemain-lbs")) / 5500);
        } else {
            setprop("controls/fuel/jettison-timeremain-min", 0.0);
        }

    } else {
        # Disable dumping if the nozzle switches are pressed before the jettisoning system is armed.
        # To unblock the nozzle switches: disarm the jettison system and close the nozzle switches. Then arm the system and proceed.
        if (getprop("controls/fuel/tank[0]/nozzle-switch")) {
            setprop("controls/fuel/tank[0]/nozzle-blocked", 1);
            setprop("controls/fuel/tank[0]/b-nozzle", 0);
            setprop("controls/fuel/tank[0]/nozzle-valve", 2);
        } else {
            setprop("controls/fuel/tank[0]/nozzle-blocked", 0);
            setprop("controls/fuel/tank[0]/b-nozzle", 1);
            setprop("controls/fuel/tank[0]/nozzle-valve", 0);
        }
        if (getprop("controls/fuel/tank[2]/nozzle-switch")) {
            setprop("controls/fuel/tank[2]/nozzle-blocked", 1);
            setprop("controls/fuel/tank[2]/b-nozzle", 0);
            setprop("controls/fuel/tank[2]/nozzle-valve", 2);
        } else {
            setprop("controls/fuel/tank[2]/nozzle-blocked", 0);
            setprop("controls/fuel/tank[2]/b-nozzle", 1);
            setprop("controls/fuel/tank[2]/nozzle-valve", 0);
        }
        setprop("controls/fuel/JettManMLW", "");
    }

    if(getprop("controls/fuel/jettison-arm-switch")
        and getprop("controls/flight/air-sensing-sw")
        and (getprop("consumables/fuel/total-fuel-norm") > getprop("controls/fuel/FuelToRemain-norm")))
    # Jettison Fuel @ 2500 kg/5511lbs/minute
    {
        var jettisonrate = (5511.5566 * deltatime / 60 / getprop("consumables/fuel/tank[0]/density-ppg") / 2); #convert lbs/min to USgal/sec per valve

        #If there is fuel in the center tank, fuel is dumped from the three tanks at the same time
        if(getprop("controls/fuel/tank[0]/b-nozzle") and getprop("controls/fuel/tank[0]/nozzle-switch") and !getprop("controls/fuel/tank[0]/nozzle-blocked")) {
            setprop("controls/fuel/tank[0]/nozzle-valve", 1);
            setprop("controls/fuel/tank[0]/boost-pump[2]", 1);
            setprop("controls/fuel/tank[0]/m-boost-pump[2]", 1);
            if(getprop("consumables/fuel/tank[1]/level-gal_us") > 0) {
                setprop("controls/fuel/tank[1]/nozzle-valve[0]", 1);
                setprop("controls/fuel/tank[1]/nozzle-valve[1]", 1);
            }
            if(getprop("consumables/fuel/tank[1]/level-gal_us") > 0) {
                if (getprop("consumables/fuel/tank[0]/level-lbs") > 11464) {
                    setprop("consumables/fuel/tank[1]/level-gal_us", getprop("consumables/fuel/tank[1]/level-gal_us") - 0.80 * jettisonrate);
                    setprop("consumables/fuel/tank[0]/level-gal_us", getprop("consumables/fuel/tank[0]/level-gal_us") - 0.20 * jettisonrate);
                } else {
                    setprop("consumables/fuel/tank[1]/level-gal_us", getprop("consumables/fuel/tank[1]/level-gal_us") - jettisonrate);
                }
                setprop("controls/fuel/tank[0]/nozzlestate", "Jettisoning");
                setprop("controls/fuel/tank[0]/jettisoning", 1);

            } elsif (getprop("consumables/fuel/tank[0]/level-lbs") > 11464) {
                setprop("consumables/fuel/tank[0]/level-gal_us", getprop("consumables/fuel/tank[0]/level-gal_us") - jettisonrate);
                setprop("controls/fuel/tank[0]/nozzlestate", "Jettisoning");
                setprop("controls/fuel/tank[0]/jettisoning", 1);
            } else {
                setprop("controls/fuel/tank[0]/jettisoning", 0);
                setprop("controls/fuel/tank[0]/boost-pump[2]", 0);
                setprop("controls/fuel/tank[0]/m-boost-pump[2]", 2);
            }
        } else {
            setprop("controls/fuel/tank[0]/jettisoning", 0);
            setprop("controls/fuel/tank[0]/nozzle-valve", 0);
            setprop("controls/fuel/tank[0]/boost-pump[2]", 0);
            setprop("controls/fuel/tank[0]/m-boost-pump[2]", 0);
            if(!getprop("controls/fuel/tank[2]/b-nozzle") or !getprop("controls/fuel/tank[2]/nozzle-switch")) {
                setprop("controls/fuel/tank[1]/nozzle-valve[0]", 0);
                setprop("controls/fuel/tank[1]/nozzle-valve[1]", 0);
            }
        }

        if(getprop("controls/fuel/tank[2]/b-nozzle") and getprop("controls/fuel/tank[2]/nozzle-switch") and !getprop("controls/fuel/tank[2]/nozzle-blocked")) {
            setprop("controls/fuel/tank[2]/nozzle-valve", 1);
            setprop("controls/fuel/tank[2]/boost-pump[2]", 1);
            setprop("controls/fuel/tank[2]/m-boost-pump[2]", 1);
            if(getprop("consumables/fuel/tank[1]/level-gal_us") > 0) {
                setprop("controls/fuel/tank[1]/nozzle-valve[0]", 1);
                setprop("controls/fuel/tank[1]/nozzle-valve[1]", 1);
            }
            if(getprop("consumables/fuel/tank[1]/level-gal_us") > 0) {
                if (getprop("consumables/fuel/tank[2]/level-lbs") > 11464) {
                    setprop("consumables/fuel/tank[1]/level-gal_us", getprop("consumables/fuel/tank[1]/level-gal_us")- 0.80 * jettisonrate);
                    setprop("consumables/fuel/tank[2]/level-gal_us", getprop("consumables/fuel/tank[2]/level-gal_us")- 0.20 * jettisonrate);
                } else {
                    setprop("consumables/fuel/tank[1]/level-gal_us", getprop("consumables/fuel/tank[1]/level-gal_us") - jettisonrate);
                }
                setprop("controls/fuel/tank[2]/nozzlestate", "Jettisoning");
                setprop("controls/fuel/tank[2]/jettisoning", 1);
            } elsif (getprop("consumables/fuel/tank[2]/level-lbs") > 11464) {
                setprop("consumables/fuel/tank[2]/level-gal_us", getprop("consumables/fuel/tank[2]/level-gal_us") - jettisonrate);
                setprop("controls/fuel/tank[2]/nozzlestate", "Jettisoning");
                setprop("controls/fuel/tank[2]/jettisoning", 1);
            } else {
                setprop("controls/fuel/tank[2]/jettisoning", 0);
                setprop("controls/fuel/tank[2]/boost-pump[2]", 0);
                setprop("controls/fuel/tank[2]/m-boost-pump[2]", 2);
            }
        } else {
            setprop("controls/fuel/tank[2]/jettisoning", 0);
            setprop("controls/fuel/tank[2]/nozzle-valve", 0);
            setprop("controls/fuel/tank[2]/boost-pump[2]", 0);
            setprop("controls/fuel/tank[2]/m-boost-pump[2]", 0);
            if(!getprop("controls/fuel/tank[0]/b-nozzle") or !getprop("controls/fuel/tank[0]/nozzle-switch")) {
                setprop("controls/fuel/tank[1]/nozzle-valve[0]", 0);
                setprop("controls/fuel/tank[1]/nozzle-valve[1]", 0);
            }
        }
    } elsif (getprop("controls/fuel/jettison-arm-switch")
        and (!getprop("controls/fuel/tank[0]/nozzle-blocked"))
        and (!getprop("controls/fuel/tank[2]/nozzle-blocked"))
        and     ((getprop("controls/fuel/tank[0]/nozzle-switch"))
            or (getprop("controls/fuel/tank[2]/nozzle-switch"))))
    {
        # Jettisoning finished nozzles close, pumps stop; nozzles must be switched off to reset system.
        setprop("controls/fuel/tank[0]/jettisoning", 0);
        setprop("controls/fuel/tank[2]/jettisoning", 0);
        if (getprop("controls/fuel/tank[0]/nozzle-switch") or !getprop("controls/fuel/tank[0]/b-nozzle")) {
            setprop("controls/fuel/tank[0]/nozzle-valve", 1);
        } else {
            setprop("controls/fuel/tank[0]/nozzle-valve", 0);
        }
        setprop("controls/fuel/tank[1]/nozzle-valve[0]", 2);
        setprop("controls/fuel/tank[1]/nozzle-valve[1]", 2);
        if (getprop("controls/fuel/tank[2]/nozzle-switch") or !getprop("controls/fuel/tank[2]/b-nozzle")) {
            setprop("controls/fuel/tank[2]/nozzle-valve", 1);
        } else {
            setprop("controls/fuel/tank[2]/nozzle-valve", 0);
        }
        setprop("controls/fuel/tank[0]/boost-pump[2]", 0);
        setprop("controls/fuel/tank[0]/m-boost-pump[2]", 2);
        setprop("controls/fuel/tank[2]/boost-pump[2]", 0);
        setprop("controls/fuel/tank[2]/m-boost-pump[2]", 2);
    } else {
        setprop("controls/fuel/tank[0]/jettisoning", 0);
        setprop("controls/fuel/tank[2]/jettisoning", 0);
        if (    !getprop("controls/fuel/tank[0]/nozzle-blocked")
            and !getprop("controls/fuel/tank[0]/nozzle-switch")
            and getprop("controls/fuel/tank[0]/b-nozzle"))
        {
            setprop("controls/fuel/tank[0]/nozzle-valve", 0);
        } elsif ((   (getprop("controls/fuel/tank[0]/nozzle-switch")
                and getprop("controls/fuel/tank[0]/b-nozzle")
                and (getprop("consumables/fuel/total-fuel-norm") > getprop("controls/fuel/FuelToRemain-norm")))
            or
                    ((getprop("consumables/fuel/total-fuel-norm") < getprop("controls/fuel/FuelToRemain-norm"))
                and     (!getprop("controls/fuel/tank[0]/nozzle-switch")
                    or  !getprop("controls/fuel/tank[0]/b-nozzle"))))
            and !getprop("controls/fuel/tank[0]/nozzle-blocked"))
        {
            setprop("controls/fuel/tank[0]/nozzle-valve", 1);
        } elsif (getprop("controls/fuel/tank[0]/nozzle-blocked") or !getprop("controls/fuel/tank[0]/b-nozzle")) {
            setprop("controls/fuel/tank[0]/nozzle-valve", 2);
        }
        setprop("controls/fuel/tank[1]/nozzle-valve[0]", 0);
        setprop("controls/fuel/tank[1]/nozzle-valve[1]", 0);
        if (    !getprop("controls/fuel/tank[2]/nozzle-blocked")
            and !getprop("controls/fuel/tank[2]/nozzle-switch")
            and getprop("controls/fuel/tank[2]/b-nozzle"))
        {
            setprop("controls/fuel/tank[2]/nozzle-valve", 0);
        } elsif ((   (getprop("controls/fuel/tank[2]/nozzle-switch")
                and getprop("controls/fuel/tank[2]/b-nozzle")
                and (getprop("consumables/fuel/total-fuel-norm") > getprop("controls/fuel/FuelToRemain-norm")))
            or
                    ((getprop("consumables/fuel/total-fuel-norm") < getprop("controls/fuel/FuelToRemain-norm"))
                and     (!getprop("controls/fuel/tank[2]/nozzle-switch")
                    or  !getprop("controls/fuel/tank[2]/b-nozzle"))))
            and !getprop("controls/fuel/tank[2]/nozzle-blocked"))
        {
            setprop("controls/fuel/tank[2]/nozzle-valve", 1);
        } elsif (getprop("controls/fuel/tank[2]/nozzle-blocked") or !getprop("controls/fuel/tank[0]/b-nozzle")) {
            setprop("controls/fuel/tank[2]/nozzle-valve", 2);
        }
        setprop("controls/fuel/tank[0]/boost-pump[2]", 0);
        setprop("controls/fuel/tank[0]/m-boost-pump[2]", 0);
        setprop("controls/fuel/tank[2]/boost-pump[2]", 0);
        setprop("controls/fuel/tank[2]/m-boost-pump[2]", 0);
    }

    if (getprop("controls/fuel/tank[0]/nozzle-blocked")) {
        setprop("controls/fuel/tank[0]/nozzlestate", "Blocked");
    } elsif (!getprop("controls/fuel/tank[0]/b-nozzle") and getprop("controls/fuel/tank[0]/nozzle-switch")) {
        setprop("controls/fuel/tank[0]/nozzlestate", "Opening");
    } elsif (getprop("controls/fuel/tank[0]/b-nozzle") and getprop("controls/fuel/tank[0]/nozzle-switch")) {
        setprop("controls/fuel/tank[0]/nozzlestate", "Open");
    } elsif (!getprop("controls/fuel/tank[0]/b-nozzle")and !getprop("controls/fuel/tank[0]/nozzle-switch")) {
        setprop("controls/fuel/tank[0]/nozzlestate", "Closing");
    } else {
        setprop("controls/fuel/tank[0]/nozzlestate", "Closed");
    }

    if (getprop("controls/fuel/tank[2]/nozzle-blocked")) {
        setprop("controls/fuel/tank[2]/nozzlestate", "Blocked");
    } elsif (!getprop("controls/fuel/tank[2]/b-nozzle") and getprop("controls/fuel/tank[2]/nozzle-switch")) {
        setprop("controls/fuel/tank[2]/nozzlestate", "Opening");
    } elsif (getprop("controls/fuel/tank[2]/b-nozzle") and getprop("controls/fuel/tank[2]/nozzle-switch")) {
        setprop("controls/fuel/tank[2]/nozzlestate", "Open");
    } elsif (!getprop("controls/fuel/tank[2]/b-nozzle") and !getprop("controls/fuel/tank[2]/nozzle-switch")) {
        setprop("controls/fuel/tank[2]/nozzlestate", "Closing");
    } else {
        setprop("controls/fuel/tank[2]/nozzlestate", "Closed");
    }

# Ctr Tank Fuel Scavage pumps empty the center tank into the main tanks when boost pumps deactivated and ctr fuel level low

    var CtrFuelLevel_lbs = getprop("consumables/fuel/tank[1]/level-lbs");
    var MainFuelLevel0_lbs = getprop("consumables/fuel/tank[0]/level-lbs");
    var MainFuelLevel2_lbs = getprop("consumables/fuel/tank[2]/level-lbs");
    var Scavagerate_lbs = (0.5 * deltatime); #Transfer 0.5 lbs of fuel per second
    if (!getprop("consumables/fuel/tank[1]/empty") and
        (CtrFuelLevel_lbs < 2400) and
        !getprop("controls/fuel/tank[1]/boost-pump[0]") and
        !getprop("controls/fuel/tank[1]/boost-pump[1]") and
        (l_xfr.getValue() > 80) and
        (getprop("consumables/fuel/tank[0]/level-gal_us") < getprop("consumables/fuel/tank[0]/capacity-gal_us")) and
        (getprop("consumables/fuel/tank[2]/level-gal_us") < getprop("consumables/fuel/tank[2]/capacity-gal_us")))
    {
        if (CtrFuelLevel_lbs < Scavagerate_lbs) {
            setprop("consumables/fuel/tank[0]/level-lbs", MainFuelLevel0_lbs += CtrFuelLevel_lbs / 2);
            setprop("consumables/fuel/tank[1]/level-lbs", 0);
            setprop("consumables/fuel/tank[2]/level-lbs", MainFuelLevel2_lbs += CtrFuelLevel_lbs / 2);
        } else {
            setprop("consumables/fuel/tank[0]/level-lbs", MainFuelLevel0_lbs += Scavagerate_lbs / 2);
            setprop("consumables/fuel/tank[1]/level-lbs", CtrFuelLevel_lbs -= Scavagerate_lbs);
            setprop("consumables/fuel/tank[2]/level-lbs", MainFuelLevel2_lbs += Scavagerate_lbs / 2);
        }
    }

# Fuel X-feed system
    #X-feed procedure:
    # if fuel imbalance: open fwd and aft fuel x-feed valves;
    # shut down boost pumps from the main tank with the lowest fuel level
    # fuel is now feeded from the other tank to both engines
    # when imbalance is over: reactivate boost pumps and close x-feed valves
    var xfeedfwd_switch = getprop("controls/fuel/xfeedfwd-switch");
    var xfeedaft_switch = getprop("controls/fuel/xfeedaft-switch");
    var xfeedfwd_pwr = getprop("controls/fuel/xfeedfwd-valve/powered");
    var xfeedaft_pwr = getprop("controls/fuel/xfeedaft-valve/powered");
    var xfeedfwd_valve = getprop("controls/fuel/xfeedfwd-valve/opened");
    var xfeedaft_valve = getprop("controls/fuel/xfeedaft-valve/opened");
    var xfeedfwd_a_valve = aircraft.door.new("controls/fuel/xfdfwd-vlv", 2.0);
    var xfeedaft_a_valve = aircraft.door.new("controls/fuel/xfdaft-vlv", 2.0);
    var mainpumpfwdl = getprop("controls/fuel/tank[0]/boost-pump[0]");
    var mainpumpaftl = getprop("controls/fuel/tank[0]/boost-pump[1]");
    var mainpumpfwdr = getprop("controls/fuel/tank[2]/boost-pump[0]");
    var mainpumpaftr = getprop("controls/fuel/tank[2]/boost-pump[1]");
    var ctrpumpl = getprop("controls/fuel/tank[1]/boost-pump[0]");
    var ctrpumpr = getprop("controls/fuel/tank[1]/boost-pump[1]");

    # configure x-feed valves; actual fuel transfer is done in engine.nas
    if (xfeedfwd_switch and xfeedfwd_pwr) {
        if (xfeedfwd_a_valve.getpos() == 0) {
            xfeedfwd_a_valve.open();
            setprop("controls/fuel/b-xfdfwd-vlv", 0);
        }
        if ((xfeedfwd_a_valve.getpos() == 1) and xfeedfwd_valve != 1) {
            setprop("controls/fuel/xfeedfwd-valve/opened", 1);
            setprop("controls/fuel/b-xfdfwd-vlv", 1);
        }
    } else {
        if (xfeedfwd_valve) {
            setprop("controls/fuel/xfeedfwd-valve/opened", 0);
            setprop("controls/fuel/b-xfdfwd-vlv", 0);
            xfeedfwd_a_valve.close();
        } elsif (xfeedfwd_a_valve.getpos() == 0) {
            setprop("controls/fuel/b-xfdfwd-vlv", 1);
        }
    }
    if (xfeedaft_switch and xfeedaft_pwr) {
        if (xfeedaft_a_valve.getpos() == 0) {
            xfeedaft_a_valve.open();
            setprop("controls/fuel/b-xfdaft-vlv", 0);
        }
        if ((xfeedaft_a_valve.getpos() == 1) and xfeedaft_valve != 1) {
            setprop("controls/fuel/xfeedaft-valve/opened", 1);
            setprop("controls/fuel/b-xfdaft-vlv", 1);
        }
    } else {
        if (xfeedaft_valve) {
            setprop("controls/fuel/xfeedaft-valve/opened", 0);
            setprop("controls/fuel/b-xfdaft-vlv", 0);
            xfeedaft_a_valve.close();
        } elsif (xfeedaft_a_valve.getpos() == 0) {
            setprop("controls/fuel/b-xfdaft-vlv", 1);
        }
    }

    # Fuel Imbalance prop
    if (abs(getprop("consumables/fuel/tank[0]/level-lbs") - getprop("consumables/fuel/tank[2]/level-lbs")) > 3000) {
        setprop("controls/fuel/imbalance", 1);
        setprop("controls/fuel/imbalance-1", 0);
    } elsif ((getprop("controls/fuel/imbalance") == 1) and (getprop("controls/fuel/imbalance-1") == 0)) {
        setprop("controls/fuel/imbalance", 0);
        setprop("controls/fuel/imbalance-1", 1); # used for checklist
    }

    # Check if L main pipe should be disabled (x-feed off, main and center tank pump off)
    if (xfeedaft_valve != 1 and xfeedfwd_valve != 1 and mainpumpfwdl != 1 and mainpumpaftl != 1 and ctrpumpl != 1) {
        setprop("controls/fuel/xfd-off-l", 1);
    } else {
        setprop("controls/fuel/xfd-off-l", 0);
    }

    # Check if R main pipe should be disabled (x-feed off, main and center tank pump off)
    if (xfeedaft_valve != 1 and xfeedfwd_valve != 1 and mainpumpfwdr != 1 and mainpumpaftr != 1 and ctrpumpr != 1) {
        setprop("controls/fuel/xfd-off-r", 1); #Override pipe
    } else {
        setprop("controls/fuel/xfd-off-r", 0);
    }

#EEC Autostart
    if((getprop("controls/engines/autostart") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/engines/b-autostart", 0);
    }
    else
    {
        setprop("controls/engines/b-autostart", 1);
    }
#EEC Left
    if((getprop("controls/engines/engine/eec-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/engines/engine/b-eec-switch", 0);
    }
    else
    {
        setprop("controls/engines/engine/b-eec-switch", 1);
    }
#EEC Right
    if((getprop("controls/engines/engine[1]/eec-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/engines/engine[1]/b-eec-switch", 0);
    }
    else
    {
        setprop("controls/engines/engine[1]/b-eec-switch", 1);
    }
#WINDOWS HEAT
    if((getprop("controls/anti-ice/window-heat-ls-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/anti-ice/window-heat-ls", 0);
    }
    else
    {
        setprop("controls/anti-ice/window-heat-ls", 1);
    }
    if((getprop("controls/anti-ice/window-heat-lf-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/anti-ice/window-heat-lf", 0);
    }
    else
    {
        setprop("controls/anti-ice/window-heat-lf", 1);
    }
    if((getprop("controls/anti-ice/window-heat-rf-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/anti-ice/window-heat-rf", 0);
    }
    else
    {
        setprop("controls/anti-ice/window-heat-rf", 1);
    }
    if((getprop("controls/anti-ice/window-heat-rs-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/anti-ice/window-heat-rs", 0);
    }
    else
    {
        setprop("controls/anti-ice/window-heat-rs", 1);
    }
    if((getprop("controls/flight/adiru-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/flight/adiru", 0);
    }
    else
    {
        setprop("controls/flight/adiru", 1);
    }
    if((getprop("controls/flight/thrust-asym-switch") == 0)
            and (cpt_flt_inst.getValue() > 24))
    {
        setprop("controls/flight/thrust-asym", 0);
    }
    else
    {
        setprop("controls/flight/thrust-asym", 1);
    }
    if((cpt_flt_inst.getValue() < 24)
            or (getprop("controls/switches/fire/cargo-fwd-switch") == 0))
    {
        setprop("controls/switches/fire/cargo-fwd", 1);
    }
    else
    {
        setprop("controls/switches/fire/cargo-fwd", 0);
    }
    if((cpt_flt_inst.getValue() < 24)
            or (getprop("controls/switches/fire/cargo-aft-switch") == 0))
    {
        setprop("controls/switches/fire/cargo-aft", 1);
    }
    else
    {
        setprop("controls/switches/fire/cargo-aft", 0);
    }
}

var update_systems = func {
    Efis.calc_kpa();
    Efis.update_temp();
    LHeng.update();
    RHeng.update();
    #wiper.active(); # not implemented yet!
    setprop("instrumentation/efis/mfd/rangearc", (Efis.mfd_display_mode.getValue() == "MAP")
        and (Efis.wxr.getValue() or Efis.terr.getValue() or Efis.tfc.getValue()));
    setprop("instrumentation/efis[1]/mfd/rangearc", (Efis2.mfd_display_mode.getValue() == "MAP")
        and (Efis2.wxr.getValue() or Efis2.terr.getValue() or Efis2.tfc.getValue()));
    var et_tmp = getprop("instrumentation/clock/ET-sec");
    if(et_tmp == 0)
    {
        et_tmp = getprop("instrumentation/clock/elapsetime-sec");
    }
    var et_min = int(et_tmp * 0.0166666666667);
    var et_hr  = int(et_min * 0.0166666666667);
    et_min = et_min - (et_hr * 60);
    et_tmp = et_hr * 100 + et_min;
    setprop("instrumentation/clock/ET-display",et_tmp);
    et_tmp = int(getprop("instrumentation/clock/elapsetime-sec") * 0.0166666666667);
    et_hr = int(et_tmp * 0.0166666666667);
    et_min = et_tmp - (et_hr * 60);
    et_tmp = sprintf("%02d:%02d", et_hr, et_min);
    setprop("instrumentation/clock/elapsed-string", et_tmp);
    switch_ind();
    setprop("instrumentation/rmu/unit/offside_tuned",
        (((getprop("instrumentation/rmu/unit/vhf-l") == 0) and (getprop("instrumentation/rmu/unit/hf-l") == 0))
            or getprop("instrumentation/rmu/unit[1]/vhf-l")
            or getprop("instrumentation/rmu/unit[1]/hf-l")
            or getprop("instrumentation/rmu/unit[2]/vhf-l")
            or getprop("instrumentation/rmu/unit[2]/hf-l")));
    setprop("instrumentation/rmu/unit[1]/offside_tuned",
        (((getprop("instrumentation/rmu/unit[1]/vhf-r") == 0) and (getprop("instrumentation/rmu/unit[1]/hf-r") == 0))
            or getprop("instrumentation/rmu/unit/vhf-r")
            or getprop("instrumentation/rmu/unit/hf-r")
            or getprop("instrumentation/rmu/unit[2]/vhf-r")
            or getprop("instrumentation/rmu/unit[2]/hf-r")));
    setprop("instrumentation/rmu/unit[2]/offside_tuned",
        ((getprop("instrumentation/rmu/unit[2]/vhf-c") == 0)
            or getprop("instrumentation/rmu/unit/vhf-c")
            or getprop("instrumentation/rmu/unit[1]/vhf-c")));

    settimer(update_systems,0);
}

# Elevator Trim FBW Handler - Do Not Touch or C*U Control Law Might Behave Preposterously! -JD
var slewProp = func(prop, delta) {
	delta *= getprop("/sim/time/delta-realtime-sec");
	setprop(prop, getprop(prop) + delta);
	return getprop(prop);
}

setprop("/controls/flight/elevator-trim-time", 0);
setprop("/fcs/fbw/pitch/trim-kts-switch", 0);

controls.elevatorTrim = func(d) {
	if (getprop("/fcs/fbw/active") == 1 and getprop("/instrumentation/afds/inputs/AP") != 1) { # Command FBW to change trim speed
		setprop("/fcs/fbw/pitch/trim-kts-switch", d);
		setprop("/controls/flight/elevator-trim-time", getprop("/sim/time/elapsed-sec"));
		elevatorTrimTimer.start();
	} else if (getprop("/instrumentation/afds/inputs/AP") != 1) { # Actually move the stabilizer
		setprop("/fcs/fbw/pitch/trim-kts-switch", 0);
		slewProp("/controls/flight/elevator-trim", d * 0.04);
	}
}

var elevatorTrimTimer = maketimer(0.05, func {
	if (getprop("/fcs/fbw/active") == 1 and getprop("/instrumentation/afds/inputs/AP") != 1) {
		if (getprop("/controls/flight/elevator-trim-time") + 0.1 <= getprop("/sim/time/elapsed-sec")) {
			elevatorTrimTimer.stop();
			setprop("/fcs/fbw/pitch/trim-kts-switch", 0);
		}
	} else {
		elevatorTrimTimer.stop();
		setprop("/fcs/fbw/pitch/trim-kts-switch", 0);
	}
});

# Stuff for storing settings, derived from ACCONFIG
# Add any properties in this way and they will be stored/restored
setprop("/systems/acconfig/options/show-fbw-bug", 0);

var readSettings = func {
	io.read_properties(getprop("/sim/fg-home") ~ "/Export/777-config.xml", "/systems/acconfig/options");
	setprop("/fcs/fbw/show-fbw-bug", getprop("/systems/acconfig/options/show-fbw-bug"));
}

var writeSettings = func {
	setprop("/systems/acconfig/options/show-fbw-bug", getprop("/fcs/fbw/show-fbw-bug"));
	io.write_properties(getprop("/sim/fg-home") ~ "/Export/777-config.xml", "/systems/acconfig/options");
}
