/* ZAB LAYOUT + SHADOW GARDEN CODE - BO1 Zombies v1.0.3 */

#include common_scripts\utility;
#include maps\_utility;
#include maps\_zombiemode;
#include maps\_zombiemode_perks;
#include maps\_zombiemode_score;
#include maps\_zombiemode_powerups;

/* ============================================================
   ENTRY POINT
   ============================================================ */

main()
{
    level thread shadow_wire_players();
}

shadow_wire_players()
{
    level endon("game_ended");

    players = level.players;
    for (i = 0; i < players.size; i++)
    {
        if (isDefined(players[i]) && !isDefined(players[i].shadow_running))
            players[i] thread shadow_player_init();
    }

    for (;;)
    {
        level waittill("connected", player);
        player thread shadow_player_init();
        player thread shadow_respawn_watch();
    }
}

shadow_respawn_watch()
{
    self endon("disconnect");
    for (;;)
    {
        self waittill("spawned_player");
        self thread shadow_player_init();
    }
}

/* ============================================================
   PLAYER INIT (Shadow state, ZAB layout)
   ============================================================ */

shadow_player_init()
{
    self endon("disconnect");

    if (isDefined(self.shadow_running) && self.shadow_running)
        return;

    self.shadow_running = true;
    self.shadow_open = false;
    self.shadow_closing = false;
    self.shadow_lock_controls = false;
    self.shadow_was_ignored = false;
    self.shadow_menu_invuln_applied = false;
    self.shadow_page = 0;
    self.shadow_cursor = 0;
    self.shadow_window = 0;
    self.shadow_visible_rows = 8;
    self.shadow_rows = [];
    self.shadow_chevrons = [];
    self.shadow_items = [];
    self.shadow_item_values = [];

    self.shadow_god = false;
    self.shadow_user_notarget = false;
    self.shadow_spawn_origin = undefined;
    self.shadow_room_slots = [];
    self.shadow_map_spots = [];
    self.shadow_shoot_tp = false;
    self.shadow_last_shoot_tp = -10000;
    self.shadow_fx_enabled = false;
    self.shadow_fx_style = 0;
    self.shadow_last_fx = -10000;
    self.shadow_nuke_rounds = false;
    self.shadow_last_nuke_shot = -10000;
    self.shadow_speed = false;
    self.shadow_auto_refill = false;
    self.shadow_infinite_clip = false;
    self.shadow_ammo_mode = 0;
    self.shadow_one_hit = false;
    self.shadow_zombie_counter = false;
    self.shadow_count_hud = undefined;
    self.shadow_saved_origin = undefined;
    self.shadow_classic_aimbot = false;
    self.shadow_unfair_aimbot = false;
    self.shadow_aim_always = false;
    self.shadow_aim_bone = "j_head";
    self.shadow_key_mode = 0;
    self.shadow_noclip_bind = 1;
    self.shadow_noclip_active = false;
    self.shadow_key_repeat = 215;
    self.shadow_invert_scroll = false;
    self.shadow_swap_horizontal = false;
    self.shadow_color_r = 0.87;
    self.shadow_color_g = 0.19;
    self.shadow_color_b = 0.36;
    self.shadow_last_powerup_drop = -5000;
    self.shadow_palette = 0;
    self.shadow_low_effects = false;
    self.shadow_selection_visible = true;
    self.shadow_scrollbar_visible = true;
    self.shadow_busy_defcon = false;
    self.shadow_busy_doors = false;
    self.shadow_busy_clear = false;
    self.shadow_defcon_last = -10000;
    self.shadow_menu_auto_protect = true;
    self.shadow_watermark_visible = true;
    self.shadow_achievement_survivor = false;
    self.shadow_achievement_veteran = false;
    self.shadow_achievement_rich = false;
    self.shadow_achievement_century = false;
    self.shadow_achievement_banker = false;

    self thread shadow_input_loop();
    self thread shadow_refill_loop();
    self thread shadow_aimbot_loop();
    self thread shadow_counter_loop();
    self thread shadow_watermark_loop();
    self thread shadow_ammo_effect_loop();
    self thread shadow_achievement_loop();
    self thread shadow_one_hit_loop();
    self thread shadow_menu_lock_loop();
    self thread shadow_safety_watchdog();
}

/* ============================================================
   SAFETY / LOCK
   ============================================================ */

shadow_safety_watchdog()
{
    self endon("disconnect");
    for (;;)
    {
        if (self.shadow_open && !self.shadow_closing &&
            (!isDefined(self.shadow_bg) || !isDefined(self.shadow_title) ||
            !isDefined(self.shadow_sel_pad) || !isDefined(self.shadow_sel_bar) ||
            self.shadow_rows.size != self.shadow_visible_rows))
        {
            self.shadow_animations = false;
            self shadow_close();
            self iPrintLn("^1SHADOW ^7HUD recovered from an incomplete state");
        }
        wait 1;
    }
}

shadow_menu_lock_loop()
{
    self endon("disconnect");
    for (;;)
    {
        if (self.shadow_open && self.shadow_lock_controls)
        {
            self setVelocity((0, 0, 0));
            if (distance(self.origin, self.shadow_lock_origin) > 0.25)
                self setOrigin(self.shadow_lock_origin);
            self setPlayerAngles(self.shadow_lock_angles);
            wait 0.016;
        }
        else
            wait 0.10;
    }
}

/* ============================================================
   INPUT (ZAB-style - includes NoClip bind passthrough)
   ============================================================ */

shadow_input_loop()
{
    self endon("disconnect");

    old_ads = false;
    old_melee = false;
    old_attack = false;
    old_use = false;
    old_right = false;
    old_left = false;
    old_noclip_combo = false;
    next_nav = 0;

    for (;;)
    {
        ads = self adsButtonPressed();
        melee = self meleeButtonPressed();
        attack = self attackButtonPressed();
        use = self useButtonPressed();

        if (!self.shadow_open)
        {
            if (ads && melee && (!old_ads || !old_melee))
                self shadow_show();
            else
            {
                noclip_bind = false;
                if (self.shadow_noclip_bind == 1)
                    noclip_bind = ads && self jumpButtonPressed();
                else if (self.shadow_noclip_bind == 2)
                    noclip_bind = use && self jumpButtonPressed();
                else if (self.shadow_noclip_bind == 3)
                    noclip_bind = use && melee;

                if (noclip_bind && !old_noclip_combo)
                    self shadow_request_noclip();
                old_noclip_combo = noclip_bind;
            }
        }
        else
        {
            old_noclip_combo = false;

            movement = self getNormalizedMovement();
            w = movement[0] > 0.50;
            s = movement[0] < -0.50;
            d = movement[1] > 0.50;
            a = movement[1] < -0.50;
            select_key = d && !old_right;
            back_key = a && !old_left;
            up_key = w;
            down_key = s;
            if (self.shadow_swap_horizontal)
            {
                select_key = a && !old_left;
                back_key = d && !old_right;
            }
            if (self.shadow_invert_scroll)
            {
                up_key = s;
                down_key = w;
            }

            if (melee && !old_melee)
                self shadow_close();
            else if ((self.shadow_key_mode == 0 && select_key) ||
                (use && !old_use))
                self shadow_activate();
            else if (self.shadow_key_mode == 0 && back_key)
                self shadow_back();
            else if (getTime() >= next_nav)
            {
                if ((self.shadow_key_mode == 0 && down_key) || (attack && !old_attack))
                {
                    self shadow_move(1);
                    next_nav = getTime() + self.shadow_key_repeat;
                }
                else if ((self.shadow_key_mode == 0 && up_key) || (ads && !old_ads))
                {
                    self shadow_move(-1);
                    next_nav = getTime() + self.shadow_key_repeat;
                }
            }
            old_right = d;
            old_left = a;
        }

        old_ads = ads;
        old_melee = melee;
        old_attack = attack;
        old_use = use;
        wait 0.05;
    }
}

/* ============================================================
   SHOW / CLOSE - ZAB LAYOUT
   ============================================================ */

shadow_show()
{
    if (self.shadow_open || self.shadow_closing)
        return;

    self.shadow_open = true;
    self.shadow_page = 0;
    self.shadow_cursor = 0;
    self.shadow_window = 0;
    self.shadow_lock_controls = true;
    self.shadow_lock_origin = self.origin;
    self.shadow_lock_angles = self getPlayerAngles();
    if (!isDefined(self.shadow_spawn_origin))
        self.shadow_spawn_origin = self.origin;
    self setVelocity((0, 0, 0));
    self setMoveSpeedScale(0);
    self.shadow_was_ignored = isDefined(self.ignoreme) && self.ignoreme;
    self.shadow_menu_invuln_applied = false;
    if (self.shadow_menu_auto_protect)
    {
        self.ignoreme = true;
        self enableInvulnerability();
        self.shadow_menu_invuln_applied = true;
    }
    self disableWeapons();
    self shadow_define_page();

    /* ---- ZAB LAYOUT: box at x 42..354, top bar, footer ---- */

    self.shadow_shadowbar = self shadow_bar(46, 24, 312, 320,
        (0.00, 0.02, 0.01), 0.65, 2);
    self.shadow_bg = self shadow_bar(42, 20, 312, 320,
        (0.028, 0.030, 0.040), 0.96, 3);
    self.shadow_outline_top = self shadow_bar(42, 20, 312, 1,
        self shadow_accent(), 0.55, 4);
    self.shadow_outline_bot = self shadow_bar(42, 339, 312, 1,
        self shadow_accent(), 0.55, 4);

    self.shadow_top = self shadow_bar(42, 20, 312, 64,
        (0.070, 0.020, 0.040), 0.98, 4);
    self.shadow_accent_bar = self shadow_bar(52, 32, 4, 26,
        self shadow_accent(), 1.0, 6);
    self.shadow_title = self shadow_text_left("SHADOW GARDEN", 64, 30, 1.42,
        (0.98, 0.98, 0.98), 8);
    self.shadow_subtitle = self shadow_text_left("BLACK OPS ZOMBIES  /  GSC",
        65, 56, 0.92, self shadow_accent(), 8);
    self.shadow_section = self shadow_text_right("MAIN MENU", 340, 32,
        1.02, self shadow_accent(), 8);
    self.shadow_page_count = self shadow_text_right("1 / 1", 340, 56,
        0.92, (0.85, 0.85, 0.85), 8);
    self.shadow_header_strip = self shadow_bar(42, 82, 312, 2,
        self shadow_accent(), 0.85, 5);

    self.shadow_sel_pad = self shadow_bar(50, 108, 296, 22,
        (0.33, 0.035, 0.095), 0.94, 5);
    self.shadow_sel_bar = self shadow_bar(50, 108, 3, 22,
        self shadow_accent(), 1.0, 7);

    self.shadow_scroll_rail = self shadow_bar(344, 108, 3, 168,
        (0.06, 0.02, 0.04), 0.90, 5);
    self.shadow_scroll_thumb = self shadow_bar(344, 108, 3, 28,
        self shadow_accent(), 0.95, 6);

    for (i = 0; i < self.shadow_visible_rows; i++)
    {
        self.shadow_rows[i] = self shadow_text_left(" ", 62, 111 + (i * 24),
            1.07, (1, 1, 1), 8);
        self.shadow_chevrons[i] = self shadow_text_right(" ", 336,
            111 + (i * 24), 1.05, (0.45, 0.45, 0.52), 7);
    }

    self.shadow_footbar = self shadow_bar(42, 292, 312, 48,
        (0.040, 0.020, 0.030), 0.97, 4);
    self.shadow_foot_strip = self shadow_bar(42, 292, 312, 2,
        self shadow_accent(), 0.75, 5);
    self.shadow_footer  = self shadow_text_left("W/S  SCROLL", 56, 304,
        0.94, (0.85, 0.85, 0.85), 8);
    self.shadow_footer2 = self shadow_text_left("D  SELECT", 146, 304,
        0.94, (0.85, 0.85, 0.85), 8);
    self.shadow_footer3 = self shadow_text_left("A  BACK", 226, 304,
        0.94, (0.85, 0.85, 0.85), 8);
    self.shadow_exit = self shadow_text_right("MELEE  CLOSE", 340, 304,
        0.94, self shadow_accent(), 8);
    self.shadow_open_hint = self shadow_text_left("ADS + MELEE TO OPEN",
        56, 322, 0.85, (0.55, 0.55, 0.60), 8);

    self shadow_paint_page();
}

shadow_close()
{
    if (!self.shadow_open)
        return;

    self.shadow_open = false;
    self.shadow_closing = true;
    self.shadow_lock_controls = false;
    self notify("shadow_menu_closed");
    self enableWeapons();
    if (self.shadow_speed)
        self setMoveSpeedScale(1.5);
    else
        self setMoveSpeedScale(1);
    self.ignoreme = self.shadow_user_notarget || self.shadow_was_ignored;
    if (!self.shadow_god && self.shadow_menu_invuln_applied)
        self disableInvulnerability();
    self.shadow_menu_invuln_applied = false;

    for (i = 0; i < self.shadow_visible_rows; i++)
    {
        if (isDefined(self.shadow_rows[i]))
            self.shadow_rows[i] destroy();
        if (isDefined(self.shadow_chevrons[i]))
            self.shadow_chevrons[i] destroy();
    }

    if (isDefined(self.shadow_shadowbar))     self.shadow_shadowbar destroy();
    if (isDefined(self.shadow_outline_top))   self.shadow_outline_top destroy();
    if (isDefined(self.shadow_outline_bot))   self.shadow_outline_bot destroy();
    if (isDefined(self.shadow_accent_bar))    self.shadow_accent_bar destroy();
    if (isDefined(self.shadow_header_strip))  self.shadow_header_strip destroy();
    if (isDefined(self.shadow_sel_bar))       self.shadow_sel_bar destroy();
    if (isDefined(self.shadow_sel_pad))       self.shadow_sel_pad destroy();
    if (isDefined(self.shadow_scroll_rail))   self.shadow_scroll_rail destroy();
    if (isDefined(self.shadow_scroll_thumb))  self.shadow_scroll_thumb destroy();
    if (isDefined(self.shadow_footbar))       self.shadow_footbar destroy();
    if (isDefined(self.shadow_foot_strip))    self.shadow_foot_strip destroy();
    if (isDefined(self.shadow_footer))        self.shadow_footer destroy();
    if (isDefined(self.shadow_footer2))       self.shadow_footer2 destroy();
    if (isDefined(self.shadow_footer3))       self.shadow_footer3 destroy();
    if (isDefined(self.shadow_exit))          self.shadow_exit destroy();
    if (isDefined(self.shadow_open_hint))     self.shadow_open_hint destroy();
    if (isDefined(self.shadow_section))       self.shadow_section destroy();
    if (isDefined(self.shadow_page_count))    self.shadow_page_count destroy();
    if (isDefined(self.shadow_subtitle))      self.shadow_subtitle destroy();
    if (isDefined(self.shadow_title))         self.shadow_title destroy();
    if (isDefined(self.shadow_top))           self.shadow_top destroy();
    if (isDefined(self.shadow_bg))            self.shadow_bg destroy();

    self.shadow_rows = [];
    self.shadow_chevrons = [];
    self.shadow_items = [];
    self.shadow_item_values = [];
    self.shadow_cursor = 0;
    self.shadow_window = 0;
    self.shadow_closing = false;

    self.shadow_shadowbar = undefined;
    self.shadow_bg = undefined;
    self.shadow_outline_top = undefined;
    self.shadow_outline_bot = undefined;
    self.shadow_top = undefined;
    self.shadow_accent_bar = undefined;
    self.shadow_title = undefined;
    self.shadow_subtitle = undefined;
    self.shadow_section = undefined;
    self.shadow_page_count = undefined;
    self.shadow_header_strip = undefined;
    self.shadow_sel_pad = undefined;
    self.shadow_sel_bar = undefined;
    self.shadow_scroll_rail = undefined;
    self.shadow_scroll_thumb = undefined;
    self.shadow_footbar = undefined;
    self.shadow_foot_strip = undefined;
    self.shadow_footer = undefined;
    self.shadow_footer2 = undefined;
    self.shadow_footer3 = undefined;
    self.shadow_exit = undefined;
    self.shadow_open_hint = undefined;
}
