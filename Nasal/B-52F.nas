autotakeoff = func {
  if(getprop("/autopilot/locks/auto-take-off") == "enabled") {
    ato_initiation();
  }
}
#--------------------------------------------------------------------
ato_initiation = func {
  # Check that the steering-heading-deg has been reset
  # (< -999), that the a/c is on the ground and that the flaps
  # have been deployed.  If so, auto-takeoff is started.
  if(getprop("/autopilot/settings/steering-heading-deg") < -999) {
    if(getprop("/position/gear-agl-ft") < 0.10) {
      if(getprop("surface-positions/left-flap-pos-norm") > 0.999) {
        if(getprop("surface-positions/right-flap-pos-norm") > 0.999) {
          hdgdeg = getprop("/orientation/heading-deg");
          toptdeg = getprop("/autopilot/settings/take-off-pitch-deg");
          setprop("/autopilot/settings/steering-heading-deg", hdgdeg);
          setprop("/autopilot/settings/true-heading-deg", hdgdeg);
          setprop("/autopilot/settings/target-aoa-deg", 0);
          setprop("/autopilot/settings/target-climb-rate-fps", 0);
          setprop("/autopilot/settings/target-pitch-deg", toptdeg);
          setprop("/autopilot/settings/target-roll-deg", 0);
          setprop("/autopilot/settings/target-speed-kt", 310);
          setprop("/autopilot/locks/altitude", "take-off");
          setprop("/autopilot/locks/speed", "speed-with-throttle");
          setprop("/autopilot/locks/heading", "wing-leveler");
          setprop("/autopilot/locks/rudder-control", "rudder-hold");
          setprop("/autopilot/locks/take-off-phase", "take-off");
          setprop("/autopilot/locks/auto-take-off", "engaged");
          setprop("/autopilot/locks/steering-front", "ground-roll");
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
ato_loop = func {
  if(getprop("/autopilot/locks/auto-take-off") == "engaged") {
    ato_heading();
    ato_mode();
    ato_winject();
    ato_spddep();
    settimer(ato_loop, 0.2);
  }
}
#--------------------------------------------------------------------
ato_heading = func {
  agl = getprop("/position/altitude-agl-ft");
  if(agl > 50) {
    tophase = getprop("/autopilot/locks/take-off-phase");
    if(tophase == "take-off") {
      coiptdeg = getprop("/autopilot/settings/climb-out-initial-pitch-deg");
      interpolate("/autopilot/settings/target-pitch-deg", coiptdeg, 4);
      setprop("/controls/gear/gear-down", "false");
      setprop("/autopilot/locks/rudder-control", "reset");
      setprop("/autopilot/locks/steering-front", "reset");
      setprop("/autopilot/locks/take-off-phase", "climb-out");
      interpolate("/controls/flight/rudder", 0, 10);
    }
  }
}
#--------------------------------------------------------------------
ato_mode = func {
  agl = getprop("/position/altitude-agl-ft");
  rdrctrl = getprop("/autopilot/locks/rudder-control");
  if(agl > 50) {
    tophase = getprop("/autopilot/locks/take-off-phase");
    if(tophase == "take-off") {
      coiptdeg = getprop("/autopilot/settings/climb-out-initial-pitch-deg");
      interpolate("/autopilot/settings/target-pitch-deg", coiptdeg, 4);
      setprop("/controls/gear/gear-down", "false");
      setprop("/autopilot/locks/take-off-phase", "climb-out");
      if(rdrctrl != "") {
        setprop("/autopilot/locks/rudder-control", "");
        interpolate("/controls/flight/rudder", 0, 10);
      }
    }
  }
}
#--------------------------------------------------------------------
ato_winject = func {
  # This script controls the water injection spoof (reheat)
  airspeed = getprop("/velocities/airspeed-kt");
  if(airspeed > 0) {
    if(airspeed < 220) {
      setprop("/controls/engines/engine[0]/afterburner", 1);
    } else {
      setprop("/controls/engines/engine[0]/afterburner", 0);
    }
  }
}
#--------------------------------------------------------------------
ato_spddep = func {
  # This script controls speed dependent actions.
  airspeed = getprop("/velocities/airspeed-kt");
  flpretkt = getprop("/autopilot/settings/flap-retract-speed-kt");
  if(airspeed < 40) {
    # Do nothing until we're moving (allow for high windspeed)
  } else {
    if(airspeed < flpretkt) {
      setprop("/autopilot/locks/steering-front", "ground-roll");
    } else {
      if(airspeed < 260) {
        setprop("/autopilot/locks/steering-front", "reset");
        setprop("/autopilot/locks/steering-front", "");
        setprop("/controls/gear/steer-front-norm", 0);
        setprop("/controls/flight/flaps", 0);
        cofptdeg = getprop("/autopilot/settings/climb-out-final-pitch-deg");
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
  ccrfps = getprop("/velocities/vertical-speed-fps");
  setprop("/autopilot/settings/target-climb-rate-fps", ccrfps);
}
#--------------------------------------------------------------------
autoland = func {
  if(getprop("/autopilot/locks/auto-landing") == "enabled") {
    setprop("/autopilot/locks/auto-landing", "engaged");
    atl_initiation();
  }
}
#--------------------------------------------------------------------
atl_initiation = func {
  cvfps = getprop("/velocities/vertical-speed-fps");
  flpextaoa = getprop("/autopilot/settings/flap-extend-aoa-deg");
  weight = getprop("/yasim/gross-weight-lbs");

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
atl_loop = func {
  agl = getprop("/position/altitude-agl-ft");

  if(agl > 400) {
    # Glide Slope phase.
    atl_spddep();
    atl_glideslope();
    atl_aoa();
  } else {
    # Touch Down phase.
    atl_touchdown();
#    atl_steering();
  }

  # Re-schedule the next loop if the Landing function is enabled.
  if(getprop("/autopilot/locks/auto-landing") == "engaged") {
    settimer(atl_loop, 0.1);
  }
}
#--------------------------------------------------------------------
atl_spddep = func {
  # This script handles speed related actions.
  appsplowwgtlbs = getprop("/autopilot/settings/approach-spoiler-low-weight-lbs");
  appspmaxwgtlbs = getprop("/autopilot/settings/approach-spoiler-max-weight-lbs");
  appaoa = getprop("/autopilot/settings/approach-aoa-deg");
  curraskts = getprop("/velocities/airspeed-kt");
  atl_weight_lbs = getprop("/autopilot/internal/atl-weight-lbs");
  grmxextspdkt = getprop("/autopilot/settings/gear-extend-max-speed-kt");
  flpmxa = getprop("/autopilot/settings/flap-extend-aoa-deg");
  flppos = getprop("/surface-positions/flap-pos-norm");
  spdhold = getprop("/autopilot/locks/speed");
  tgtaskts = getprop("/autopilot/settings/target-speed-kt");

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
atl_glideslope = func {
  # This script handles glide slope interception.
  if(getprop("/position/altitude-agl-ft") > 300) {
    gsmnvfps = getprop("/autopilot/settings/glide-slope-min-vfps");
    gsroc = getprop("/autopilot/internal/gs-rate-of-climb-filtered[1]");
    flppos = getprop("/surface-positions/flap-pos-norm");
    askt = getprop("/velocities/airspeed-kt");
    tgtaskt = getprop("/autopilot/settings/target-speed-kt");
    nav1errd = getprop("/autopilot/internal/nav1-heading-error-deg");

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
atl_aoa = func {
  #This script handles AoA dependent actions.
  curraoa = getprop("/orientation/alpha-deg");
  curraskts = getprop("/velocities/airspeed-kt");
  flpextaoa = getprop("/autopilot/settings/flap-extend-aoa-deg");
  flpextkts = getprop("/autopilot/settings/flap-extend-max-speed-kts");
  flpctrl = getprop("/controls/flight/flaps");

  if(flpctrl < 1) {
    if(curraoa >= flpextaoa) {
      if(curraskts < flpextkts) {
        setprop("/controls/flight/flaps", 1);
      }
    }
  }
}
#--------------------------------------------------------------------
atl_touchdown = func {
  # Touch Down phase.
  agl = getprop("/position/gear-agl-ft");
  vfps = getprop("/velocities/vertical-speed-fps");

  if(agl < 1) {
    setprop("/controls/gear/brake-left", 0.1);
    setprop("/controls/gear/brake-right", 0.1);
    setprop("/autopilot/settings/steering-heading-deg", -999.9);
    setprop("/autopilot/locks/auto-landing", "disabled");
    setprop("/autopilot/locks/auto-take-off", "enabled");
    setprop("/autopilot/locks/altitude", "");
    setprop("/autopilot/locks/heading", "");
    setprop("/autopilot/locks/steering-front", "");
    setprop("/autopilot/settings/target-climb-rate-fps", 0);
    interpolate("/controls/flight/elevator-trim", 0, 10.0);
  } else {
    setprop("/autopilot/locks/steering-front", "auto-yaw");
    setprop("/autopilot/locks/heading", "wing-leveler");
    if(agl < 2) {
      setprop("/autopilot/locks/heading", "");
      setprop("/controls/flight/spoilers", 1);
    }
  }
  if(agl < 4) {
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
          if(vfps < -6) {
            setprop("/autopilot/settings/target-climb-rate-fps", -6);
          }
        } else {
          if(agl < 80) {
            if(vfps < -8) {
              setprop("/autopilot/settings/target-climb-rate-fps", -8);
            }
          } else {
            if(agl < 160) {
              if(vfps < -10) {
                setprop("/autopilot/settings/target-climb-rate-fps", -10);
              }
            } else {
              if(agl < 320) {
                if(vfps < -12) {
                  setprop("/autopilot/settings/target-climb-rate-fps", -12);
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
#atl_steering = func {
#  gaglft = getprop("/position/gear-agl-ft");

#  if(gaglft > 0.001) {
#    setprop("/autopilot/locks/steering-front", "auto-yaw");
#  } else {
#    setprop("/autopilot/locks/steering-front", "");
#  }
#}
#--------------------------------------------------------------------
steering_norm_to_deg = func {
  # This listener script provides a steering-deg node for display to
  # the pilot so that the front gear steering can be aligned, with
  # reference to the yaw, for cross-wind landings.  The rear gear
  # steering is handled automatically so that the pilot doesn't have
  # to try to control two independent sets of steering
  # simultaneously.
  steering_front_norm = getprop("/controls/gear/steer-front-norm");
  steering_front_deg = steering_front_norm * 53;
  steering_rear_norm = getprop("/controls/gear/steer-rear-norm");
  steering_rear_deg = steering_rear_norm * 53;
  setprop("/instrumentation/steering/steering-front-deg", steering_front_deg);
  setprop("/instrumentation/steering/steering-rear-deg", steering_rear_deg);
}
#--------------------------------------------------------------------
auto_steering = func {
  # This listener script controls automatic gear steering.
  
  gear_agl_ft = getprop("/position/gear-agl-ft");
  yaw_deg = getprop("/orientation/side-slip-deg");
  steer_auto_transition_sec = getprop("/autopilot/settings/steering-auto-transition-sec");
  front_steering_lock = getprop("/autopilot/locks/steering-front");
  rear_steering_lock = getprop("/autopilot/locks/steering-rear");
#  vertical_speed_fps = getprop("/velocities/vertical-speed-fps");

  if(front_steering_lock == "auto-yaw") {
    str_fr_norm = -1 * (yaw_deg / 53);
    setprop("/controls/gear/steer-front-norm", str_fr_norm);
  } else {
    if(front_steering_lock == "auto-transition") {
      setprop("/autopilot/locks/steering-front", "");
      interpolate("/controls/gear/steer-front-norm", 0, steer_auto_transition_sec);
    } else {
      if(front_steering_lock == "reset") {
        setprop("/controls/gear/steer-front-norm", 0);
      }
    }
  }

  if(gear_agl_ft > 400) {
    if(rear_steering_lock != "locked") {
      setprop("/autopilot/locks/steering-rear", "reset");
    }
  } else {
    if(gear_agl_ft > 0.0001) {
      setprop("/autopilot/locks/steering-rear", "auto-yaw");
    } else {
      if(rear_steering_lock != "locked") {
        setprop("/autopilot/locks/steering-rear", "auto-transition");
      }
    }
  }

  if(rear_steering_lock == "auto-yaw") {
    str_r_norm = -1 * (yaw_deg / 53);
    setprop("/controls/gear/steer-rear-norm", str_r_norm);
  } else {
    if(rear_steering_lock == "auto-transition") {
      setprop("/autopilot/locks/steering-rear", "locked");
      interpolate("/controls/gear/steer-rear-norm", 0, steer_auto_transition_sec);
    } else {
      if(rear_steering_lock == "reset") {
        setprop("/autopilot/locks/steering-rear", "locked");
        setprop("/controls/gear/steer-rear-norm", 0);
      }
    }
  }
}
#--------------------------------------------------------------------
toggle_traj_mkr = func {
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
initialise_drop_view_pos = func {
  eyelatdeg = getprop("/position/latitude-deg");
  eyelondeg = getprop("/position/longitude-deg");
  eyealtft = getprop("/position/altitude-ft") + 20;
  setprop("/sim/view[7]/latitude-deg", eyelatdeg);
  setprop("/sim/view[7]/longitude-deg", eyelondeg);
  setprop("/sim/view[7]/altitude-ft", eyealtft);
}
#--------------------------------------------------------------------
update_drop_view_pos = func {
  eyelatdeg = getprop("/position/latitude-deg");
  eyelondeg = getprop("/position/longitude-deg");
  eyealtft = getprop("/position/altitude-ft") + 20;
  interpolate("/sim/view[7]/latitude-deg", eyelatdeg, 5);
  interpolate("/sim/view[7]/longitude-deg", eyelondeg, 5);
  interpolate("/sim/view[7]/altitude-ft", eyealtft, 5);
}
#--------------------------------------------------------------------
start_up = func {
  settimer(initialise_drop_view_pos, 5);
  setlistener("/controls/gear/steer-front-norm", steering_norm_to_deg);
  setlistener("/autopilot/internal/side-slip-deg-filtered", auto_steering);
#  setlistener("/autopilot/locks/steering-rear", auto_steering);
}
#--------------------------------------------------------------------
