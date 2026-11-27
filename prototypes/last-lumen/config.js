// PROTOTYPE - NOT FOR PRODUCTION
// Question: Is a fast side-view run, where the lantern charge turns hits into a Flare and room boons change how the Flare works, fun enough to want one more run?
// Date: 2026-11-27
// Every tuning value lives here, each with value, min, max and step. The game reads them live
// through tune.<name> (index.html); the tweak panel, an add-on, writes them back here.
// Distances are in world pixels (the screen is 1280x720), times in seconds, speeds in px/s.
window.CONFIG = {
  seed: 1, // every gameplay random call reads rng(), seeded from this (or ?seed= in the address)
  volume: { value: 0.5, min: 0, max: 1, step: 0.05 },

  // ---- Player movement ----
  run_speed: { value: 360, min: 150, max: 700, step: 10 },        // px/s
  gravity: { value: 2300, min: 800, max: 4000, step: 50 },        // px/s^2
  jump_speed: { value: 860, min: 400, max: 1400, step: 10 },      // px/s upward at take-off
  max_fall: { value: 1100, min: 400, max: 2000, step: 50 },       // px/s
  coyote: { value: 0.1, min: 0, max: 0.3, step: 0.01 },           // s of jump grace after a ledge
  jump_buffer: { value: 0.12, min: 0, max: 0.3, step: 0.01 },     // s a jump press is remembered
  dash_speed: { value: 980, min: 400, max: 1800, step: 20 },      // px/s
  dash_time: { value: 0.17, min: 0.05, max: 0.4, step: 0.01 },    // s, untouchable the whole time
  dash_cooldown: { value: 0.55, min: 0.1, max: 2, step: 0.05 },   // s
  player_hp: { value: 100, min: 20, max: 300, step: 5 },
  hurt_iframes: { value: 0.8, min: 0.2, max: 2, step: 0.05 },     // s untouchable after a hit

  // ---- Strike ----
  strike_dmg: { value: 11, min: 1, max: 60, step: 1 },
  strike_finisher: { value: 1.8, min: 1, max: 4, step: 0.1 },     // x damage on the 3rd hit of a combo
  strike_time: { value: 0.26, min: 0.1, max: 0.6, step: 0.01 },   // s per swing
  strike_reach: { value: 78, min: 30, max: 200, step: 2 },        // px in front of the knight
  knockback: { value: 260, min: 0, max: 800, step: 10 },          // px/s pushed on a hit
  hitstop: { value: 0.045, min: 0, max: 0.15, step: 0.005 },      // s frozen on a landed hit

  // ---- The Lantern and the Flare ----
  charge_per_hit: { value: 10, min: 1, max: 50, step: 1 },        // % of the lantern per landed hit
  light_base: { value: 170, min: 60, max: 500, step: 5 },         // px light radius at empty lantern
  light_gain: { value: 230, min: 0, max: 600, step: 5 },          // px extra radius at a full lantern
  darkness: { value: 0.86, min: 0, max: 1, step: 0.01 },          // how dark the unlit room is
  flare_dmg: { value: 38, min: 5, max: 200, step: 1 },
  flare_radius: { value: 430, min: 100, max: 900, step: 10 },     // px
  flare_stun: { value: 1.4, min: 0, max: 4, step: 0.1 },          // s enemies are stunned
  burn_time: { value: 3, min: 0, max: 8, step: 0.5 },             // s a Flare burns enemies
  burn_dps: { value: 5, min: 0, max: 30, step: 1 },               // damage per second while burning

  // ---- Enemies (base values, Ash levels scale them) ----
  crawler_hp: { value: 34, min: 5, max: 200, step: 1 },
  crawler_speed: { value: 95, min: 20, max: 300, step: 5 },
  crawler_charge: { value: 640, min: 200, max: 1200, step: 10 },  // px/s rush
  crawler_wind: { value: 0.5, min: 0.1, max: 1.5, step: 0.05 },   // s warning before the rush
  crawler_dmg: { value: 12, min: 1, max: 60, step: 1 },
  bat_hp: { value: 20, min: 5, max: 150, step: 1 },
  bat_swoop: { value: 540, min: 200, max: 1200, step: 10 },
  bat_wind: { value: 0.55, min: 0.1, max: 1.5, step: 0.05 },
  bat_dmg: { value: 10, min: 1, max: 60, step: 1 },
  sentry_hp: { value: 50, min: 10, max: 300, step: 1 },
  sentry_fire: { value: 2.4, min: 0.6, max: 6, step: 0.1 },       // s between shots
  sentry_shot_speed: { value: 310, min: 100, max: 800, step: 10 },
  sentry_dmg: { value: 14, min: 1, max: 60, step: 1 },
  sentry_block: { value: 0.15, min: 0, max: 1, step: 0.05 },      // x damage a strike to the shield deals
  bloat_hp: { value: 26, min: 5, max: 150, step: 1 },
  bloat_speed: { value: 75, min: 20, max: 250, step: 5 },
  bloat_fuse: { value: 0.85, min: 0.2, max: 2, step: 0.05 },      // s it swells before it bursts
  bloat_radius: { value: 125, min: 40, max: 300, step: 5 },
  bloat_dmg: { value: 22, min: 1, max: 80, step: 1 },             // to the player; enemies take 2x
  warden_hp: { value: 720, min: 100, max: 3000, step: 10 },
  warden_dmg: { value: 18, min: 1, max: 80, step: 1 },
  warden_rest: { value: 1.0, min: 0.2, max: 3, step: 0.1 },       // s between its attacks

  // ---- Run and rewards ----
  floor_heal: { value: 0.3, min: 0, max: 1, step: 0.05 },         // share of max health healed between floors
  embers_mult: { value: 1, min: 0.2, max: 5, step: 0.1 },
  win_bonus: { value: 60, min: 0, max: 500, step: 5 },            // Embers for beating the boss
  ash_hp: { value: 0.25, min: 0, max: 1, step: 0.05 },            // +enemy health per Ash level
  ash_dmg: { value: 0.15, min: 0, max: 1, step: 0.05 },           // +enemy damage per Ash level
  ash_speed: { value: 0.07, min: 0, max: 0.5, step: 0.01 },       // +enemy speed per Ash level
  ash_embers: { value: 0.3, min: 0, max: 1, step: 0.05 },         // +Embers per Ash level
  up_cost_scale: { value: 1, min: 0.2, max: 3, step: 0.1 },       // x every Shrine price
  up_vigor_hp: { value: 12, min: 1, max: 50, step: 1 },           // max health per Vigor level
};
