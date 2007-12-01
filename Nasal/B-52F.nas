#--------------------------------------------------------------------
var start_up = func {
  settimer(initialise_drop_view_pos, 5);
  settimer(yaw_monitor, 5);
  settimer(steering_instrument_update, 5);
  setlistener("/controls/gear/steering-front-norm", yaw_steering);
  setlistener("/autopilot/locks/altitude", pitch_hold_monitor);
  setlistener("/instrumentation/terrain-radar/hi-elev/alt-ft", tfa_high_alt_monitor);
  var dialog = gui.Dialog.new("/sim/gui/dialogs/B-52F/TFA-popup/dialog",
               "Aircraft/B-52F/Dialogs/TFA-popup.xml");
}
#--------------------------------------------------------------------
var autotakeoff = func {
  if(getprop("/autopilot/locks/auto-take-off") == "enabled") {
    ato_initiation();
  }
}
#--------------------------------------------------------------------
var ato_initiation = func {
  # Check that the steering-heading-deg has been reset
  # (< -999), that the a/c is on the ground and that the flaps
  # have been deployed.  If so, auto-takeoff is started.
  if(getprop("/autopilot/settings/steering-heading-deg") < -999) {
    if(getprop("/position/gear-agl-ft") < 0.10) {
      if(getprop("surface-positions/left-flap-pos-norm") > 0.999) {
        if(getprop("surface-positions/right-flap-pos-norm") > 0.999) {
          var hdgdeg =  getprop("/orientation/heading-deg");
          var toptdeg = getprop("/autopilot/settings/take-off-pitch-deg");
          setprop("/autopilot/settings/steering-heading-deg", hdgdeg);
          setprop("/autopilot/settings/true-heading-deg", hdgdeg);
          setprop("/autopilot/settings/target-aoa-deg", 0);
          setprop("/autopilot/settings/target-climb-rate-fps", 0);
          setprop("/autopilot/settings/target-pitch-deg", toptdeg);
          setprop("/autopilot/settings/target-roll-deg", 0);
          setprop("/autopilot/settings/target-speed-kt", 310);
          setprop("/autopilot/locks/altitude", "ground-roll");
          setprop("/autopilot/locks/speed", "speed-with-throttle");
          setprop("/autopilot/locks/heading", "wing-leveler");
          setprop("/autopilot/locks/take-off-phase", "take-off");
          setprop("/autopilot/locks/auto-take-off", "engaged");
          setprop("/controls/flight/spoilers", 0);
          setprop("/controls/gear/brake-left", 0);
          setprop("/controls/gear/brake-right", 0);
          setprop("/controls/gear/brake-parking", 0);
          ato_loop();
        }
      }
    }
  }
}
#--------------------------------------------------------------------
var ato_loop = func {
  if(getprop("/autopilot/locks/auto-take-off") == "engaged") {
#    ato_heading();
    ato_mode();
    ato_winject();
    ato_spddep();
    settimer(ato_loop, 0.1);
  }
}
#--------------------------------------------------------------------
var ato_mode = func {
  var agl =     getprop("/position/altitude-agl-ft");
  if(agl > 50) {
    var tophase = getprop("/autopilot/locks/take-off-phase");
    if(tophase == "take-off") {
      var coiptdeg = getprop("/autopilot/settings/climb-out-initial-pitch-deg");
      setprop("/autopilot/locks/rudder-control", "reset");
      setprop("/autopilot/locks/steering-front", "reset");
      setprop("/controls/gear/gear-down", "false");
      interpolate("/autopilot/settings/target-pitch-deg", coiptdeg, 4);
      setprop("/autopilot/locks/take-off-phase", "climb-out");
    }
  }
}
#--------------------------------------------------------------------
var ato_winject = func {
  # This script controls the water injection spoof (reheat)
  var airspeed = getprop("/velocities/airspeed-kt");
  if(airspeed > 0) {
    if(airspeed < 220) {
      setprop("/controls/engines/engine[0]/afterburner", 1);
    } else {
      setprop("/controls/engines/engine[0]/afterburner", 0);
    }
  }
}
#--------------------------------------------------------------------
var ato_spddep = func {
  # This script controls speed dependent actions.
  var airspeed = getprop("/velocities/airspeed-kt");
  var flpretkt = getprop("/autopilot/settings/flap-retract-speed-kt");
  var rdrctrl = getprop("/autopilot/locks/rudder-control");
  if(airspeed < 40) {
    # Do nothing until we're moving.
  } else {
    if(airspeed < flpretkt) {
      setprop("/autopilot/locks/rudder-control", "rudder-hold");
      setprop("/autopilot/locks/steering-front", "ground-roll");
      setprop("/autopilot/locks/altitude", "take-off");
    } else {
      if(airspeed < 260) {
        if(rdrctrl != "") {
          setprop("/autopilot/locks/rudder-control", "reset");
          if(rdrctrl != "") {
            setprop("/autopilot/locks/rudder-control", "");
            interpolate("/controls/flight/rudder", 0, 10);
          }
        }
        setprop("/autopilot/locks/steering-front", "");
        setprop("/controls/gear/steering-front-norm", 0);
        setprop("/controls/flight/flaps", 0);
        var cofptdeg = getprop("/autopilot/settings/climb-out-final-pitch-deg");
        interpolate("/autopilot/settings/target-pitch-deg", cofptdeg, 8);
      } else {
        if(getprop("surface-positions/left-flap-pos-norm") < 0.001) {
          if(getprop("surface-positions/right-flap-pos-norm") < 0.001) {
            # Switch to true-heading-hold, Mach-Hold throttle
            # mode, mach-hold-climb mode and disable Take-Off mode.
            setprop("/autopilot/locks/heading", "true-heading-hold");
            setprop("/autopilot/locks/altitude", "altitude-hold");
            setprop("/autopilot/locks/auto-take-off", "disabled");
            setprop("/autopilot/locks/auto-landing", "enabled");
            setprop("/autopilot/settings/target-climb-rate-fps", 0);
          }
        }
      }
    }
  }
  # This little section just copies the current climb-rate to the 
  # target-climb-rate-fps setting in the autopilot to smooth the
  # transition bewteen pitch-hold and altitude-hold on completion
  # of take-off
  var ccrfps = getprop("/velocities/vertical-speed-fps");
  setprop("/autopilot/settings/target-climb-rate-fps", ccrfps);
}
#--------------------------------------------------------------------
var autoland = func {
  if(getprop("/autopilot/locks/auto-landing") == "enabled") {
    setprop("/autopilot/locks/auto-landing", "engaged");
    atl_initiation();
  }
}
#--------------------------------------------------------------------
var atl_initiation = func {
  var cvfps =     getprop("/velocities/vertical-speed-fps");
  var flpextaoa = getprop("/autopilot/settings/flap-extend-aoa-deg");
  var weight =    getprop("/yasim/gross-weight-lbs");

  setprop("/autopilot/internal/atl-weight-lbs", weight);
  setprop("/autopilot/locks/speed", "speed-with-throttle");
  setprop("/autopilot/settings/target-aoa-deg", (flpextaoa + 0.2));
  setprop("/autopilot/locks/aoa", "aoa-with-speed");

  setprop("/autopilot/settings/target-climb-rate-fps", cvfps);
  setprop("/autopilot/locks/altitude", "vfps-hold");
  interpolate("/autopilot/settings/target-climb-rate-fps", 0, 10);
  
  # Set the A/P Heading lock to nav1-hold.
  setprop("/autopilot/locks/heading", "nav1-hold");

  # Start the main loop.
  atl_loop();
}
#--------------------------------------------------------------------
var atl_loop = func {
  var agl = getprop("/position/altitude-agl-ft");

  if(agl > 400) {
    # Glide Slope phase.
    atl_spddep();
    atl_glideslope();
    atl_aoa();
  } else {
    # Touch Down phase.
    atl_touchdown();
  }

  # Re-schedule the next loop if the Landing function is enabled.
  if(getprop("/autopilot/locks/auto-landing") == "engaged") {
    settimer(atl_loop, 0.1);
  }
}
#--------------------------------------------------------------------
var atl_spddep = func {
  # This script handles speed related actions.
  var appsplowwgtlbs = getprop("/autopilot/settings/approach-spoiler-low-weight-lbs");
  var appspmaxwgtlbs = getprop("/autopilot/settings/approach-spoiler-max-weight-lbs");
  var appaoa =         getprop("/autopilot/settings/approach-aoa-deg");
  var curraskts =      getprop("/velocities/airspeed-kt");
  var atl_weight_lbs = getprop("/autopilot/internal/atl-weight-lbs");
  var grmxextspdkt =   getprop("/autopilot/settings/gear-extend-max-speed-kt");
  var flpmxa =         getprop("/autopilot/settings/flap-extend-aoa-deg");
  var flppos =         getprop("/surface-positions/flap-pos-norm");
  var spdhold =        getprop("/autopilot/locks/speed");
  var tgtaskts =       getprop("/autopilot/settings/target-speed-kt");

  if(curraskts > (tgtaskts + 10)) {
    if(flppos < 0.999) {
      setprop("/controls/flight/spoilers", 1);
    }
  } else {
    if(atl_weight_lbs < appsplowwgtlbs) {
      setprop("/controls/flight/spoilers", 0.857);
    } else {
      if(atl_weight_lbs < appspmaxwgtlbs) {
        setprop("/controls/flight/spoilers", 0.428);
      } else {
        setprop("/controls/flight/spoilers", 0);
      }
    }
  }

  if(flppos < 0.999) {
    setprop("/autopilot/settings/target-aoa-deg", (flpmxa + 1));
  } else {
    interpolate("/autopilot/settings/target-aoa-deg", appaoa, 10);
  }

  # Extend the landing gear
  if(curraskts < grmxextspdkt) {
    setprop("/controls/gear/gear-down", "true");
  }
}
#--------------------------------------------------------------------
var atl_glideslope = func {
  # This script handles glide slope interception.
  if(getprop("/position/altitude-agl-ft") > 300) {
    var gsmnvfps = getprop("/autopilot/settings/glide-slope-min-vfps");
    var gsroc =    getprop("/autopilot/internal/gs-rate-of-climb-filtered[1]");
    var flppos =   getprop("/surface-positions/flap-pos-norm");
    var askt =     getprop("/velocities/airspeed-kt");
    var tgtaskt =  getprop("/autopilot/settings/target-speed-kt");
    var nav1errd = getprop("/autopilot/internal/nav1-heading-error-deg");

    if(flppos > 0.999) {
      if(nav1errd > -80) {
        if(nav1errd < 80) {
          if(gsroc > 0) {
            setprop("/autopilot/settings/target-climb-rate-fps", 0);
          } else {
            if(gsroc < gsmnvfps) {
              setprop("/autopilot/settings/target-climb-rate-fps", gsmnvfps);
            } else {
              setprop("/autopilot/settings/target-climb-rate-fps", gsroc);
            }
          }
        }
      }
    }
  }
}
#--------------------------------------------------------------------
var atl_aoa = func {
  #This script handles AoA dependent actions.
  var curraoa =   getprop("/orientation/alpha-deg");
  var curraskts = getprop("/velocities/airspeed-kt");
  var flpextaoa = getprop("/autopilot/settings/flap-extend-aoa-deg");
  var flpextkts = getprop("/autopilot/settings/flap-extend-max-speed-kts");
  var flpctrl =   getprop("/controls/flight/flaps");

  if(flpctrl < 1) {
    if(curraoa >= flpextaoa) {
      if(curraskts < flpextkts) {
        setprop("/controls/flight/flaps", 1);
      }
    }
  }
}
#--------------------------------------------------------------------
var atl_touchdown = func {
  # Touch Down phase.
  var agl =  getprop("/position/gear-agl-ft");
  var vfps = getprop("/velocities/vertical-speed-fps");

  if(agl < 1) {
    setprop("/controls/gear/brake-left", 0.1);
    setprop("/controls/gear/brake-right", 0.1);
    setprop("/autopilot/settings/steering-heading-deg", -999.9);
    setprop("/autopilot/locks/auto-landing", "disabled");
    setprop("/autopilot/locks/auto-take-off", "enabled");
    setprop("/autopilot/locks/altitude", "");
    setprop("/autopilot/locks/heading", "");
    setprop("/autopilot/settings/target-climb-rate-fps", 0);
    interpolate("/controls/flight/elevator-trim", 0, 10.0);
  } else {
    setprop("/autopilot/locks/heading", "");
    if(agl < 2) {
      setprop("/controls/flight/spoilers", 1);
    }
  }
  if(agl < 4) {
#    setprop("/autopilot/locks/aoa", "");
#    setprop("/autopilot/locks/speed", "Off");
#    setprop("/controls/engines/engine[0]/throttle", 0);
#    setprop("/controls/engines/engine[1]/throttle", 0);
#    setprop("/controls/engines/engine[2]/throttle", 0);
#    setprop("/controls/engines/engine[3]/throttle", 0);
#    setprop("/controls/engines/engine[4]/throttle", 0);
#    setprop("/controls/engines/engine[5]/throttle", 0);
#    setprop("/controls/engines/engine[6]/throttle", 0);
#    setprop("/controls/engines/engine[7]/throttle", 0);
  } else {
    if(agl < 10) {
      if(vfps < -2) {
        setprop("/autopilot/settings/target-climb-rate-fps", -2);
      }
    } else {
      if(agl < 20) {
        if(vfps < -4) {
          setprop("/autopilot/settings/target-climb-rate-fps", -4);
        }
      } else {
        if(agl < 40) {
          setprop("/autopilot/locks/aoa", "");
          setprop("/autopilot/locks/speed", "Off");
          setprop("/controls/engines/engine[0]/throttle", 0);
          setprop("/controls/engines/engine[1]/throttle", 0);
          setprop("/controls/engines/engine[2]/throttle", 0);
          setprop("/controls/engines/engine[3]/throttle", 0);
          setprop("/controls/engines/engine[4]/throttle", 0);
          setprop("/controls/engines/engine[5]/throttle", 0);
          setprop("/controls/engines/engine[6]/throttle", 0);
          setprop("/controls/engines/engine[7]/throttle", 0);
          if(vfps < -6) {
            setprop("/autopilot/settings/target-climb-rate-fps", -6);
          }
        } else {
          if(agl < 80) {
            if(vfps < -10) {
              setprop("/autopilot/settings/target-climb-rate-fps", -10);
            }
          } else {
            if(agl < 160) {
              if(vfps < -10) {
#                setprop("/autopilot/settings/target-climb-rate-fps", -10);
              }
            } else {
              if(agl < 320) {
                if(vfps < -12) {
#                  setprop("/autopilot/settings/target-climb-rate-fps", -12);
                }
              }
            }
          }
        }
      }
    }
  }
}
#--------------------------------------------------------------------
var steering_instrument_update = func {
  # This listener function converts the steering angles from norm to deg
  # and updates the relevent property tree nodes so that the steering instrument
  # can display the current settings for the pilot.
  var str_f_norm = props.globals.getNode("/controls/gear/steering-front-norm", 1);
  var str_r_norm = props.globals.getNode("/controls/gear/steering-rear-norm", 1);
  var str_f_deg =  props.globals.getNode("/controls/gear/steering-front-deg", 1);
  var str_r_deg =  props.globals.getNode("/controls/gear/steering-rear-deg", 1);

  # Convert from norm to deg for the instrument display.
  str_f_deg.setValue(str_f_norm.getValue() * 53);
  str_r_deg.setValue(str_r_norm.getValue() * 53);

  # Schedule the next loop - doesn't need a high update rate.
  settimer(steering_instrument_update, 0.25);
}
#--------------------------------------------------------------------
var yaw_steering = func {
  # This listener function monitors front gear steering inputs and copies them
  # to the rear gear for cross wind landings.
  # Once the speed has dropped below steering-yaw-transition-kt the rear gear
  # is interpolated to center over steering-yaw-transition-sec seconds so that
  # the aircraft can then be steered normally.

  var str_f_norm = cmdarg().getValue();
  var str_r_norm = props.globals.getNode("/controls/gear/steering-rear-norm", 1);
  var str_r_lock = props.globals.getNode("/autopilot/locks/steering-rear", 1);
  var str_t_kt =   props.globals.getNode("/autopilot/settings/steering-yaw-transition-kt", 1);
  var str_t_sec =  props.globals.getNode("/autopilot/settings/steering-yaw-transition-sec", 1);
  var spd =        props.globals.getNode("/velocities/airspeed-kt", 1);

  # Set the appropriate lock states.
  if(spd.getValue() > str_t_kt.getValue()) {
    str_r_lock.setValue("linked");
  } else {
    if(str_r_lock.getValue() != "locked") {
      str_r_lock.setValue("transition");
    }
  }

  # Set the rear steering.
  if(str_r_lock.getValue() == "linked") {
    str_r_norm.setValue(str_f_norm);
  } else {
    if(str_r_lock.getValue() == "transition") {
      str_r_lock.setValue("locked");
      interpolate(str_r_norm, 0, str_t_sec.getValue());
    }
  }
}
#--------------------------------------------------------------------
var toggle_traj_mkr = func {
  if(getprop("/ai/submodels/trajectory-markers") == nil) {
    setprop("/ai/submodels/trajectory-markers", 0);
  }
  if(getprop("/ai/submodels/trajectory-markers") < 1) {
    setprop("/ai/submodels/trajectory-markers", 1);
  } else {
    setprop("/ai/submodels/trajectory-markers", 0);
  }
}
#--------------------------------------------------------------------
var initialise_drop_view_pos = func {
  var eyelatdeg = getprop("/position/latitude-deg");
  var eyelondeg = getprop("/position/longitude-deg");
  var eyealtft =  getprop("/position/altitude-ft") + 20;
  setprop("/sim/view[101]/latitude-deg", eyelatdeg);
  setprop("/sim/view[101]/longitude-deg", eyelondeg);
  setprop("/sim/view[101]/altitude-ft", eyealtft);
}
#--------------------------------------------------------------------
var update_drop_view_pos = func {
  var eyelatdeg = getprop("/position/latitude-deg");
  var eyelondeg = getprop("/position/longitude-deg");
  var eyealtft =  getprop("/position/altitude-ft") + 20;
  interpolate("/sim/view[101]/latitude-deg", eyelatdeg, 5);
  interpolate("/sim/view[101]/longitude-deg", eyelondeg, 5);
  interpolate("/sim/view[101]/altitude-ft", eyealtft, 5);
}
#--------------------------------------------------------------------
var yaw_monitor = func {
  # This function works out the current aircraft yaw angle by comparing
  # /orientation/heading-deg and /instrumentation/gps/indicated-track-true-deg
  # and puts the result in /autopilot/internal/yaw-deg.
  # This is really a stop-gap measure until /orientation/yaw-deg works.

  var hdgdeg = props.globals.getNode("/orientation/heading-deg", 1);
  var gpsdeg = props.globals.getNode("/instrumentation/gps/indicated-track-true-deg", 1);
  var yawdeg = props.globals.getNode("/autopilot/internal/yaw-deg", 1);

  var yawtemp = (gpsdeg.getValue() - hdgdeg.getValue());

  # Check for 360-0 problems.
  if(yawtemp < -180) {
    yawtemp = yawtemp + 360;
  } else {
    if(yawtemp > 180) {
      yawtemp = yawtemp - 360;
    }
  }

  yawdeg.setValue(yawtemp);

  # Schedule the next call.
  settimer(yaw_monitor, 0.1);
}
#--------------------------------------------------------------------
var pitch_hold_monitor = func {
  var pitch_mode = cmdarg().getValue();

  if(pitch_mode == "agl-hold") {
    var current_alt_ft = getprop("/position/altitude-ft");
    var tfa_mode =       getprop("/instrumentation/terrain-radar/settings/mode");
    setprop("/autopilot/settings/target-climb-rate-fps", 0);
    setprop("/autopilot/internal/target-tfa-altitude-ft", current_alt_ft);
    setprop("/autopilot/internal/target-tfa-climb-rate-fps", 0);
    setprop("/instrumentation/terrain-radar/settings/state", "on");
    if(tfa_mode == "extend") {
      settimer(tfa_radar_extend_mode_loop, 0.1);
    } else {
      if(tfa_mode == "continuous") {
        settimer(tfa_radar_continuous_mode_loop, 0.1);
      }
    }
  } else {
    setprop("/instrumentation/terrain-radar/settings/state", "off");
    setprop("/instrumentation/terrain-radar/hi-elev/alt-ft", -9999.9);
    setprop("/instrumentation/terrain-radar/hi-elev/lat-deg", -9999.9);
    setprop("/instrumentation/terrain-radar/hi-elev/lon-deg", -9999.9);
    setprop("/instrumentation/terrain-radar/hi-elev/dist-m", -9999.9);
    setprop("/autopilot/internal/target-tfa-altitude-ft", -9999.9);
    setprop("/autopilot/internal/target-tfa-climb-rate-fps", 0);
  }
}
#--------------------------------------------------------------------
var tfa_high_alt_monitor = func {
  collision_monitor();
  hi_elev_markers();
}
#--------------------------------------------------------------------
var hi_elev_markers = func {
  marker_status =    props.globals.getNode("/instrumentation/terrain-radar/settings/hi-elev-markers", 1);

  if(marker_status.getValue() == "on") {
    var hi_elev_lat =  props.globals.getNode("/instrumentation/terrain-radar/hi-elev/lat-deg", 1);
    var hi_elev_lon =  props.globals.getNode("/instrumentation/terrain-radar/hi-elev/lon-deg", 1);
    if(hi_elev_lat.getValue() > -180) {
      geo.put_model("Aircraft/B-52F/Models/Elevation-marker.ac", hi_elev_lat.getValue(), hi_elev_lon.getValue());
    }
  }
}
#--------------------------------------------------------------------
var collision_monitor = func {
  var hi_alt_ft =      props.globals.getNode("/instrumentation/terrain-radar/hi-elev/alt-ft", 1);
  var hi_elev_dist_m = props.globals.getNode("/instrumentation/terrain-radar/hi-elev/dist-m", 1);
  var curr_gspd_kt =   props.globals.getNode("/velocities/groundspeed-kt", 1);
  var curr_alt_ft =    props.globals.getNode("/position/altitude-ft", 1);

  var max_climb_rate =   props.globals.getNode("/instrumentation/terrain-radar/settings/max-climb-rate-fps", 1);
  var warn_climb_rate =  props.globals.getNode("/instrumentation/terrain-radar/settings/warn-climb-rate-fps", 1);
  var collision_status = props.globals.getNode("/instrumentation/terrain-radar/hi-elev/collision-status", 1);

  # Convert distance from m into feet.
  var hi_elev_dist_ft = (hi_elev_dist_m.getValue() * 3.28);

  # Convert groundspeed from kts into feet per second
  var curr_gspd_fps = (curr_gspd_kt.getValue() * 1.6878092);

  var time = hi_elev_dist_ft / curr_gspd_fps;
  if(time > 2) {  # Do this to stop false positives from very close new hi-elevs
    if((time * warn_climb_rate.getValue()) < (hi_alt_ft.getValue() - curr_alt_ft.getValue())) {
      if((time * max_climb_rate.getValue()) < (hi_alt_ft.getValue() - curr_alt_ft.getValue())) {
        collision_status.setValue("collision");
      } else {
        collision_status.setValue("warning");
      }
    } else {
      collision_status.setValue("");
    }
  }
}
#--------------------------------------------------------------------
var tfa_radar_continuous_mode_loop = func {
  # This function checks to see if we are still approaching the high elevation
  # or whether we have passed it.
  # If we are still approaching it we leave the current high elevation alone.
  # If we have passed the current high elevation we reset the current high elevation.

  var radar_state =  props.globals.getNode("/instrumentation/terrain-radar/settings/state");
  var radar_mode =   props.globals.getNode("/instrumentation/terrain-radar/settings/mode");
  var hi_elev_alt =  props.globals.getNode("/instrumentation/terrain-radar/hi-elev/alt-ft", 1);
  var hi_elev_lat =  props.globals.getNode("/instrumentation/terrain-radar/hi-elev/lat-deg", 1);
  var hi_elev_lon =  props.globals.getNode("/instrumentation/terrain-radar/hi-elev/lon-deg", 1);
  var hi_elev_dist = props.globals.getNode("/instrumentation/terrain-radar/hi-elev/dist-m", 1);

  # Set up a geo container for the stored high elevation location and validate it.
  var stor_coord = geo.Coord.new().set_latlon(hi_elev_lat.getValue(), hi_elev_lon.getValue());
  if(stor_coord.is_defined()) {
    # Get the current distance to the stored high elevation location.
    var curr_dist = geo.aircraft_position().distance_to(stor_coord);
  } else {
    # We've got a bad coord stored - zero it and re-scan.
    var curr_dist = 0;
  }

  # Test to see if we are still approaching the high elevation.
  if(curr_dist < hi_elev_dist.getValue()) {
    # YES - we are still approaching the high elevation.
    # Update the stored distance.
    hi_elev_dist.setDoubleValue(curr_dist);
  } else {
    # NO - we have passed the high elevation and need to reset.
    hi_elev_alt.setDoubleValue(-9999.9);
    hi_elev_lat.setDoubleValue(-9999.9);
    hi_elev_lon.setDoubleValue(-9999.9);
    hi_elev_dist.setDoubleValue(-9999.9);
  }
  tfa_radar_continuous_mode_full_scan();

  # Check that tfa is still engaged and re-schedule the next loop.
  # Also check that the mode hasn't changed.
  if(radar_state.getValue() == "on") {
    if(radar_mode.getValue() == "continuous") {
      settimer(tfa_radar_continuous_mode_loop, 0.1);
    } else {
      if(radar_mode.getValue() == "extend") {
        settimer(tfa_radar_extend_mode_loop, 0.1);
      }
    }
  }
}
#--------------------------------------------------------------------
var tfa_radar_extend_mode_loop = func {
  # This function checks to see if we are still approaching the high elevation
  # or whether we have passed it.
  # If we are still approaching it we perform an extend scan to check for a
  # higher elevation after the current high elevation.
  # If we have passed the current high elevation we do a full scan ahead to
  # find a new high elevation.

  var radar_state =  props.globals.getNode("/instrumentation/terrain-radar/settings/state");
  var radar_mode =   props.globals.getNode("/instrumentation/terrain-radar/settings/mode");
  var hi_elev_alt =  props.globals.getNode("/instrumentation/terrain-radar/hi-elev/alt-ft", 1);
  var hi_elev_lat =  props.globals.getNode("/instrumentation/terrain-radar/hi-elev/lat-deg", 1);
  var hi_elev_lon =  props.globals.getNode("/instrumentation/terrain-radar/hi-elev/lon-deg", 1);
  var hi_elev_dist = props.globals.getNode("/instrumentation/terrain-radar/hi-elev/dist-m", 1);

  # Set up a geo container for the stored high elevation location and validate it.
  var stor_coord = geo.Coord.new().set_latlon(hi_elev_lat.getValue(), hi_elev_lon.getValue());

  if(stor_coord.is_defined()) {
    # Get the current distance to the stored high elevation location.
    var curr_dist = geo.aircraft_position().distance_to(stor_coord);
  } else {
    # We've got a bad coord stored - zero it and re-scan.
    var curr_dist = 0;
  }

  # Test to see if we are still approaching the high elevation.
  if(curr_dist < hi_elev_dist.getValue()) {
    # YES - we are still approaching the high elevation.
    # Update the stored distance.
    hi_elev_dist.setDoubleValue(curr_dist);
    # Perfom an extend scan.
    tfa_radar_extend_mode_extend_scan();
  } else {
    # NO - we have passed the high elevation and need to perform a full scan.
    tfa_radar_extend_mode_full_scan();
  }

  # Check that tfa is still engaged and re-schedule the next loop.
  # Also check that the mode hasn't changed.
  if(radar_state.getValue() == "on") {
    if(radar_mode.getValue() == "continuous") {
      settimer(tfa_radar_continuous_mode_loop, 0.1);
    } else {
      if(radar_mode.getValue() == "extend") {
        settimer(tfa_radar_extend_mode_loop, 0.1);
      }
    }
  }
}
#--------------------------------------------------------------------
var tfa_radar_continuous_mode_full_scan = func {
  # This function scans the terrain ahead of the aircraft in steps and identifies
  # the highest ground elevation.  If it is higher than the stored high elevation
  # the stored high elevation is updated.

  var hi_elev_ft =   props.globals.getNode("/instrumentation/terrain-radar/hi-elev/alt-ft", 1);
  var hi_elev_lat =  props.globals.getNode("/instrumentation/terrain-radar/hi-elev/lat-deg", 1);
  var hi_elev_lon =  props.globals.getNode("/instrumentation/terrain-radar/hi-elev/lon-deg", 1);
  var hi_elev_dist = props.globals.getNode("/instrumentation/terrain-radar/hi-elev/dist-m", 1);
  var tfa_range =    props.globals.getNode("/instrumentation/terrain-radar/settings/range-m", 1);
  var tfa_step =     props.globals.getNode("/instrumentation/terrain-radar/settings/step-m", 1);
  var tgt_tfa_ft =   props.globals.getNode("/autopilot/internal/target-tfa-altitude-ft", 1);
  var tgt_agl_ft =   props.globals.getNode("/autopilot/settings/target-agl-ft", 1);
  var hdgdeg =       props.globals.getNode("/instrumentation/gps/indicated-track-true-deg", 1);
  var test =         -9999;

  for (dist = tfa_step.getValue(); tfa_range.getValue(); dist += tfa_step.getValue()) {
    var geo_coord = geo.aircraft_position().apply_course_distance(hdgdeg.getValue(), dist);
    if(geo_coord.is_defined()) {
      var geo_elev_m = geo.elevation(geo_coord.lat(), geo_coord.lon());

      # geo.elevation sometimes seems to return a bad value so test for it.
      if(geo_elev_m < -999) {
        geo_elev_m = 0;
      }

      # pick the highest point on the scan and store it (the test is in m but 
      # needs to be stored in ft)
      if(geo_elev_m > test) {
        test = geo_elev_m;
        var geo_elev_ft = geo_elev_m * 3.28;
        if(geo_elev_ft > hi_elev_ft.getValue()) {
          hi_elev_ft.setDoubleValue(geo_elev_ft);
          hi_elev_lat.setDoubleValue(geo_coord.lat());
          hi_elev_lon.setDoubleValue(geo_coord.lon());
          hi_elev_dist.setDoubleValue(dist);
          tgt_tfa_ft.setDoubleValue(geo_elev_ft + tgt_agl_ft.getValue());
        }
      }
    }
    if(dist >= tfa_range.getValue()) {
      break;
    }
  }
}
#--------------------------------------------------------------------
var tfa_radar_extend_mode_full_scan = func {
  # This function scans the terrain ahead of the aircraft in steps and identifies
  # the highest ground elevation.  It is only called when the current high
  # elevation point has been passed and a new high elevation is needed when in
  # extend mode but is called every time when in continuous mode.

  var hi_elev_ft =   props.globals.getNode("/instrumentation/terrain-radar/hi-elev/alt-ft", 1);
  var hi_elev_lat =  props.globals.getNode("/instrumentation/terrain-radar/hi-elev/lat-deg", 1);
  var hi_elev_lon =  props.globals.getNode("/instrumentation/terrain-radar/hi-elev/lon-deg", 1);
  var hi_elev_dist = props.globals.getNode("/instrumentation/terrain-radar/hi-elev/dist-m", 1);
  var tfa_range =    props.globals.getNode("/instrumentation/terrain-radar/settings/range-m", 1);
  var tfa_step =     props.globals.getNode("/instrumentation/terrain-radar/settings/step-m", 1);
  var tgt_tfa_ft =   props.globals.getNode("/autopilot/internal/target-tfa-altitude-ft", 1);
  var tgt_agl_ft =   props.globals.getNode("/autopilot/settings/target-agl-ft", 1);
  var hdgdeg =       props.globals.getNode("/instrumentation/gps/indicated-track-true-deg", 1);
  var test =         -9999;

  for (dist = tfa_step.getValue(); tfa_range.getValue(); dist += tfa_step.getValue()) {
    var geo_coord = geo.aircraft_position().apply_course_distance(hdgdeg.getValue(), dist);
    if(geo_coord.is_defined()) {
      var geo_elev_m = geo.elevation(geo_coord.lat(), geo_coord.lon());

      # geo.elevation sometimes seems to return a bad value so test for it.
      if(geo_elev_m < -999) {
        geo_elev_m = 0;
      }

      # pick the highest point on the scan and store it (the test is in m but 
      # needs to be stored in ft)
      if(geo_elev_m > test) {
        test = geo_elev_m;
        var geo_elev_ft = geo_elev_m * 3.28;
        hi_elev_ft.setDoubleValue(geo_elev_ft);
        hi_elev_lat.setDoubleValue(geo_coord.lat());
        hi_elev_lon.setDoubleValue(geo_coord.lon());
        hi_elev_dist.setDoubleValue(dist);
        tgt_tfa_ft.setDoubleValue(geo_elev_ft + tgt_agl_ft.getValue());
      }
    }
    if(dist >= tfa_range.getValue()) {
      break;
    }
  }
}
#--------------------------------------------------------------------
var tfa_radar_extend_mode_extend_scan = func {
  # This function scans the terrain at the full range ahead of the aircraft to
  # check for a new high elevation after tfa_radar_full_scan has identified the
  # initial high elevation. If a new higher elevation is found it updates the
  # current stored high elevation

  var hi_elev_ft =   props.globals.getNode("/instrumentation/terrain-radar/hi-elev/alt-ft", 1);
  var hi_elev_lat =  props.globals.getNode("/instrumentation/terrain-radar/hi-elev/lat-deg", 1);
  var hi_elev_lon =  props.globals.getNode("/instrumentation/terrain-radar/hi-elev/lon-deg", 1);
  var hi_elev_dist = props.globals.getNode("/instrumentation/terrain-radar/hi-elev/dist-m", 1);
  var tfa_range =    props.globals.getNode("/instrumentation/terrain-radar/settings/range-m", 1);
  var tgt_tfa_ft =   props.globals.getNode("/autopilot/internal/target-tfa-altitude-ft", 1);
  var tgt_agl_ft =   props.globals.getNode("/autopilot/settings/target-agl-ft", 1);
  var hdgdeg =       props.globals.getNode("/instrumentation/gps/indicated-track-true-deg", 1);
  var geo_coord =    geo.aircraft_position().apply_course_distance(hdgdeg.getValue(), tfa_range.getValue());

  if(geo_coord.is_defined()) {
    var geo_elev_m = geo.elevation(geo_coord.lat(), geo_coord.lon());
    # Need to test in ft
    var geo_elev_ft = geo_elev_m * 3.28;
    if(geo_elev_ft > hi_elev_ft.getValue()) {
      # New high elevation.
      hi_elev_ft.setDoubleValue(geo_elev_ft);
      hi_elev_lat.setDoubleValue(geo_coord.lat());
      hi_elev_lon.setDoubleValue(geo_coord.lon());
      hi_elev_dist.setDoubleValue(tfa_range.getValue());
      tgt_tfa_ft.setDoubleValue(geo_elev_ft + tgt_agl_ft.getValue());
    }
  }
}
#--------------------------------------------------------------------
