autotakeoff = func {
  ato_start();      # Initiation stuff.
  ato_mode();       # Take-off/Climb-out mode handler.
  ato_winject();    # Water injection control (reheat spoof).
  ato_spddep();     # Speed dependent actions.

  # Re-schedule the next loop if the Take-Off function is enabled.
  if(getprop("/autopilot/locks/auto-take-off") != "enabled") {
    print("Auto Take-Off disabled");
  } else {
    settimer(autotakeoff, 0.2);
  }
}
#--------------------------------------------------------------------
ato_start_takeoff = func {
  # Check that the ground-roll-heading has been reset
  # (< -999), that the a/c is on the ground and that the flaps
  # have been deployed.  If so, auto-takeoff is started.
  # Note: The flaps have to be deployed manually.
  if(getprop("/autopilot/settings/ground-roll-heading-deg") < -999) {
    if(getprop("/position/altitude-agl-ft") < 0.01) {
      if(getprop("surface-positions/left-flap-pos-norm") > 0.999) {
        if(getprop("surface-positions/right-flap-pos-norm") > 0.999) {
          hdgdeg = getprop("/orientation/heading-deg");
          setprop("/autopilot/settings/ground-roll-heading-deg", hdgdeg);
          setprop("/autopilot/settings/true-heading-deg", hdgdeg);
          setprop("/autopilot/settings/target-AoA-deg", 0);
          setprop("/autopilot/settings/target-speed-kt", 310);
          setprop("/autopilot/settings/climb-out-pitch-deg", 0.0);
          setprop("/autopilot/locks/altitude", "ground-roll");
          setprop("/autopilot/locks/speed", "speed-with-throttle");
          setprop("/autopilot/locks/heading", "wing-leveler");
          # Start the main loop
          settimer(ato_takeoff_loop, 0.2);
        }
      }
    }
  }
}
#--------------------------------------------------------------------
ato_takeoff_loop = func {
  ato_mode();
  ato_winject();
  ato_spddep();
  # Check whether to run the loop again
  if(getprop("surface-positions/left-flap-pos-norm") < 0.001) {
    if(getprop("surface-positions/right-flap-pos-norm") < 0.001) {
      ato_finish();
    } else {
      settimer(ato_takeoff_loop, 0.2);
    }
  }
}
#--------------------------------------------------------------------
ato_finish = func {
  setprop("/autopilot/locks/heading", "true-heading-hold");
  setprop("/autopilot/locks/speed", "mach-with-throttle");
  setprop("/autopilot/locks/altitude", "altitude-hold");
  setprop("/autopilot/locks/auto-take-off", "disabled");
  setprop("/autopilot/locks/auto-landing", "enabled");
}
#--------------------------------------------------------------------
ato_start = func {
  # Check that the ground-roll-heading has been reset
  # (< -999), that the a/c is on the ground and that the flaps
  # have been deployed.  If so, auto-takeoff is started.
  # Note: The flaps have to be deployed manually.
  if(getprop("/autopilot/settings/ground-roll-heading-deg") < -999) {
    if(getprop("/position/altitude-agl-ft") < 0.01) {
      if(getprop("surface-positions/left-flap-pos-norm") > 0.999) {
        if(getprop("surface-positions/right-flap-pos-norm") > 0.999) {
          hdgdeg = getprop("/orientation/heading-deg");
          setprop("/autopilot/settings/ground-roll-heading-deg", hdgdeg);
          setprop("/autopilot/settings/true-heading-deg", hdgdeg);
          setprop("/autopilot/settings/target-AoA-deg", 0);
          toptdeg = getprop("/autopilot/settings/take-off-pitch-deg");
          setprop("/autopilot/settings/target-pitch-deg", toptdeg);
          setprop("/autopilot/settings/target-speed-kt", 310);
          setprop("/autopilot/locks/altitude", "take-off");
          setprop("/autopilot/locks/speed", "speed-with-throttle");
          setprop("/autopilot/locks/heading", "wing-leveler");
          setprop("/autopilot/locks/rudder-control", "rudder-hold");
          setprop("/autopilot/locks/take-off-phase", "take-off");
        }
      }
    }
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
          setprop("/autopilot/locks/speed", "mach-with-throttle");
          setprop("/autopilot/locks/altitude", "altitude-hold");
          setprop("/autopilot/locks/auto-take-off", "disabled");
          setprop("/autopilot/locks/auto-landing", "enabled");
        }
      }
    }
  }
}
#--------------------------------------------------------------------
autoland = func {
  agl = getprop("/position/altitude-agl-ft");
  
  if(agl > 200) {
    # Glide Slope phase.
    atl_heading();
    atl_spddep();
    atl_glideslope();
    atl_aoa();
    
  } else {
    # Touch Down phase.
    atl_touchdown();
  }

  # Re-schedule the next loop if the Landing function is enabled.
  if(getprop("/autopilot/locks/auto-landing") != "enabled") {
    print("Auto Landing disabled");
  } else {
    settimer(autoland, 0.2);
  }
}
#--------------------------------------------------------------------
atl_spddep = func {
  # This script handles speed related actions.
  if(getprop("/autopilot/locks/speed") != "speed-with-throttle") {
    setprop("/autopilot/locks/speed", "speed-with-throttle");
  }
  airspeed = getprop("/velocities/airspeed-kt");
  if(getprop("/autopilot/settings/target-speed-kt") > 170) {
    setprop("/controls/flight/spoilers", 0.57);
    setprop("/autopilot/settings/target-speed-kt", 160);
  } else {
    if(airspeed < 170) {
      setprop("/autopilot/settings/target-AoA-deg", 1);
      setprop("/autopilot/locks/AoA-lock", "Engaged");
      setprop("/controls/gear/gear-down", "true");
    }
  }
}
#--------------------------------------------------------------------
atl_glideslope = func {
  # This script handles glide slope interception.
  if(getprop("/position/altitude-agl-ft") > 200) {
    if(getprop("/autopilot/locks/altitude") != "gsvfps-hold") {
      setprop("/autopilot/settings/target-vfps", 0);
      setprop("/autopilot/locks/altitude", "gsvfps-hold");
    } else {
      if(getprop("/autopilot/internal/filtered-gs-rate-of-climb") < 0) {
        gsvfps = getprop("/instrumentation/nav[0]/gs-rate-of-climb");
        setprop("/autopilot/settings/target-vfps", gsvfps);
        setprop("/autopilot/locks/altitude", "gsvfps-hold");
      }
    }
  }
}
#--------------------------------------------------------------------
atl_touchdown = func {
  # Touch Down phase.
  agl = getprop("/position/altitude-agl-ft");
  vfps = getprop("/velocities/vertical-speed-fps");
  setprop("/autopilot/locks/altitude", "gsvfps-hold");
  setprop("/autopilot/settings/target-vfps", vfps);
  setprop("/autopilot/locks/AoA-lock", "Off");

  if(agl < 0.01) {
    setprop("/controls/gear/brake-left", 0.1);
    setprop("/controls/gear/brake-right", 0.1);
    setprop("/autopilot/settings/ground-roll-heading-deg", -999.9);
    setprop("/autopilot/locks/auto-landing", "disabled");
    setprop("/autopilot/locks/auto-take-off", "enabled");
    setprop("/autopilot/locks/altitude", "Off");
    setprop("/autopilot/settings/target-vfps", 0);
    interpolate("/controls/flight/elevator-trim", 0, 10.0);
  } else {
    if(agl < 0.8) {
      setprop("/autopilot/locks/heading", "Off");
      setprop("/controls/flight/spoilers", 1);
    } else {
      if(agl < 4) {
        setprop("/autopilot/locks/speed", "Off");
        setprop("/controls/engines/engine[0]/throttle", 0);
        setprop("/controls/engines/engine[1]/throttle", 0);
        setprop("/controls/engines/engine[2]/throttle", 0);
        setprop("/controls/engines/engine[3]/throttle", 0);
        setprop("/controls/engines/engine[4]/throttle", 0);
        setprop("/controls/engines/engine[5]/throttle", 0);
        setprop("/controls/engines/engine[6]/throttle", 0);
        setprop("/controls/engines/engine[7]/throttle", 0);
      }
    }
  }
  if(agl < 1) {
    setprop("/autopilot/settings/target-vfps", -0.5);
  } else {
    if(agl < 2) {
      setprop("/autopilot/settings/target-vfps", -1.0);
    } else {
      if(agl < 4) {
        setprop("/autopilot/settings/target-vfps", -2);
      } else {
        if(agl < 8) {
          setprop("/autopilot/settings/target-vfps", -3);
        } else {
          if(agl < 16) {
            setprop("/autopilot/settings/target-vfps", -4);
          } else {
            if(agl < 20) {
              setprop("/autopilot/settings/target-vfps", -6);
            } else {
              if(agl < 40) {
                setprop("/autopilot/settings/target-vfps", -8);
              } else {
                if(agl < 80) {
                  setprop("/autopilot/settings/target-vfps", -10);
                } else {
                  if(agl < 160) {
                    setprop("/autopilot/settings/target-vfps", -12);
                  } else {
                    setprop("/autopilot/locks/altitude", "gsvfps-hold");
                    setprop("/autopilot/settings/target-vfps", vfps);
                    setprop("/autopilot/locks/AoA-lock", "off");
                    setprop("/autopilot/locks/heading", "");
                  }
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
atl_aoa = func {
  #This script handles AoA dependent actions.
  aoa = getprop("/orientation/alpha-deg");
  flpxa = getprop("/autopilot/settings/flap-extend-aoa-deg");
  if(getprop("/controls/flight/flaps") < 1) {
    if(aoa > flpxa) {
      setprop("/controls/flight/flaps", 1);
    }
  }
}
#--------------------------------------------------------------------
atl_heading = func {
  # This script handles heading dependent actions.
  hdnddf = getprop("/autopilot/internal/heading-needle-deflection-filtered");
  if(hdnddf < 3) {
    if(hdnddf > -3) {
      setprop("/autopilot/locks/heading", "nav1-hold-fa");
    } else {
      setprop("/autopilot/locks/heading", "nav1-hold");
    }
  } else {
    setprop("/autopilot/locks/heading", "nav1-hold");
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
initialise_target_altitude = func {
  alt = getprop("/position/altitude-ft") + 3000;
  setprop("/autopilot/settings/target-altitude-ft", alt);
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
  settimer(initialise_target_altitude, 5);
}
#--------------------------------------------------------------------
