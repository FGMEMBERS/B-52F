autotakeoff = func {
  if(getprop("/autopilot/locks/auto-take-off") == "enabled") {
    ato_initiation();
  }
}
#--------------------------------------------------------------------
ato_initiation = func {
  # Check that the ground-roll-heading has been reset
  # (< -999), that the a/c is on the ground and that the flaps
  # have been deployed.  If so, auto-takeoff is started.
  if(getprop("/autopilot/settings/ground-roll-heading-deg") < -999) {
    if(getprop("/position/gear-agl-ft") < 0.10) {
      if(getprop("surface-positions/left-flap-pos-norm") > 0.999) {
        if(getprop("surface-positions/right-flap-pos-norm") > 0.999) {
          hdgdeg = getprop("/orientation/heading-deg");
          toptdeg = getprop("/autopilot/settings/take-off-pitch-deg");
          setprop("/autopilot/settings/ground-roll-heading-deg", hdgdeg);
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
    ato_mode();
    ato_winject();
    ato_spddep();
    settimer(ato_loop, 0.2);
  }
}
#--------------------------------------------------------------------
ato_mode = func {
  agl = getprop("/position/altitude-agl-ft");
  if(agl > 50) {
    tophase = getprop("/autopilot/locks/take-off-phase");
    if(tophase == "take-off") {
      coiptdeg = getprop("/autopilot/settings/climb-out-initial-pitch-deg");
      interpolate("/autopilot/settings/target-pitch-deg", coiptdeg, 4);
      setprop("/controls/gear/gear-down", "false");
      setprop("/autopilot/locks/rudder-control", "reset");
      setprop("/autopilot/locks/take-off-phase", "climb-out");
      interpolate("/controls/flight/rudder", 0, 10);
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
  if(airspeed < flpretkt) {
    # Do not do anything until airspeed > flap retraction speed kt
  } else {
    if(airspeed < 260) {
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
  currweightlbs = getprop("/yasim/gross-weight-lbs");
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
    if(currweightlbs < appsplowwgtlbs) {
      setprop("/controls/flight/spoilers", 0.857);
    } else {
      if(currweightlbs < appspmaxwgtlbs) {
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
    setprop("/autopilot/settings/ground-roll-heading-deg", -999.9);
    setprop("/autopilot/locks/auto-landing", "disabled");
    setprop("/autopilot/locks/auto-take-off", "enabled");
    setprop("/autopilot/locks/altitude", "Off");
    setprop("/autopilot/settings/target-climb-rate-fps", 0);
    interpolate("/controls/flight/elevator-trim", 0, 10.0);
  } else {
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
              } else {
                setprop("/autopilot/locks/heading", "");
              }
            }
          }
        }
      }
    }
  }
}
#--------------------------------------------------------------------
toggle_traj_mkr = func {
  if(getprop("ai/submodels/trajectory-markers") < 1) {
    setprop("ai/submodels/trajectory-markers", 1);
  } else {
    setprop("ai/submodels/trajectory-markers", 0);
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
}
#--------------------------------------------------------------------
