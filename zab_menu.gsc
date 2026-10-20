/* ZAB MENU GSC - BO1 Zombies v1.2.0 */

#include common_scripts\utility;
#include maps\_utility;

/* ============================================================
   ENTRY POINT
   ============================================================ */

main()
{
    level thread zab_wire_players();
}

zab_wire_players()
{
    level endon("game_ended");

    for (;;)
    {
        level waittill("connected", player);
        player thread zab_player_init();
        player thread zab_player_respawn_watch();
    }
}

zab_player_respawn_watch()
{
    self endon("disconnect");

    for (;;)
    {
        self waittill("spawned_player");
        self thread zab_player_init();
    }
}

/* ============================================================
   PLAYER INIT
   ============================================================ */

zab_player_init()
{
    self endon("disconnect");

    if (isDefined(self.zab_running) && self.zab_running)
        return;

    self.zab_running = true;
    self.zab_open = false;
    self.zab_closing = false;
    self.zab_lock_controls = false;
    self.zab_was_ignored = false;
    self.zab_menu_invuln_applied = false;
    self.zab_page = 0;
    self.zab_cursor = 0;
    self.zab_window = 0;
    self.zab_visible_rows = 5;
    self.zab_rows = [];
    self.zab_chevrons = [];
    self.zab_items = [];
    self.zab_item_values = [];

    self.zab_god = false;
    self.zab_user_notarget = false;
    self.zab_noclip = false;
    self.zab_noclip_speed = 8;
    self.zab_noclip_bind = 1;
    self.zab_noclip_worker_running = false;
    self.zab_noclip_return = undefined;
    self.zab_spawn_origin = undefined;
    self.zab_room_slots = [];
    self.zab_map_spots = [];
    self.zab_shoot_tp = false;
    self.zab_last_shoot_tp = -10000;
    self.zab_fx_enabled = false;
    self.zab_fx_style = 0;
    self.zab_last_fx = -10000;
    self.zab_nuke_rounds = false;
    self.zab_last_nuke_shot = -10000;
    self.zab_speed = false;
    self.zab_auto_refill = false;
    self.zab_infinite_clip = false;
    self.zab_ammo_mode = 0;
    self.zab_one_hit = false;
    self.zab_zombie_counter = false;
    self.zab_count_hud = undefined;
    self.zab_saved_origin = undefined;
    self.zab_classic_aimbot = false;
    self.zab_unfair_aimbot = false;
    self.zab_aim_always = false;
    self.zab_aim_bone = "j_head";
    self.zab_key_mode = 0;
    self.zab_key_repeat = 165;
    self.zab_invert_scroll = false;
    self.zab_swap_horizontal = false;
    self.zab_panel_opacity = 0.96;
    self.zab_animations = true;
    self.zab_low_effects = false;
    self.zab_toast_enabled = true;
    self.zab_extra_shaders = true;
    self.zab_busy_defcon = false;
    self.zab_busy_doors = false;
    self.zab_busy_clear = false;
    self.zab_defcon_last = -10000;
    self.zab_menu_auto_protect = true;
    self.zab_watermark_visible = true;
    self.zab_achievement_survivor = false;
    self.zab_achievement_veteran = false;
    self.zab_achievement_rich = false;
    self.zab_achievement_century = false;
    self.zab_achievement_banker = false;
    self.zab_last_powerup_drop = -5000;

    self thread zab_input_loop();
    self thread zab_refill_loop();
    self thread zab_aimbot_loop();
    self thread zab_counter_loop();
    self thread zab_watermark_loop();
    self thread zab_ammo_effect_loop();
    self thread zab_achievement_loop();
    self thread zab_one_hit_loop();
    self thread zab_menu_lock_loop();
    self thread zab_safety_watchdog();
}

/* ============================================================
   SAFETY / LOCK
   ============================================================ */

zab_safety_watchdog()
{
    self endon("disconnect");
    for (;;)
    {
        if (self.zab_open && !self.zab_closing &&
            (!isDefined(self.zab_bg) || !isDefined(self.zab_title) ||
            !isDefined(self.zab_sel_pad) || !isDefined(self.zab_sel_bar) ||
            self.zab_rows.size != self.zab_visible_rows))
        {
            self.zab_animations = false;
            self zab_close();
            self iPrintLn("^2ZAB ^7HUD recovered from an incomplete state");
        }
        wait 1;
    }
}

zab_menu_lock_loop()
{
    self endon("disconnect");
    for (;;)
    {
        if (self.zab_open && self.zab_lock_controls)
        {
            self setVelocity((0, 0, 0));
            if (distance(self.origin, self.zab_lock_origin) > 0.25)
                self setOrigin(self.zab_lock_origin);
            self setPlayerAngles(self.zab_lock_angles);
            wait 0.016;
        }
        else
            wait 0.10;
    }
}

/* ============================================================
   INPUT
   ============================================================ */

zab_input_loop()
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

        if (!self.zab_open)
        {
            if (ads && melee && (!old_ads || !old_melee))
                self zab_show();
            else
            {
                noclip_bind = false;
                if (self.zab_noclip_bind == 1)
                    noclip_bind = ads && self jumpButtonPressed();
                else if (self.zab_noclip_bind == 2)
                    noclip_bind = use && self jumpButtonPressed();
                else if (self.zab_noclip_bind == 3)
                    noclip_bind = use && melee;

                if (noclip_bind && !old_noclip_combo)
                    self zab_toggle_noclip();
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
            if (self.zab_swap_horizontal)
            {
                select_key = a && !old_left;
                back_key = d && !old_right;
            }
            if (self.zab_invert_scroll)
            {
                up_key = s;
                down_key = w;
            }

            if (melee && !old_melee)
                self zab_close();
            else if ((self.zab_key_mode == 0 && select_key) ||
                (use && !old_use))
                self zab_activate();
            else if (self.zab_key_mode == 0 && back_key)
                self zab_back();
            else if (getTime() >= next_nav)
            {
                if ((self.zab_key_mode == 0 && down_key) || (attack && !old_attack))
                {
                    self zab_move(1);
                    next_nav = getTime() + self.zab_key_repeat;
                }
                else if ((self.zab_key_mode == 0 && up_key) || (ads && !old_ads))
                {
                    self zab_move(-1);
                    next_nav = getTime() + self.zab_key_repeat;
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
   SHOW / CLOSE
   ============================================================ */

zab_show()
{
    if (self.zab_open || self.zab_closing)
        return;

    self.zab_open = true;
    self.zab_page = 0;
    self.zab_cursor = 0;
    self.zab_window = 0;
    self.zab_lock_controls = true;
    self.zab_lock_origin = self.origin;
    self.zab_lock_angles = self getPlayerAngles();
    if (!isDefined(self.zab_spawn_origin))
        self.zab_spawn_origin = self.origin;
    self setVelocity((0, 0, 0));
    self setMoveSpeedScale(0);
    self.zab_was_ignored = isDefined(self.ignoreme) && self.ignoreme;
    self.zab_menu_invuln_applied = false;
    if (self.zab_menu_auto_protect)
    {
        self.ignoreme = true;
        self enableInvulnerability();
        self.zab_menu_invuln_applied = true;
    }
    self disableWeapons();
    self zab_define_page();

    self.zab_shadowbar = self zab_bar(46, 24, 312, 320,
        (0.00, 0.02, 0.01), 0.65, 2);
    self.zab_bg = self zab_bar(42, 20, 312, 320,
        (0.028, 0.062, 0.040), self.zab_panel_opacity, 3);
    self.zab_outline_top = self zab_bar(42, 20, 312, 1,
        (0.20, 0.55, 0.30), 0.55, 4);
    self.zab_outline_bot = self zab_bar(42, 339, 312, 1,
        (0.20, 0.55, 0.30), 0.55, 4);

    self.zab_top = self zab_bar(42, 20, 312, 64,
        (0.045, 0.14, 0.075), 0.98, 4);
    self.zab_accent = self zab_bar(52, 32, 4, 26,
        (0.35, 0.95, 0.55), 1.0, 6);
    self.zab_title = self zab_text_left("ZAB MENU", 64, 30, 1.42,
        (0.38, 0.98, 0.58), 8);
    self.zab_subtitle = self zab_text_left("BLACK OPS ZOMBIES  /  GSC",
        65, 56, 0.92, (0.52, 0.82, 0.58), 8);
    self.zab_section = self zab_text_right("MAIN MENU", 340, 32,
        1.02, (0.70, 0.95, 0.74), 8);
    self.zab_page_count = self zab_text_right("1 / 1", 340, 56,
        0.92, (0.48, 0.68, 0.54), 8);
    self.zab_header_strip = self zab_bar(42, 82, 312, 2,
        (0.22, 0.70, 0.38), 0.85, 5);

    self.zab_sel_pad = self zab_bar(50, 108, 296, 22,
        (0.075, 0.20, 0.11), 0.85, 5);
    self.zab_sel_bar = self zab_bar(50, 108, 3, 22,
        (0.42, 1.00, 0.62), 1.0, 7);

    if (self.zab_extra_shaders && !self.zab_low_effects)
    {
        self.zab_scroll_rail = self zab_bar(344, 108, 3, 168,
            (0.06, 0.16, 0.10), 0.90, 5);
        self.zab_scroll_thumb = self zab_bar(344, 108, 3, 28,
            (0.32, 0.88, 0.48), 0.95, 6);
    }

    for (i = 0; i < self.zab_visible_rows; i++)
    {
        self.zab_rows[i] = self zab_text_left(" ", 62, 111 + (i * 24),
            1.07, (0.86, 0.96, 0.88), 8);
        self.zab_chevrons[i] = self zab_text_right(" ", 336,
            111 + (i * 24), 1.05, (0.45, 0.70, 0.52), 7);
    }

    self.zab_footbar = self zab_bar(42, 292, 312, 48,
        (0.040, 0.11, 0.065), 0.97, 4);
    self.zab_foot_strip = self zab_bar(42, 292, 312, 2,
        (0.18, 0.55, 0.30), 0.75, 5);
    self.zab_footer  = self zab_text_left("W/S  SCROLL", 56, 304,
        0.94, (0.60, 0.82, 0.65), 8);
    self.zab_footer2 = self zab_text_left("D  SELECT", 146, 304,
        0.94, (0.60, 0.82, 0.65), 8);
    self.zab_footer3 = self zab_text_left("A  BACK", 226, 304,
        0.94, (0.60, 0.82, 0.65), 8);
    self.zab_exit = self zab_text_right("MELEE  CLOSE", 340, 304,
        0.94, (0.42, 0.85, 0.55), 8);
    self.zab_open_hint = self zab_text_left("ADS + MELEE TO OPEN",
        56, 322, 0.85, (0.35, 0.58, 0.42), 8);

    if (self.zab_toast_enabled)
    {
        self.zab_open_toast = self zab_text_right("ZAB",
            340, 4, 0.92, (0.72, 0.98, 0.78), 9);
        self thread zab_open_toast_life();
    }

    if (self.zab_animations)
    {
        self.zab_bg.alpha = 0;
        self.zab_bg fadeOverTime(0.16);
        self.zab_bg.alpha = self.zab_panel_opacity;

        self.zab_top.alpha = 0;
        self.zab_top fadeOverTime(0.16);
        self.zab_top.alpha = 0.98;

        self.zab_sel_pad.alpha = 0;
        self.zab_sel_pad fadeOverTime(0.12);
        self.zab_sel_pad.alpha = 0.85;
    }

    self zab_paint_page();
}

zab_open_toast_life()
{
    self endon("disconnect");
    self endon("zab_menu_closed");
    wait 1.65;
    if (isDefined(self.zab_open_toast))
    {
        self.zab_open_toast fadeOverTime(0.35);
        self.zab_open_toast.alpha = 0;
    }
    wait 0.36;
    if (isDefined(self.zab_open_toast))
        self.zab_open_toast destroy();
    self.zab_open_toast = undefined;
}

zab_close()
{
    if (!self.zab_open)
        return;

    self.zab_open = false;
    self.zab_closing = true;
    self.zab_lock_controls = false;
    self notify("zab_menu_closed");
    self enableWeapons();
    if (self.zab_speed)
        self setMoveSpeedScale(1.5);
    else
        self setMoveSpeedScale(1);
    self.ignoreme = self.zab_user_notarget || self.zab_was_ignored;
    if (!self.zab_god && self.zab_menu_invuln_applied)
        self disableInvulnerability();
    self.zab_menu_invuln_applied = false;

    if (self.zab_animations)
    {
        self.zab_bg fadeOverTime(0.10);
        self.zab_bg.alpha = 0;
        self.zab_top fadeOverTime(0.10);
        self.zab_top.alpha = 0;
        self.zab_sel_pad fadeOverTime(0.10);
        self.zab_sel_pad.alpha = 0;
        wait 0.10;
    }

    for (i = 0; i < self.zab_visible_rows; i++)
    {
        if (isDefined(self.zab_rows[i]))
            self.zab_rows[i] destroy();
        if (isDefined(self.zab_chevrons[i]))
            self.zab_chevrons[i] destroy();
    }

    if (isDefined(self.zab_shadowbar))       self.zab_shadowbar destroy();
    if (isDefined(self.zab_outline_top))     self.zab_outline_top destroy();
    if (isDefined(self.zab_outline_bot))     self.zab_outline_bot destroy();
    if (isDefined(self.zab_accent))          self.zab_accent destroy();
    if (isDefined(self.zab_header_strip))    self.zab_header_strip destroy();
    if (isDefined(self.zab_sel_bar))         self.zab_sel_bar destroy();
    if (isDefined(self.zab_sel_pad))         self.zab_sel_pad destroy();
    if (isDefined(self.zab_scroll_rail))     self.zab_scroll_rail destroy();
    if (isDefined(self.zab_scroll_thumb))    self.zab_scroll_thumb destroy();
    if (isDefined(self.zab_footbar))         self.zab_footbar destroy();
    if (isDefined(self.zab_foot_strip))      self.zab_foot_strip destroy();
    if (isDefined(self.zab_footer))          self.zab_footer destroy();
    if (isDefined(self.zab_footer2))         self.zab_footer2 destroy();
    if (isDefined(self.zab_footer3))         self.zab_footer3 destroy();
    if (isDefined(self.zab_exit))            self.zab_exit destroy();
    if (isDefined(self.zab_open_hint))       self.zab_open_hint destroy();
    if (isDefined(self.zab_open_toast))      self.zab_open_toast destroy();
    if (isDefined(self.zab_section))         self.zab_section destroy();
    if (isDefined(self.zab_page_count))      self.zab_page_count destroy();
    if (isDefined(self.zab_subtitle))        self.zab_subtitle destroy();
    if (isDefined(self.zab_title))           self.zab_title destroy();
    if (isDefined(self.zab_top))             self.zab_top destroy();
    if (isDefined(self.zab_bg))              self.zab_bg destroy();

    self.zab_rows = [];
    self.zab_chevrons = [];
    self.zab_items = [];
    self.zab_item_values = [];
    self.zab_cursor = 0;
    self.zab_window = 0;
    self.zab_closing = false;

    self.zab_shadowbar = undefined;
    self.zab_bg = undefined;
    self.zab_outline_top = undefined;
    self.zab_outline_bot = undefined;
    self.zab_top = undefined;
    self.zab_accent = undefined;
    self.zab_title = undefined;
    self.zab_subtitle = undefined;
    self.zab_section = undefined;
    self.zab_page_count = undefined;
    self.zab_header_strip = undefined;
    self.zab_sel_pad = undefined;
    self.zab_sel_bar = undefined;
    self.zab_scroll_rail = undefined;
    self.zab_scroll_thumb = undefined;
    self.zab_footbar = undefined;
    self.zab_foot_strip = undefined;
    self.zab_footer = undefined;
    self.zab_footer2 = undefined;
    self.zab_footer3 = undefined;
    self.zab_exit = undefined;
    self.zab_open_hint = undefined;
    self.zab_open_toast = undefined;
}

/* ============================================================
   NAVIGATION
   ============================================================ */

zab_move(direction)
{
    count = self.zab_items.size;
    if (count == 0)
        return;

    self.zab_cursor += direction;
    if (self.zab_cursor < 0)
        self.zab_cursor = count - 1;
    if (self.zab_cursor >= count)
        self.zab_cursor = 0;

    old_window = self.zab_window;
    if (self.zab_cursor < self.zab_window)
        self.zab_window = self.zab_cursor;
    if (self.zab_cursor >= self.zab_window + self.zab_visible_rows)
        self.zab_window = self.zab_cursor - (self.zab_visible_rows - 1);
    if (old_window != self.zab_window)
        self zab_paint_page();
    else
        self zab_paint_cursor();
}

zab_change_page(page)
{
    if (page == 18)
        self.zab_five_parent = self.zab_page;
    self.zab_page = page;
    self.zab_cursor = 0;
    self.zab_window = 0;
    self zab_define_page();
    self zab_paint_page();
}

zab_back()
{
    if (self.zab_page == 0)
        self zab_close();
    else
        self zab_change_page(self zab_parent_page(self.zab_page));
}

zab_parent_page(page)
{
    if (page == 18 && isDefined(self.zab_five_parent))
        return self.zab_five_parent;
    if (page == 2 || page == 3 || page == 9 || page == 22)
        return 13;
    if (page == 4 || page == 5 || page == 25)
        return 14;
    if (page == 24)
        return 4;
    if (page == 6 || page == 10)
        return 15;
    if (page == 17 || page == 23)
        return 6;
    if (page == 8 || page == 12)
        return 16;
    if (page == 11 || page == 19 || page == 21)
        return 20;
    return 0;
}

/* ============================================================
   PAGE DEFINITIONS
   ============================================================ */

zab_define_page()
{
    self.zab_items = [];
    self.zab_item_values = [];

    if (self.zab_page == 0)
    {
        self zab_add_option("Player / Movement", 1);
        self zab_add_option("Arsenal / Upgrades", 13);
        self zab_add_option("Zombies / Points", 14);
        self zab_add_option("Teleport / World", 15);
        self zab_add_option("Combat / Aimbot", 7);
        self zab_add_option("Controls / HUD", 20);
        self zab_add_option("Stats / Achievements", 16);
        self zab_add_option("Close ZAB Menu", -1);
    }
    else if (self.zab_page == 1)
    {
        if (self.zab_god)
            self.zab_items[0] = "God Mode: ON";
        else
            self.zab_items[0] = "God Mode: OFF";

        if (self.zab_user_notarget)
            self.zab_items[1] = "No Target: ON";
        else
            self.zab_items[1] = "No Target: OFF";

        if (self.zab_noclip)
            self.zab_items[2] = "NoClip: ON";
        else
            self.zab_items[2] = "NoClip: OFF";

        self.zab_items[3] = "NoClip Speed: " + self.zab_noclip_speed;
        if (self.zab_speed)
            self.zab_items[4] = "Speed Boost: ON";
        else
            self.zab_items[4] = "Speed Boost: OFF";
        self.zab_items[5] = "Restore Health";
        self.zab_items[6] = "Return to NoClip Start";
        self.zab_items[7] = "Reset Player Options";
        self.zab_items[8] = "< Back";
    }
    else if (self.zab_page == 2)
    {
        self zab_add_weapon("ray_gun_zm", "Ray Gun");
        self zab_add_weapon("ak74u_zm", "AK74u");
        self zab_add_weapon("mp40_zm", "MP40");
        self zab_add_weapon("galil_zm", "Galil");
        self zab_add_weapon("hk21_zm", "HK21");
        self zab_add_weapon("rpk_zm", "RPK");
        self zab_add_weapon("m1911_zm", "M1911");
        self zab_add_weapon("thundergun_zm", "Thundergun");
        self zab_add_weapon("tesla_gun_zm", "Wunderwaffe DG-2");
        self zab_add_weapon("freezegun_zm", "Winter's Howl");
        self zab_add_weapon("scavenger_zm", "Scavenger");
        self zab_add_weapon("microwavegun_zm", "Wave Gun");
        self zab_add_weapon("31-79_jgb215_zm", "31-79 JGb215");
        if (self.zab_items.size == 0)
            self zab_add_option("No registered weapons", "unavailable");
        self zab_add_option("< Back", "back");
    }
    else if (self.zab_page == 3)
    {
        self.zab_items[0] = "Refill Current Weapon";
        if (self.zab_auto_refill)
            self.zab_items[1] = "Infinite Reserve: ON";
        else
            self.zab_items[1] = "Infinite Reserve: OFF";
        if (self.zab_infinite_clip)
            self.zab_items[2] = "Infinite Clip: ON";
        else
            self.zab_items[2] = "Infinite Clip: OFF";
        self.zab_items[3] = "Rounds: " + self zab_ammo_mode_name();
        self.zab_items[4] = "Drop Current Weapon";
        self.zab_items[5] = "< Back";
    }
    else if (self.zab_page == 4)
    {
        self.zab_items[0] = "Clear Spawned Zombies";
        if (self.zab_zombie_counter)
            self.zab_items[1] = "Zombie Counter: ON";
        else
            self.zab_items[1] = "Zombie Counter: OFF";
        if (self.zab_one_hit)
            self.zab_items[2] = "One-Hit Zombies: ON";
        else
            self.zab_items[2] = "One-Hit Zombies: OFF";
        self.zab_items[3] = "Count Alive Now";
        self.zab_items[4] = "Current Round";
        self.zab_items[5] = "Zombie Spawner";
        self.zab_items[6] = "< Back";
    }
    else if (self.zab_page == 5)
    {
        self.zab_items[0] = "Add 1,000";
        self.zab_items[1] = "Add 5,000";
        self.zab_items[2] = "Add 10,000";
        self.zab_items[3] = "Add 50,000";
        self.zab_items[4] = "Add 100,000";
        self.zab_items[5] = "< Back";
    }
    else if (self.zab_page == 6)
    {
        self.zab_items[0] = "Room Bookmarks (A / B / C)";
        self.zab_items[1] = "Map Location Teleports";
        self.zab_items[2] = "Shoot to TP: " + self zab_on_off(self.zab_shoot_tp);
        self.zab_items[3] = "Save Current Location";
        self.zab_items[4] = "Return to Saved";
        self.zab_items[5] = "Teleport to Crosshair";
        self.zab_items[6] = "Clear Saved Location";
        self.zab_items[7] = "< Back";
    }
    else if (self.zab_page == 7)
    {
        if (self.zab_classic_aimbot)
            self.zab_items[0] = "Classic Aimbot: ON";
        else
            self.zab_items[0] = "Classic Aimbot: OFF";

        if (self.zab_unfair_aimbot)
            self.zab_items[1] = "Unfair Aimbot: ON";
        else
            self.zab_items[1] = "Unfair Aimbot: OFF";

        if (self.zab_aim_always)
            self.zab_items[2] = "Activation: Always";
        else
            self.zab_items[2] = "Activation: ADS";

        if (self.zab_aim_bone == "j_head")
            self.zab_items[3] = "Target: Head";
        else
            self.zab_items[3] = "Target: Torso";

        self.zab_items[4] = "< Back";
    }
    else if (self.zab_page == 8)
    {
        self.zab_items[0] = "Current Map";
        self.zab_items[1] = "Current Weapon";
        self.zab_items[2] = "Player Position";
        self.zab_items[3] = "Current Round";
        self.zab_items[4] = "< Back";
    }
    else if (self.zab_page == 9)
    {
        self zab_add_perk("specialty_armorvest", "Juggernog");
        self zab_add_perk("specialty_fastreload", "Speed Cola");
        self zab_add_perk("specialty_rof", "Double Tap");
        self zab_add_perk("specialty_quickrevive", "Quick Revive");
        self zab_add_perk("specialty_longersprint", "Stamin-Up");
        self zab_add_perk("specialty_detectexplosive", "PhD Flopper");
        self zab_add_perk("specialty_deadshot", "Deadshot Daiquiri");
        self zab_add_perk("specialty_additionalprimaryweapon", "Mule Kick");
        self zab_add_option("Give All Available Perks", "all_perks");
        self zab_add_option("Remove All Perks", "clear_perks");
        self zab_add_option("< Back", "back");
    }
    else if (self.zab_page == 10)
    {
        if (self zab_door_count() > 0)
            self zab_add_option("Unlock All Doors", "doors");
        if (self zab_power_available())
            self zab_add_option("Turn Power On", "power");
        self zab_add_option("< Back", "back");
    }
    else if (self.zab_page == 11)
    {
        if (self.zab_key_mode == 0)
            self.zab_items[0] = "Navigation: WASD";
        else
            self.zab_items[0] = "Navigation: Classic";
        self.zab_items[1] = "Scroll Repeat: " + self.zab_key_repeat + "ms";
        if (self.zab_invert_scroll)
            self.zab_items[2] = "Scroll Direction: Inverted";
        else
            self.zab_items[2] = "Scroll Direction: Normal";
        if (self.zab_swap_horizontal)
            self.zab_items[3] = "Horizontal: A Select / D Back";
        else
            self.zab_items[3] = "Horizontal: D Select / A Back";
        self.zab_items[4] = "NoClip Bind: " + self zab_noclip_bind_name();
        self.zab_items[5] = "Reset Controls";
        self.zab_items[6] = "< Back";
    }
    else if (self.zab_page == 12)
    {
        self.zab_items[0] = "ZAB Session Challenges";
        if (self.zab_achievement_survivor)
            self.zab_items[1] = "Survivor V  [UNLOCKED]";
        else
            self.zab_items[1] = "Survivor V  [LOCKED]";
        if (self.zab_achievement_veteran)
            self.zab_items[2] = "Veteran X  [UNLOCKED]";
        else
            self.zab_items[2] = "Veteran X  [LOCKED]";
        if (self.zab_achievement_rich)
            self.zab_items[3] = "Wealth 10K  [UNLOCKED]";
        else
            self.zab_items[3] = "Wealth 10K  [LOCKED]";
        if (self.zab_achievement_century)
            self.zab_items[4] = "Hunter 100  [UNLOCKED]";
        else
            self.zab_items[4] = "Hunter 100  [LOCKED]";
        if (self.zab_achievement_banker)
            self.zab_items[5] = "Banker 100K  [UNLOCKED]";
        else
            self.zab_items[5] = "Banker 100K  [LOCKED]";
        self.zab_items[6] = "Unlock All Local Badges";
        self.zab_items[7] = "Reset Local Badges";
        self.zab_items[8] = "< Back";
    }
    else if (self.zab_page == 13)
    {
        self zab_add_option("Give Weapons", 2);
        self zab_add_option("Ammo / Impact Rounds", 3);
        self zab_add_option("Custom Weapon FX", 22);
        if (self zab_perks_available())
            self zab_add_option("Give / Remove Perks", 9);
        if (getDvar("mapname") == "zombie_pentagon")
            self zab_add_option("Five: Pack-a-Punch Access", 18);
        self zab_add_option("< Back", "back");
    }
    else if (self.zab_page == 14)
    {
        self zab_add_option("Zombie Controls", 4);
        self zab_add_option("Add Points", 5);
        self zab_add_option("Spawn Power-Ups", 25);
        self zab_add_option("< Back", "back");
    }
    else if (self.zab_page == 15)
    {
        self zab_add_option("Saved / Room Teleports", 6);
        if (self zab_world_available())
            self zab_add_option("Doors / Power", 10);
        if (getDvar("mapname") == "zombie_pentagon")
            self zab_add_option("Five: Rooms / DEFCON", 18);
        self zab_add_option("< Back", "back");
    }
    else if (self.zab_page == 16)
    {
        self zab_add_option("Session Challenges", 12);
        self zab_add_option("Map / Player Information", 8);
        self zab_add_option("< Back", "back");
    }
    else if (self.zab_page == 17)
    {
        self.zab_items[0] = "Save Room A Here";
        self.zab_items[1] = "Teleport to Room A";
        self.zab_items[2] = "Save Room B Here";
        self.zab_items[3] = "Teleport to Room B";
        self.zab_items[4] = "Save Room C Here";
        self.zab_items[5] = "Teleport to Room C";
        self.zab_items[6] = "Return to Spawn";
        self.zab_items[7] = "< Back";
    }
    else if (self.zab_page == 18)
    {
        self.zab_items[0] = "Activate DEFCON 5 (Power First)";
        self.zab_items[1] = "Teleport: Top Floor";
        self.zab_items[2] = "Teleport: War Room";
        self.zab_items[3] = "Teleport: Labs";
        self.zab_items[4] = "Teleport: Pack-a-Punch Room";
        self.zab_items[5] = "DEFCON / Power Status";
        self.zab_items[6] = "< Back";
    }
    else if (self.zab_page == 19)
    {
        self.zab_items[0] = "Animations: " + self zab_on_off(self.zab_animations);
        self.zab_items[1] = "Rainbow Name: " + self zab_on_off(self.zab_watermark_visible);
        self.zab_items[2] = "Panel Opacity: " + self.zab_panel_opacity;
        self.zab_items[3] = "Extra Background Shaders: " + self zab_on_off(self.zab_extra_shaders);
        self.zab_items[4] = "Open HUD Credit: " + self zab_on_off(self.zab_toast_enabled);
        self.zab_items[5] = "< Back";
    }
    else if (self.zab_page == 20)
    {
        self zab_add_option("Menu Binds / NoClip Key", 11);
        self zab_add_option("Theme / HUD Effects", 19);
        self zab_add_option("Safety / Performance", 21);
        self zab_add_option("< Back", "back");
    }
    else if (self.zab_page == 21)
    {
        self.zab_items[0] = "Auto Protection: " + self zab_on_off(self.zab_menu_auto_protect);
        self.zab_items[1] = "Low Effects: " + self zab_on_off(self.zab_low_effects);
        self.zab_items[2] = "Emergency: Close Menu";
        self.zab_items[3] = "< Back";
    }
    else if (self.zab_page == 22)
    {
        self.zab_items[0] = "Impact FX: " + self zab_on_off(self.zab_fx_enabled);
        self.zab_items[1] = "Effect: " + self zab_fx_name();
        self.zab_items[2] = "Ammo Damage Mode: " + self zab_ammo_mode_name();
        self.zab_items[3] = "Nuke Rounds: " + self zab_on_off(self.zab_nuke_rounds);
        self.zab_items[4] = "< Back";
    }
    else if (self.zab_page == 23)
    {
        self zab_build_map_spots();
        self zab_add_option("< Back", "back");
    }
    else if (self.zab_page == 24)
    {
        self.zab_items[0] = "Queue 1 Map Zombie";
        self.zab_items[1] = "Queue 5 Map Zombies";
        self.zab_items[2] = "Queue 10 Map Zombies";
        self.zab_items[3] = "Queued This Round: " + self zab_spawn_pending_text();
        self.zab_items[4] = "Clear All Spawned Zombies";
        self.zab_items[5] = "< Back";
    }
    else if (self.zab_page == 25)
    {
        self.zab_items[0] = "Spawn Active Nuke";
        self.zab_items[1] = "Spawn Max Ammo";
        self.zab_items[2] = "Spawn Insta-Kill";
        self.zab_items[3] = "Spawn Double Points";
        self.zab_items[4] = "Spawn Carpenter";
        self.zab_items[5] = "Spawn Fire Sale";
        self.zab_items[6] = "< Back";
    }
}

/* ============================================================
   HELPERS / NAMES
   ============================================================ */

zab_on_off(value)
{
    if (value) return "ON";
    return "OFF";
}

zab_noclip_bind_name()
{
    if (self.zab_noclip_bind == 1) return "ADS + JUMP";
    if (self.zab_noclip_bind == 2) return "USE + JUMP";
    if (self.zab_noclip_bind == 3) return "USE + MELEE";
    return "OFF";
}

zab_fx_name()
{
    if (self.zab_fx_style == 0) return "Explosion";
    if (self.zab_fx_style == 1) return "Tesla";
    if (self.zab_fx_style == 2) return "Flame";
    if (self.zab_fx_style == 3) return "Blood";
    return "Dust";
}

zab_page_name()
{
    if (self.zab_page == 1) return "PLAYER";
    if (self.zab_page == 2) return "WEAPONS";
    if (self.zab_page == 3) return "AMMO";
    if (self.zab_page == 4) return "ZOMBIES";
    if (self.zab_page == 5) return "POINTS";
    if (self.zab_page == 6) return "TELEPORT";
    if (self.zab_page == 7) return "AIMBOT";
    if (self.zab_page == 8) return "INFORMATION";
    if (self.zab_page == 9) return "PERKS";
    if (self.zab_page == 10) return "WORLD / MAP";
    if (self.zab_page == 11) return "BINDS / THEME";
    if (self.zab_page == 12) return "ACHIEVEMENTS";
    if (self.zab_page == 13) return "ARSENAL / UPGRADES";
    if (self.zab_page == 14) return "ZOMBIES / POINTS";
    if (self.zab_page == 15) return "TELEPORT / WORLD";
    if (self.zab_page == 16) return "STATS / ACHIEVEMENTS";
    if (self.zab_page == 17) return "ROOM BOOKMARKS";
    if (self.zab_page == 18) return "FIVE / DEFCON";
    if (self.zab_page == 19) return "THEME / HUD";
    if (self.zab_page == 20) return "CONTROLS / HUD";
    if (self.zab_page == 21) return "SAFETY / PERFORMANCE";
    if (self.zab_page == 22) return "CUSTOM WEAPON FX";
    if (self.zab_page == 23) return "MAP LOCATIONS";
    if (self.zab_page == 24) return "ZOMBIE SPAWNER";
    if (self.zab_page == 25) return "POWER-UPS / NUKES";
    return "MAIN MENU";
}

zab_add_option(label, value)
{
    index = self.zab_items.size;
    self.zab_items[index] = label;
    self.zab_item_values[index] = value;
}

zab_add_weapon(weapon, label)
{
    if (isDefined(level.zombie_weapons) &&
        isDefined(level.zombie_weapons[weapon]))
        self zab_add_option(label, weapon);
}

zab_perks_available()
{
    triggers = getEntArray("zombie_vending", "targetname");
    return triggers.size > 0;
}

zab_add_perk(perk, label)
{
    triggers = getEntArray("zombie_vending", "targetname");
    for (i = 0; i < triggers.size; i++)
    {
        if (isDefined(triggers[i].script_noteworthy) &&
            triggers[i].script_noteworthy == perk)
        {
            self zab_add_option(label, perk);
            return;
        }
    }
}

zab_door_count()
{
    doors = getEntArray("zombie_door", "targetname");
    debris = getEntArray("zombie_debris", "targetname");
    return doors.size + debris.size;
}

zab_power_available()
{
    map = getDvar("mapname");
    if (map == "zombie_theater" || map == "zombie_pentagon" ||
        map == "zombie_cod5_factory" || map == "nazi_zombie_factory" ||
        map == "zombie_cod5_asylum" || map == "nazi_zombie_asylum" ||
        map == "zombie_cosmodrome" || map == "zombie_coast" ||
        map == "zombie_temple" || map == "zombie_moon")
        return true;
    return false;
}

zab_world_available()
{
    return self zab_door_count() > 0 || self zab_power_available();
}

zab_ammo_mode_name()
{
    if (self.zab_ammo_mode == 1) return "Explosive";
    if (self.zab_ammo_mode == 2) return "Heavy";
    if (self.zab_ammo_mode == 3) return "One-Hit";
    if (self.zab_ammo_mode == 4) return "Burn DOT";
    return "Normal";
}

/* ============================================================
   PAINT
   ============================================================ */

zab_paint_page()
{
    if (!self.zab_open || !isDefined(self.zab_section))
        return;

    self.zab_section setText(self zab_page_name());

    if (self.zab_key_mode == 0 && self.zab_swap_horizontal)
    {
        self.zab_footer  setText("W/S  SCROLL");
        self.zab_footer2 setText("A  SELECT");
        self.zab_footer3 setText("D  BACK");
    }
    else if (self.zab_key_mode == 0)
    {
        self.zab_footer  setText("W/S  SCROLL");
        self.zab_footer2 setText("D  SELECT");
        self.zab_footer3 setText("A  BACK");
    }
    else
    {
        self.zab_footer  setText("FIRE  DOWN");
        self.zab_footer2 setText("ADS  UP");
        self.zab_footer3 setText("USE  SELECT");
    }

    self zab_paint_cursor();
}

zab_paint_cursor()
{
    if (!self.zab_open || !isDefined(self.zab_sel_pad))
        return;

    row_y = 108 + ((self.zab_cursor - self.zab_window) * 24);

    if (self.zab_animations)
    {
        self.zab_sel_pad moveOverTime(0.09);
        self.zab_sel_bar moveOverTime(0.09);
    }
    self.zab_sel_pad.y = row_y;
    self.zab_sel_bar.y = row_y;

    if (isDefined(self.zab_scroll_thumb))
    {
        if (self.zab_items.size > self.zab_visible_rows)
        {
            ratio = self.zab_window /
                (self.zab_items.size - self.zab_visible_rows);
            if (ratio < 0) ratio = 0;
            if (ratio > 1) ratio = 1;
            self.zab_scroll_thumb.y = 108 + (ratio * (168 - 28));
            self.zab_scroll_thumb.alpha = 0.95;
        }
        else
            self.zab_scroll_thumb.alpha = 0;
    }

    if (isDefined(self.zab_page_count))
        self.zab_page_count setText(
            (self.zab_cursor + 1) + " / " + self.zab_items.size);

    for (i = 0; i < self.zab_visible_rows; i++)
    {
        item = i + self.zab_window;

        if (item < self.zab_items.size)
        {
            label = self.zab_items[item];
            is_sel = (item == self.zab_cursor);

            if (is_sel)
            {
                self.zab_rows[i] setText("▸ " + label);
                self.zab_rows[i].color = (0.42, 1.00, 0.62);
            }
            else
            {
                self.zab_rows[i] setText("   " + label);
                self.zab_rows[i].color = (0.86, 0.96, 0.88);
            }
            self.zab_rows[i].alpha = 1;

            val = self.zab_item_values[item];
            is_back = (item == self.zab_items.size - 1 &&
                label == "< Back");

            if (is_back)
                self.zab_chevrons[i] setText("");
            else if (isDefined(val) && isInt(val) && val >= 0)
                self.zab_chevrons[i] setText("›");
            else if (val == "all_perks" || val == "clear_perks" ||
                val == "doors" || val == "power")
                self.zab_chevrons[i] setText("›");
            else
                self.zab_chevrons[i] setText("");
        }
        else
        {
            self.zab_rows[i] setText(" ");
            self.zab_rows[i].alpha = 0;
            self.zab_chevrons[i] setText("");
        }
    }
}

/* ============================================================
   ACTIVATION
   ============================================================ */

zab_activate()
{
    page = self.zab_page;
    index = self.zab_cursor;

    if (page == 0)
    {
        choice = self.zab_item_values[index];
        if (choice == -1)
            self zab_close();
        else
            self zab_change_page(choice);
        return;
    }

    if (index == self.zab_items.size - 1)
    {
        self zab_back();
        return;
    }

    if (page == 13 || page == 14 || page == 15 || page == 16 || page == 20)
    {
        self zab_change_page(self.zab_item_values[index]);
        return;
    }

    if (page == 1)
    {
        if (index == 0)
        {
            self.zab_god = !self.zab_god;
            if (self.zab_god || self.zab_menu_invuln_applied)
                self enableInvulnerability();
            else if (!self.zab_god)
                self disableInvulnerability();
        }
        else if (index == 1)
        {
            self.zab_user_notarget = !self.zab_user_notarget;
            self.ignoreme = self.zab_user_notarget ||
                self.zab_was_ignored ||
                (self.zab_menu_auto_protect && self.zab_open);
        }
        else if (index == 2)
            self zab_toggle_noclip();
        else if (index == 3)
        {
            self.zab_noclip_speed += 5;
            if (self.zab_noclip_speed > 30)
                self.zab_noclip_speed = 5;
        }
        else if (index == 4)
        {
            self.zab_speed = !self.zab_speed;
            if (!self.zab_open)
            {
                if (self.zab_speed)
                    self setMoveSpeedScale(1.5);
                else
                    self setMoveSpeedScale(1);
            }
        }
        else if (index == 5)
        {
            if (isDefined(self.maxhealth))
                self.health = self.maxhealth;
            else
                self.health = 100;
            self iPrintLn("^2ZAB ^7Health restored");
        }
        else if (index == 6)
        {
            if (isDefined(self.zab_noclip_return))
                self zab_warp(self.zab_noclip_return, "NoClip start");
            else
                self iPrintLn("^2ZAB ^7NoClip start not saved");
        }
        else if (index == 7)
        {
            self.zab_god = false;
            self.zab_user_notarget = false;
            self.zab_noclip = false;
            self.zab_speed = false;
            self.ignoreme = self.zab_was_ignored ||
                (self.zab_menu_auto_protect && self.zab_open);
            if (!self.zab_menu_invuln_applied)
                self disableInvulnerability();
            self iPrintLn("^2ZAB ^7Player options reset");
        }
    }
    else if (page == 2)
    {
        choice = self.zab_item_values[index];
        if (choice != "unavailable")
            self zab_give_weapon(choice, self.zab_items[index]);
    }
    else if (page == 3)
    {
        if (index == 0)
        {
            current = self getCurrentWeapon();
            if (isDefined(current) && current != "none")
                self giveMaxAmmo(current);
            self iPrintLn("^2ZAB ^7Ammo refilled");
        }
        else if (index == 1)
        {
            self.zab_auto_refill = !self.zab_auto_refill;
        }
        else if (index == 2)
            self.zab_infinite_clip = !self.zab_infinite_clip;
        else if (index == 3)
        {
            self.zab_ammo_mode++;
            if (self.zab_ammo_mode > 4)
                self.zab_ammo_mode = 0;
        }
        else if (index == 4)
        {
            current = self getCurrentWeapon();
            if (isDefined(current) && current != "none")
                self takeWeapon(current);
        }
    }
    else if (page == 4)
    {
        if (index == 0)
        {
            self thread zab_clear_zombies();
        }
        else if (index == 1)
        {
            self.zab_zombie_counter = !self.zab_zombie_counter;
            if (!self.zab_zombie_counter && isDefined(self.zab_count_hud))
            {
                self.zab_count_hud destroy();
                self.zab_count_hud = undefined;
            }
        }
        else if (index == 2)
            self.zab_one_hit = !self.zab_one_hit;
        else if (index == 3)
        {
            zombies = getAiArray("axis");
            self iPrintLn("^2ZAB ^7Zombies alive: " + zombies.size);
        }
        else if (index == 4)
            self zab_print_round();
        else if (index == 5)
            self zab_change_page(24);
    }
    else if (page == 5)
    {
        amount = 1000;
        if (index == 1) amount = 5000;
        if (index == 2) amount = 10000;
        if (index == 3) amount = 50000;
        if (index == 4) amount = 100000;
        self maps\_zombiemode_score::add_to_player_score(amount);
        self iPrintLn("^2ZAB ^7Points added: " + amount);
    }
    else if (page == 6)
    {
        if (index == 0)
            self zab_change_page(17);
        else if (index == 1)
            self zab_change_page(23);
        else if (index == 2)
            self.zab_shoot_tp = !self.zab_shoot_tp;
        else if (index == 3)
        {
            self.zab_saved_origin = self.origin;
            self iPrintLn("^2ZAB ^7Location saved");
        }
        else if (index == 4)
        {
            if (isDefined(self.zab_saved_origin))
                self zab_warp(self.zab_saved_origin, "saved position");
            else
                self iPrintLn("^2ZAB ^7Save a location first");
        }
        else if (index == 5)
            self zab_teleport_to_crosshair();
        else if (index == 6)
        {
            self.zab_saved_origin = undefined;
            self iPrintLn("^2ZAB ^7Saved location cleared");
        }
    }
    else if (page == 7)
    {
        if (index == 0)
        {
            self.zab_classic_aimbot = !self.zab_classic_aimbot;
            if (!self.zab_classic_aimbot)
                self.zab_unfair_aimbot = false;
        }
        else if (index == 1)
        {
            self.zab_unfair_aimbot = !self.zab_unfair_aimbot;
            if (self.zab_unfair_aimbot)
                self.zab_classic_aimbot = true;
        }
        else if (index == 2)
            self.zab_aim_always = !self.zab_aim_always;
        else if (index == 3)
        {
            if (self.zab_aim_bone == "j_head")
                self.zab_aim_bone = "j_spine4";
            else
                self.zab_aim_bone = "j_head";
        }
    }
    else if (page == 8)
    {
        if (index == 0)
            self iPrintLn("^2ZAB ^7Map: " + getDvar("mapname"));
        else if (index == 1)
            self iPrintLn("^2ZAB ^7Weapon: " + self getCurrentWeapon());
        else if (index == 2)
        {
            pos = self.origin;
            self iPrintLn("^2ZAB ^7X " + pos[0] + " Y " + pos[1] + " Z " + pos[2]);
        }
        else
            self zab_print_round();
    }
    else if (page == 9)
    {
        choice = self.zab_item_values[index];
        if (choice == "all_perks")
        {
            for (i = 0; i < self.zab_item_values.size - 3; i++)
                self zab_grant_perk(self.zab_item_values[i]);
            self iPrintLn("^2ZAB ^7Available perks granted");
        }
        else if (choice == "clear_perks")
        {
            self clearPerks();
            self iPrintLn("^2ZAB ^7Perks cleared");
        }
        else
        {
            self zab_grant_perk(choice);
            self iPrintLn("^2ZAB ^7Perk granted: " + self.zab_items[index]);
        }
    }
    else if (page == 10)
    {
        choice = self.zab_item_values[index];
        if (choice == "doors")
            self thread zab_unlock_all_doors();
        else if (choice == "power")
        {
            flag_set("power_on");
            self iPrintLn("^2ZAB ^7Power activated");
        }
    }
    else if (page == 11)
    {
        if (index == 0)
            self.zab_key_mode = !self.zab_key_mode;
        else if (index == 1)
        {
            self.zab_key_repeat -= 35;
            if (self.zab_key_repeat < 60)
                self.zab_key_repeat = 200;
        }
        else if (index == 2)
            self.zab_invert_scroll = !self.zab_invert_scroll;
        else if (index == 3)
            self.zab_swap_horizontal = !self.zab_swap_horizontal;
        else if (index == 4)
        {
            self.zab_noclip_bind++;
            if (self.zab_noclip_bind > 3)
                self.zab_noclip_bind = 0;
        }
        else if (index == 5)
        {
            self.zab_key_mode = 0;
            self.zab_key_repeat = 165;
            self.zab_invert_scroll = false;
            self.zab_swap_horizontal = false;
            self.zab_noclip_bind = 1;
        }
    }
    else if (page == 17)
    {
        if (index == 6)
        {
            if (isDefined(self.zab_spawn_origin))
                self zab_warp(self.zab_spawn_origin, "spawn");
            else
                self iPrintLn("^2ZAB ^7Spawn point unavailable");
        }
        else
        {
            slot = 0;
            if (index == 2 || index == 3)
                slot = 1;
            else if (index == 4 || index == 5)
                slot = 2;
            if (index == 0 || index == 2 || index == 4)
            {
                self.zab_room_slots[slot] = self.origin;
                self iPrintLn("^2ZAB ^7Room bookmark saved");
            }
            else if (isDefined(self.zab_room_slots[slot]))
                self zab_warp(self.zab_room_slots[slot], "room bookmark");
            else
                self iPrintLn("^2ZAB ^7Save this room slot first");
        }
    }
    else if (page == 18)
    {
        if (index == 0)
            self thread zab_five_auto_defcon();
        else if (index == 1)
            self zab_five_warp(0);
        else if (index == 2)
            self zab_five_warp(1);
        else if (index == 3)
            self zab_five_warp(2);
        else if (index == 4)
            self zab_five_warp(3);
        else if (index == 5)
            self zab_five_status();
    }
    else if (page == 19)
    {
        if (index == 0)
            self.zab_animations = !self.zab_animations;
        else if (index == 1)
            self.zab_watermark_visible = !self.zab_watermark_visible;
        else if (index == 2)
        {
            self.zab_panel_opacity -= 0.09;
            if (self.zab_panel_opacity < 0.62)
                self.zab_panel_opacity = 0.96;
            self.zab_bg.alpha = self.zab_panel_opacity;
        }
        else if (index == 3)
            self.zab_extra_shaders = !self.zab_extra_shaders;
        else if (index == 4)
            self.zab_toast_enabled = !self.zab_toast_enabled;
    }
    else if (page == 21)
    {
        if (index == 0)
        {
            self.zab_menu_auto_protect = !self.zab_menu_auto_protect;
            self.ignoreme = self.zab_user_notarget || self.zab_was_ignored ||
                (self.zab_menu_auto_protect && self.zab_open);
            self.zab_menu_invuln_applied = self.zab_menu_auto_protect;
            if (self.zab_god || self.zab_menu_invuln_applied)
                self enableInvulnerability();
            else
                self disableInvulnerability();
        }
        else if (index == 1)
            self.zab_low_effects = !self.zab_low_effects;
        else if (index == 2)
        {
            self zab_close();
            return;
        }
    }
    else if (page == 22)
    {
        if (index == 0)
            self.zab_fx_enabled = !self.zab_fx_enabled;
        else if (index == 1)
        {
            self.zab_fx_style++;
            if (self.zab_fx_style > 4)
                self.zab_fx_style = 0;
        }
        else if (index == 2)
        {
            self.zab_ammo_mode++;
            if (self.zab_ammo_mode > 4)
                self.zab_ammo_mode = 0;
        }
        else if (index == 3)
            self.zab_nuke_rounds = !self.zab_nuke_rounds;
    }
    else if (page == 23)
    {
        if (index < self.zab_map_spots.size &&
            isDefined(self.zab_map_spots[index]))
            self zab_warp(self.zab_map_spots[index], "map location");
    }
    else if (page == 24)
    {
        if (index == 0)
            self zab_queue_zombies(1);
        else if (index == 1)
            self zab_queue_zombies(5);
        else if (index == 2)
            self zab_queue_zombies(10);
        else if (index == 4)
            self thread zab_clear_zombies();
    }
    else if (page == 25)
    {
        if (index == 0)
            self zab_spawn_powerup("nuke", true);
        else if (index == 1)
            self zab_spawn_powerup("full_ammo", false);
        else if (index == 2)
            self zab_spawn_powerup("insta_kill", false);
        else if (index == 3)
            self zab_spawn_powerup("double_points", false);
        else if (index == 4)
            self zab_spawn_powerup("carpenter", false);
        else if (index == 5)
            self zab_spawn_powerup("fire_sale", false);
    }
    else if (page == 12)
    {
        if (index == 6)
        {
            self.zab_achievement_survivor = true;
            self.zab_achievement_veteran = true;
            self.zab_achievement_rich = true;
            self.zab_achievement_century = true;
            self.zab_achievement_banker = true;
            self iPrintLn("^2ZAB ^7All local badges unlocked (not platform awards)");
        }
        else if (index == 7)
        {
            self.zab_achievement_survivor = false;
            self.zab_achievement_veteran = false;
            self.zab_achievement_rich = false;
            self.zab_achievement_century = false;
            self.zab_achievement_banker = false;
            self iPrintLn("^2ZAB ^7Local badges reset");
        }
        else
            self iPrintLn("^2ZAB ^7Local session badges, not platform achievements");
    }

    self zab_define_page();
    if (self.zab_cursor >= self.zab_items.size)
        self.zab_cursor = self.zab_items.size - 1;
    if (self.zab_cursor < self.zab_window)
        self.zab_window = self.zab_cursor;
    self zab_paint_page();
}

/* ============================================================
   ACTIONS
   ============================================================ */

zab_print_round()
{
    if (isDefined(level.round_number))
        self iPrintLn("^2ZAB ^7Round: " + level.round_number);
    else
        self iPrintLn("^2ZAB ^7Round information unavailable");
}

zab_spawn_pending_text()
{
    if (isDefined(level.zombie_total))
        return level.zombie_total;
    return "Unavailable";
}

zab_queue_zombies(amount)
{
    if (!isDefined(level.zombie_total) || !isDefined(level.enemy_spawns) ||
        level.enemy_spawns.size == 0)
    {
        self iPrintLn("^2ZAB ^7Map spawner not ready");
        return;
    }
    if (level.zombie_total + amount > 50)
    {
        self iPrintLn("^2ZAB ^7Spawn queue capped at 50");
        return;
    }
    level.zombie_total += amount;
    self iPrintLn("^2ZAB ^7Queued " + amount + " zombies through round spawner");
}

zab_warp(position, label)
{
    if (!isDefined(position))
    {
        self iPrintLn("^2ZAB ^7Teleport destination unavailable");
        return;
    }

    if (self.zab_open)
        self.zab_lock_origin = position;
    self setVelocity((0, 0, 0));
    self setOrigin(position);
    self iPrintLn("^2ZAB ^7Teleported: " + label);
}

zab_add_map_spot(label, position)
{
    if (!isDefined(position) || self.zab_items.size >= 7)
        return;
    index = self.zab_items.size;
    self.zab_map_spots[index] = position;
    self zab_add_option(label, index);
}

zab_perk_spot_name(perk)
{
    if (perk == "specialty_armorvest") return "Juggernog Room";
    if (perk == "specialty_fastreload") return "Speed Cola Room";
    if (perk == "specialty_rof") return "Double Tap Room";
    if (perk == "specialty_quickrevive") return "Quick Revive Room";
    if (perk == "specialty_longersprint") return "Stamin-Up Room";
    if (perk == "specialty_detectexplosive") return "PhD Flopper Room";
    if (perk == "specialty_deadshot") return "Deadshot Room";
    if (perk == "specialty_additionalprimaryweapon") return "Mule Kick Room";
    return "Perk Machine Room";
}

zab_build_map_spots()
{
    self.zab_map_spots = [];
    if (isDefined(self.zab_spawn_origin))
        self zab_add_map_spot("Starting Room", self.zab_spawn_origin);

    power = getEntArray("use_elec_switch", "targetname");
    if (power.size > 0 && isDefined(power[0].origin))
        self zab_add_map_spot("Power Switch", power[0].origin + (0, 0, 36));
    upgrade = getEntArray("zombie_vending_upgrade", "targetname");
    if (upgrade.size > 0 && isDefined(upgrade[0].origin) &&
        getDvar("mapname") != "zombie_pentagon")
        self zab_add_map_spot("Pack-a-Punch Machine", upgrade[0].origin + (0, 0, 36));

    perks = getEntArray("zombie_vending", "targetname");
    for (i = 0; i < perks.size && i < 10 && self.zab_items.size < 7; i++)
    {
        if (isDefined(perks[i]) && isDefined(perks[i].origin) &&
            isDefined(perks[i].script_noteworthy))
            self zab_add_map_spot(self zab_perk_spot_name(perks[i].script_noteworthy),
                perks[i].origin + (0, 0, 36));
    }
    if (self.zab_items.size == 0)
        self zab_add_option("No known map locations yet", "unavailable");
}

zab_five_status()
{
    if (getDvar("mapname") != "zombie_pentagon")
    {
        self iPrintLn("^2ZAB ^7Five features unavailable on this map");
        return;
    }
    if (flag("power_on"))
        self iPrintLn("^2ZAB ^7Power: ON");
    else
        self iPrintLn("^2ZAB ^7Power: OFF");
    if (isDefined(level.defcon_level))
        self iPrintLn("^2ZAB ^7DEFCON: " + level.defcon_level);
}

zab_five_auto_defcon()
{
    self endon("disconnect");
    if (self.zab_busy_defcon || getTime() - self.zab_defcon_last < 1800)
        return;
    if (getDvar("mapname") != "zombie_pentagon")
        return;
    if (!flag("power_on"))
    {
        self iPrintLn("^2ZAB ^7Five: activate power first");
        return;
    }
    if (flag("defcon_active"))
    {
        self iPrintLn("^2ZAB ^7DEFCON already active - use a teleporter");
        return;
    }
    switches = getEntArray("punch_switch", "targetname");
    if (switches.size < 4)
    {
        self iPrintLn("^2ZAB ^7DEFCON switches not initialized");
        return;
    }
    self.zab_busy_defcon = true;
    self.zab_defcon_last = getTime();
    for (i = 0; i < switches.size && i < 4; i++)
    {
        if (isDefined(switches[i]) && !flag("defcon_active"))
            switches[i] notify("trigger", self);
        wait 0.26;
    }
    if (flag("defcon_active"))
        self iPrintLn("^2ZAB ^7DEFCON 5: Pack-a-Punch route active");
    else
        self iPrintLn("^2ZAB ^7DEFCON not ready; try the War Room switches");
    self.zab_busy_defcon = false;
}

zab_five_warp(spot)
{
    if (getDvar("mapname") != "zombie_pentagon")
        return;
    if (spot == 0 && isDefined(level.portal_top))
        self zab_warp(level.portal_top.origin + (0, 0, 38), "top floor");
    else if (spot == 1 && isDefined(level.portal_mid))
        self zab_warp(level.portal_mid.origin + (0, 0, 38), "war room");
    else if (spot == 2 && isDefined(level.portal_bottom) &&
        level.portal_bottom.size > 0)
        self zab_warp(level.portal_bottom[0].origin + (0, 0, 38), "labs");
    else if (spot == 3)
    {
        if (!flag("defcon_active"))
        {
            self iPrintLn("^2ZAB ^7Open DEFCON 5 before entering Pack room");
            return;
        }
        if (isDefined(level.portal_pack))
            self zab_warp(level.portal_pack.origin + (0, 0, 38), "Panic Room");
        else
            self iPrintLn("^2ZAB ^7Panic Room portal not ready");
    }
    else
        self iPrintLn("^2ZAB ^7Five portal not ready (power may be off)");
}

zab_give_weapon(name, label)
{
    if (!isDefined(level.zombie_weapons) ||
        !isDefined(level.zombie_weapons[name]))
    {
        self iPrintLn("^2ZAB ^7Weapon unavailable on this map");
        return;
    }
    self giveWeapon(name);
    self giveMaxAmmo(name);
    self switchToWeapon(name);
    self iPrintLn("^2ZAB ^7" + label + " (if available on this map)");
}

zab_grant_perk(perk)
{
    if (!self hasPerk(perk))
        self maps\_zombiemode_perks::give_perk(perk, false);
}

zab_spawn_powerup(type, activate)
{
    if (!isDefined(level.zombie_powerups) ||
        !isDefined(level.zombie_powerups[type]))
    {
        self iPrintLn("^2ZAB ^7Power-up unavailable on this map");
        return false;
    }
    if (getTime() - self.zab_last_powerup_drop < 1200)
    {
        self iPrintLn("^2ZAB ^7Wait before spawning another power-up");
        return false;
    }
    self.zab_last_powerup_drop = getTime();
    if (activate)
        point = self.origin;
    else
        point = self.origin + (anglesToForward(self getPlayerAngles()) * 96);
    level thread maps\_zombiemode_powerups::specific_powerup_drop(type, point);
    self iPrintLn("^2ZAB ^7Power-up spawned: " + type);
    return true;
}

/* ============================================================
   LOOPS
   ============================================================ */

zab_refill_loop()
{
    self endon("disconnect");

    while (self.zab_running)
    {
        if (self.zab_auto_refill || self.zab_infinite_clip)
        {
            current = self getCurrentWeapon();
            if (isDefined(current) && current != "none")
            {
                if (self.zab_auto_refill)
                    self giveMaxAmmo(current);
                if (self.zab_infinite_clip)
                {
                    maximum = weaponClipSize(current);
                    if (maximum > 0)
                        self setWeaponAmmoClip(current, maximum);
                }
            }
            wait 0.18;
        }
        else
            wait 0.60;
    }
}

zab_ammo_effect_loop()
{
    self endon("disconnect");

    last_attack = false;
    while (self.zab_running)
    {
        if (self.zab_ammo_mode == 0 && !self.zab_fx_enabled &&
            !self.zab_nuke_rounds && !self.zab_shoot_tp)
        {
            last_attack = false;
            wait 0.18;
            continue;
        }
        attack = self attackButtonPressed();
        if ((self.zab_ammo_mode > 0 || self.zab_fx_enabled ||
            self.zab_nuke_rounds || self.zab_shoot_tp) &&
            !self.zab_open && attack && !last_attack)
        {
            start = self getEye();
            finish = start + (anglesToForward(self getPlayerAngles()) * 3500);
            trace = bulletTrace(start, finish, false, self);
            if (isDefined(trace) && isDefined(trace["position"]))
            {
                hit = trace["position"];
                if (self.zab_nuke_rounds)
                    self zab_trigger_shot_nuke();
                if (self.zab_fx_enabled &&
                    getTime() - self.zab_last_fx >= 220)
                {
                    self.zab_last_fx = getTime();
                    self zab_impact_fx(hit);
                }

                if (self.zab_ammo_mode == 1)
                {
                    radiusDamage(hit, 135, 300, 30, self);
                }
                else if (isDefined(trace["entity"]))
                {
                    victim = trace["entity"];
                    if (isDefined(victim.health) && victim.health > 0)
                    {
                        if (self.zab_ammo_mode == 2)
                            victim doDamage(1250, hit, self);
                        else if (self.zab_ammo_mode == 3)
                            victim doDamage(victim.health + 1000, hit, self);
                        else if (self.zab_ammo_mode == 4)
                            self thread zab_burn_target(victim);
                    }
                }

                if (self.zab_shoot_tp &&
                    getTime() - self.zab_last_shoot_tp >= 650 &&
                    isDefined(trace["fraction"]) && trace["fraction"] < 0.98 &&
                    distance(start, hit) >= 80)
                {
                    landing = hit + (0, 0, 42);
                    if (isDefined(trace["normal"]))
                        landing += trace["normal"] * 24;
                    self.zab_last_shoot_tp = getTime();
                    self zab_warp(landing, "shoot-to-TP impact");
                }
            }
        }

        last_attack = attack;
        wait 0.05;
    }
}

zab_impact_fx(hit)
{
    if (!isDefined(level._effect))
        return;
    if (self.zab_fx_style == 0 && isDefined(level._effect["def_explosion"]))
        playFX(level._effect["def_explosion"], hit);
    else if (self.zab_fx_style == 1 && isDefined(level._effect["tesla_head_light"]))
        playFX(level._effect["tesla_head_light"], hit);
    else if (self.zab_fx_style == 2 && isDefined(level._effect["character_fire_pain_sm"]))
        playFX(level._effect["character_fire_pain_sm"], hit);
    else if (self.zab_fx_style == 3 && isDefined(level._effect["bloodspurt"]))
        playFX(level._effect["bloodspurt"], hit);
    else if (self.zab_fx_style == 4 && isDefined(level._effect["rise_burst"]))
        playFX(level._effect["rise_burst"], hit);
}

zab_burn_target(victim)
{
    self endon("disconnect");

    if (!isDefined(victim) || !isAlive(victim) ||
        (isDefined(victim.zab_burn_active) && victim.zab_burn_active))
        return;
    victim.zab_burn_active = true;

    for (tick = 0; tick < 5; tick++)
    {
        if (!isDefined(victim) || !isAlive(victim))
            return;
        victim doDamage(75, victim.origin, self);
        wait 0.35;
    }
    if (isDefined(victim))
        victim.zab_burn_active = false;
}

zab_one_hit_loop()
{
    self endon("disconnect");

    while (self.zab_running)
    {
        if (self.zab_one_hit)
        {
            zombies = getAiArray("axis");
            for (i = 0; i < zombies.size; i++)
            {
                if (isDefined(zombies[i]) && isAlive(zombies[i]) && zombies[i].health > 1)
                    zombies[i].health = 1;
            }
            wait 0.5;
        }
        else
            wait 1.0;
    }
}

zab_achievement_loop()
{
    self endon("disconnect");

    while (self.zab_running)
    {
        if (isDefined(level.round_number) && level.round_number >= 5 &&
            !self.zab_achievement_survivor)
        {
            self.zab_achievement_survivor = true;
            self iPrintLn("^2ZAB ^7Challenge: Survivor V");
        }
        if (isDefined(level.round_number) && level.round_number >= 10 &&
            !self.zab_achievement_veteran)
        {
            self.zab_achievement_veteran = true;
            self iPrintLn("^2ZAB ^7Challenge: Veteran X");
        }
        if (isDefined(self.score) && self.score >= 10000 &&
            !self.zab_achievement_rich)
        {
            self.zab_achievement_rich = true;
            self iPrintLn("^2ZAB ^7Challenge: Wealth 10K");
        }
        if (isDefined(self.kills) && self.kills >= 100 &&
            !self.zab_achievement_century)
        {
            self.zab_achievement_century = true;
            self iPrintLn("^2ZAB ^7Challenge: Hunter 100");
        }
        if (isDefined(self.score) && self.score >= 100000 &&
            !self.zab_achievement_banker)
        {
            self.zab_achievement_banker = true;
            self iPrintLn("^2ZAB ^7Challenge: Banker 100K");
        }
        wait 2;
    }
}

zab_counter_loop()
{
    self endon("disconnect");

    last_count = -1;
    while (self.zab_running)
    {
        if (self.zab_zombie_counter && !self.zab_open)
        {
            if (!isDefined(self.zab_count_hud))
            {
                self.zab_count_hud = self zab_text("ZOMBIES  0", 325, 65,
                    1.00, (0.35, 0.95, 0.55), 8);
                last_count = -1;
            }

            zombies = getAiArray("axis");
            if (last_count != zombies.size)
            {
                self.zab_count_hud setText("ZOMBIES  " + zombies.size);
                last_count = zombies.size;
            }
        }
        else
        {
            if (isDefined(self.zab_count_hud))
            {
                self.zab_count_hud destroy();
                self.zab_count_hud = undefined;
            }
            last_count = -1;
        }

        wait 0.5;
    }
}

zab_watermark_loop()
{
    self endon("disconnect");

    self.zab_watermark = newClientHudElem(self);
    self.zab_watermark.horzAlign = "right";
    self.zab_watermark.vertAlign = "top";
    self.zab_watermark.alignX = "right";
    self.zab_watermark.alignY = "top";
    self.zab_watermark.x = -20;
    self.zab_watermark.y = 20;
    self.zab_watermark.font = "default";
    self.zab_watermark.fontScale = 1.05;
    self.zab_watermark.alpha = 0.92;
    self.zab_watermark.sort = 6;
    self.zab_watermark.hideWhenInMenu = true;
    self.zab_watermark setText("ZAB MENU");

    colors = [];
    colors[0] = (0.15, 0.55, 0.25);
    colors[1] = (0.20, 0.65, 0.30);
    colors[2] = (0.25, 0.75, 0.35);
    colors[3] = (0.30, 0.85, 0.40);
    colors[4] = (0.35, 0.95, 0.50);
    colors[5] = (0.50, 1.00, 0.60);
    colors[6] = (0.65, 1.00, 0.70);
    colors[7] = (0.55, 0.95, 0.65);
    colors[8] = (0.40, 0.85, 0.55);
    colors[9] = (0.25, 0.70, 0.38);

    index = 0;
    for (;;)
    {
        self.zab_watermark.color = colors[index];
        if (self.zab_watermark_visible)
            self.zab_watermark.alpha = 0.92;
        else
            self.zab_watermark.alpha = 0;
        index++;
        if (index >= colors.size)
            index = 0;
        if (self.zab_low_effects)
            wait 1.0;
        else
            wait 0.20;
    }
}

zab_aimbot_loop()
{
    self endon("disconnect");

    old_attack = false;
    for (;;)
    {
        if ((!self.zab_classic_aimbot && !self.zab_unfair_aimbot) ||
            self.zab_open)
        {
            old_attack = false;
            wait 0.18;
            continue;
        }
        attack = self attackButtonPressed();

        aim_active = self.zab_classic_aimbot &&
            (self.adsButtonPressed() || self.zab_aim_always);
        shoot_active = self.zab_unfair_aimbot && attack && !old_attack;

        if (aim_active || shoot_active)
        {
            target = self zab_nearest_zombie();
            if (isDefined(target))
            {
                hit = target getTagOrigin(self.zab_aim_bone);
                if (aim_active)
                {
                    eye = self getEye();
                    self setPlayerAngles(vectorToAngles(hit - eye));
                }

                if (shoot_active)
                {
                    weapon = self getCurrentWeapon();
                    if (isDefined(weapon) && weapon != "none")
                        MagicBullet(weapon, hit + (0, 0, 5), hit, self);
                }
            }
        }

        old_attack = attack;
        wait 0.05;
    }
}

zab_nearest_zombie()
{
    zombies = getAiArray("axis");
    best = undefined;
    best_distance = 100000000;

    for (i = 0; i < zombies.size; i++)
    {
        zombie = zombies[i];
        if (!isDefined(zombie) || !isAlive(zombie))
            continue;

        d = distance(self.origin, zombie.origin);
        if (d < best_distance)
        {
            best_distance = d;
            best = zombie;
        }
    }

    return best;
}

zab_clear_zombies()
{
    self endon("disconnect");

    if (self.zab_busy_clear)
        return;
    self.zab_busy_clear = true;

    zombies = getAiArray("axis");
    for (i = 0; i < zombies.size && i < 128; i++)
    {
        if (isDefined(zombies[i]) && isAlive(zombies[i]))
            zombies[i] doDamage(zombies[i].health + 1000, zombies[i].origin, self);

        wait 0.05;
    }
    self iPrintLn("^2ZAB ^7Spawned zombies cleared");
    self.zab_busy_clear = false;
}

zab_toggle_noclip()
{
    self.zab_noclip = !self.zab_noclip;
    if (self.zab_noclip)
    {
        self.zab_noclip_return = self.origin;
        if (!self.zab_noclip_worker_running)
        {
            self.zab_noclip_worker_running = true;
            self thread zab_noclip_loop();
        }
        self iPrintLn("^2ZAB ^7NoClip ON: WASD / Jump up / Melee down");
    }
    else
    {
        self setVelocity((0, 0, 0));
        self iPrintLn("^2ZAB ^7NoClip OFF");
    }
}

zab_noclip_loop()
{
    self endon("disconnect");

    while (self.zab_running && self.zab_noclip)
    {
        if (!self.zab_open && !self.zab_lock_controls)
        {
            movement = self getNormalizedMovement();
            angles = self getPlayerAngles();
            forward = anglesToForward((0, angles[1], 0));
            right = anglesToRight((0, angles[1], 0));
            step = self.zab_noclip_speed * 0.5;
            next = self.origin + (forward * (movement[0] * step));
            next += right * (movement[1] * step);
            if (self jumpButtonPressed())
                next += (0, 0, step);
            if (self meleeButtonPressed())
                next -= (0, 0, step);
            self setVelocity((0, 0, 0));
            if (distance(self.origin, next) > 0.02)
                self setOrigin(next);
        }
        wait 0.025;
    }
    self.zab_noclip_worker_running = false;
}

zab_trigger_shot_nuke()
{
    if (!self.zab_nuke_rounds || !isDefined(level.zombie_powerups) ||
        !isDefined(level.zombie_powerups["nuke"]) ||
        getTime() - self.zab_last_nuke_shot < 1500)
        return;

    self.zab_last_nuke_shot = getTime();
    level thread maps\_zombiemode_powerups::specific_powerup_drop("nuke", self.origin);
}

zab_teleport_to_crosshair()
{
    start = self getEye();
    finish = start + (anglesToForward(self getPlayerAngles()) * 8000);
    trace = bulletTrace(start, finish, false, self);

    if (!isDefined(trace) || !isDefined(trace["position"]) ||
        (isDefined(trace["fraction"]) && trace["fraction"] >= 1))
    {
        self iPrintLn("^2ZAB ^7No safe crosshair surface found");
        return;
    }

    landing = trace["position"] + (0, 0, 42);
    if (isDefined(trace["normal"]))
        landing += trace["normal"] * 24;
    self zab_warp(landing, "crosshair impact");
}

zab_unlock_all_doors()
{
    self endon("disconnect");

    if (self.zab_busy_doors)
        return;
    self.zab_busy_doors = true;

    total = 0;
    doors = getEntArray("zombie_door", "targetname");
    for (i = 0; i < doors.size && i < 96; i++)
    {
        if (isDefined(doors[i]))
        {
            doors[i] notify("trigger", self);
            total++;
        }
        wait 0.05;
    }

    debris = getEntArray("zombie_debris", "targetname");
    for (i = 0; i < debris.size && i < 96; i++)
    {
        if (isDefined(debris[i]))
        {
            debris[i] notify("trigger", self);
            total++;
        }
        wait 0.05;
    }

    self iPrintLn("^2ZAB ^7Triggered " + total + " door/debris objects");
    self.zab_busy_doors = false;
}

/* ============================================================
   HUD ELEMENT FACTORIES
   ============================================================ */

zab_text_left(value, x, y, scale, rgb, sort)
{
    elem = newClientHudElem(self);
    elem.horzAlign = "left";
    elem.vertAlign = "top";
    elem.alignX = "left";
    elem.alignY = "top";
    elem.x = x;
    elem.y = y;
    elem.font = "default";
    elem.fontScale = scale;
    elem setText(value);
    elem.color = rgb;
    elem.alpha = 1;
    elem.sort = sort;
    elem.hideWhenInMenu = false;
    return elem;
}

zab_text_right(value, x, y, scale, rgb, sort)
{
    elem = newClientHudElem(self);
    elem.horzAlign = "left";
    elem.vertAlign = "top";
    elem.alignX = "right";
    elem.alignY = "top";
    elem.x = x;
    elem.y = y;
    elem.font = "default";
    elem.fontScale = scale;
    elem setText(value);
    elem.color = rgb;
    elem.alpha = 1;
    elem.sort = sort;
    elem.hideWhenInMenu = false;
    return elem;
}

zab_text(value, x, y, scale, rgb, sort)
{
    elem = newClientHudElem(self);
    elem.horzAlign = "left";
    elem.vertAlign = "top";
    elem.alignX = "left";
    elem.alignY = "top";
    elem.x = x;
    elem.y = y;
    elem.font = "default";
    elem.fontScale = scale;
    elem setText(value);
    elem.color = rgb;
    elem.alpha = 1;
    elem.sort = sort;
    elem.hideWhenInMenu = false;
    return elem;
}

zab_bar(x, y, width, height, rgb, alpha, sort)
{
    elem = newClientHudElem(self);
    elem.horzAlign = "left";
    elem.vertAlign = "top";
    elem.alignX = "left";
    elem.alignY = "top";
    elem.x = x;
    elem.y = y;
    elem.sort = sort;
    elem.color = rgb;
    elem.alpha = alpha;
    elem setShader("white", width, height);
    elem.hideWhenInMenu = false;
    return elem;
}