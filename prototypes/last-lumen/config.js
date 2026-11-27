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

  // ---- Locations, tiers and elites ----
  rooms_per_loc: { value: 4, min: 1, max: 8, step: 1 },          // combat rooms before each boss
  tier_hp: { value: 0.45, min: 0, max: 2, step: 0.05 },           // +enemy health per location already beaten
  tier_dmg: { value: 0.25, min: 0, max: 2, step: 0.05 },          // +enemy damage per location already beaten
  haven_heal: { value: 0.4, min: 0, max: 1, step: 0.05 },         // share of max health healed in a save room
  elite_chance: { value: 0.18, min: 0, max: 1, step: 0.01 },      // per wave, per tier above the first
  elite_hp: { value: 1.9, min: 1, max: 5, step: 0.1 },            // x health of an elite
  res_drop: { value: 0.35, min: 0, max: 1, step: 0.05 },          // chance an enemy drops its location's resource
  ringer_hp: { value: 40, min: 5, max: 200, step: 1 },
  ringer_dmg: { value: 16, min: 1, max: 60, step: 1 },
  jelly_hp: { value: 30, min: 5, max: 200, step: 1 },
  jelly_dmg: { value: 14, min: 1, max: 60, step: 1 },
  jelly_radius: { value: 105, min: 40, max: 250, step: 5 },       // px of its zap
  clockmaker_hp: { value: 680, min: 100, max: 3000, step: 10 },
  queen_hp: { value: 640, min: 100, max: 3000, step: 10 },
  boss_tier_hp: { value: 0.35, min: 0, max: 2, step: 0.05 },      // +boss health per location already beaten

  // ---- Weapons (damage and swing time are multipliers on strike_dmg and the weapon's own timing) ----
  blade_dmg: { value: 1, min: 0.2, max: 4, step: 0.05 },
  spear_dmg: { value: 1.25, min: 0.2, max: 4, step: 0.05 },
  spear_reach: { value: 150, min: 60, max: 300, step: 5 },
  sickles_dmg: { value: 0.6, min: 0.1, max: 3, step: 0.05 },
  hammer_dmg: { value: 2.5, min: 0.5, max: 6, step: 0.05 },
  hammer_quake: { value: 190, min: 50, max: 400, step: 10 },      // px reach of the hammer's ground shock
  swing_speed: { value: 1, min: 0.5, max: 2, step: 0.05 },        // x speed of every weapon's swing

  // ---- Lanterns ----
  storm_jumps: { value: 6, min: 1, max: 15, step: 1 },            // enemies the Storm Flare's lightning jumps to
  storm_dmg: { value: 1.6, min: 0.5, max: 5, step: 0.1 },         // x flare_dmg per bolt
  storm_dash_charge: { value: 8, min: 0, max: 40, step: 1 },      // % charge per dash with the Storm lantern
  moon_slow: { value: 0.7, min: 0, max: 0.95, step: 0.05 },       // share enemies are slowed by the Moon Flare
  moon_time: { value: 5, min: 1, max: 12, step: 0.5 },            // s
  moon_heal: { value: 12, min: 0, max: 60, step: 1 },
  witch_wisps: { value: 5, min: 1, max: 12, step: 1 },
  witch_dmg: { value: 0.9, min: 0.2, max: 4, step: 0.1 },         // x flare_dmg per wisp
  witch_kill_charge: { value: 12, min: 0, max: 50, step: 1 },     // % charge per kill with the Witch lantern

  // ---- Directional strikes and physics ----
  pogo_speed: { value: 760, min: 200, max: 1400, step: 20 },      // px/s bounce up after a down strike hits
  down_fall: { value: 900, min: 0, max: 1800, step: 20 },         // px/s minimum fall speed during a down strike
  slam_dmg: { value: 14, min: 0, max: 80, step: 1 },              // shockwave when a down strike lands
  slam_r: { value: 140, min: 40, max: 400, step: 10 },            // px shockwave radius
  launch_speed: { value: 640, min: 0, max: 1400, step: 20 },      // px/s an up strike throws a ground enemy
  air_mult: { value: 1.25, min: 1, max: 3, step: 0.05 },          // damage x to an enemy thrown into the air
  wall_slam_speed: { value: 300, min: 50, max: 1000, step: 10 },  // px/s of knockback needed to slam a wall or another enemy
  wall_slam_dmg: { value: 12, min: 0, max: 80, step: 1 },         // damage from hitting a wall or another enemy
  roll_time: { value: 0.3, min: 0.1, max: 0.8, step: 0.02 },      // s a ground roll lasts (air dash uses dash_time)

  // ---- Gods' statuses and runes ----
  shock_stacks: { value: 3, min: 1, max: 8, step: 1 },            // Perun charges before a discharge
  shock_dmg: { value: 22, min: 1, max: 100, step: 1 },            // discharge damage to the charged enemy
  shock_jumps: { value: 1, min: 0, max: 8, step: 1 },             // extra enemies a discharge jumps to
  bleed_time: { value: 3, min: 0, max: 10, step: 0.5 },           // s of Stribog's cuts
  bleed_dps: { value: 6, min: 0, max: 40, step: 1 },              // damage per second while cut
  curse_time: { value: 6, min: 0, max: 15, step: 0.5 },           // s of Veles' curse
  curse_mult: { value: 1.3, min: 1, max: 3, step: 0.05 },         // x damage a cursed enemy takes
  shield_max: { value: 40, min: 0, max: 200, step: 5 },           // the most Zhiva's shield can hold
  rune_dash_dmg: { value: 12, min: 0, max: 60, step: 1 },         // damage a dash rune deals passing through
  duo_chance: { value: 0.5, min: 0, max: 1, step: 0.05 },         // chance a union rune joins the offer when allowed
  legend_chance: { value: 0.35, min: 0, max: 1, step: 0.05 },     // chance the Wrath of the Gods joins the offer
  fork_three: { value: 0.45, min: 0, max: 1, step: 0.05 },        // chance a fork has three doors, not two
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
