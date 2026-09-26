// ---------------------------------------------------------------------------
// o_mod_lrgmk -- Step event.
//
// Consumes global.mod_lr_queue, which the chart gimmick callbacks fill in (they
// run in the gimmick instance scope and may only touch globals), and does the
// actual work here, where a real instance and the cc instance are available.
//
// This object knows nothing about notes or judgment: it only creates and
// colours instances of the vanilla o_lorelei_slash, i.e. a display layer.
// ---------------------------------------------------------------------------

if (!variable_global_exists("mod_lr_ready")) return;
if (!instance_exists(cc)) return;

// Switched on here rather than in Create: reaching this line already proves the
// Create event ran to completion, so every global used below exists by now.
global.mod_lr_ready = true;

// State belongs to one cc instance. A quick restart is room_restart(): the room
// and its index stay the same and only cc is rebuilt, so comparing the cc
// instance id is the only reliable way to notice it. The slash renderer is
// intentionally NOT part of the reset -- it is a chart wide draw pass and is
// shared by every slash, old or new.
if (global.mod_lr_cc != cc)
{
    global.mod_lr_cc = cc;
    global.mod_lr_queue = [];
    global.mod_lr_color = 16777215;
    mod_lr_log("chart started (cc " + string(cc) + ")");
}

// Shared draw pass for every o_lorelei_slash; created once per game run.
if (!instance_exists(global.mod_lr_renderer))
{
    global.mod_lr_renderer = instance_create_depth(0, 0, 255, o_lorelei_slash_renderer);
}

/// Colour used for "value2" that was not filled in, i.e. "_" in the .vsm.
function mod_lr_sentinel(_v)
{
    return is_undefined(_v) || _v == undefined || _v == 573613;
}

/// "value1" -> how many slashes to spawn at that beat; "_" means one.
function mod_lr_count(_v)
{
    if (mod_lr_sentinel(_v)) return 1;
    var _n = floor(real(_v));
    if (_n < 1) return 1;
    if (_n > 64) return 64;
    return _n;
}

/// Spawns one batch of slashes at the beat encoded in _req.
///
/// The "ms" field is what makes o_lorelei_slash special: its Create event sets
/// timer = (cc.currentms - ms) / 1000, so a slash created for a beat that has
/// not been reached yet stays invisible (timer < 0) and fades in on time. That
/// is why a gimmick trigger only has to fire once per beat instead of every
/// frame like slash_anycol.
function mod_lr_spawn(_req)
{
    var _count = mod_lr_count(_req.v1);
    var _col;
    if (mod_lr_sentinel(_req.v2)) _col = global.mod_lr_color;
    else                          _col = real(_req.v2);

    for (var _i = 0; _i < _count; _i++)
    {
        instance_create_depth(0, 0, 255, o_lorelei_slash, { color: _col, ms: _req.ms });
    }

    mod_lr_log("lr_slash count=" + string(_count)
        + " colour=" + string(_col)
        + " rgb=" + string(color_get_red(_col)) + "/" + string(color_get_green(_col)) + "/" + string(color_get_blue(_col))
        + " ms=" + string(_req.ms) + " currentms=" + string(cc.currentms));
}

/// Changes the colour that later lr_slash lines use when they leave value2 as "_".
function mod_lr_set_color(_req)
{
    if (mod_lr_sentinel(_req.v2))
    {
        mod_lr_log("lr_slash_color ignored: value2 is empty, writes the colour there");
        return;
    }
    global.mod_lr_color = real(_req.v2);
    mod_lr_log("lr_slash_color=" + string(global.mod_lr_color)
        + " rgb=" + string(color_get_red(global.mod_lr_color)) + "/"
        + string(color_get_green(global.mod_lr_color)) + "/"
        + string(color_get_blue(global.mod_lr_color)));
}

var _n = array_length(global.mod_lr_queue);
for (var _i = 0; _i < _n; _i++)
{
    var _req = global.mod_lr_queue[_i];
    if (_req.kind == "slash") mod_lr_spawn(_req);
    else                      mod_lr_set_color(_req);
}
if (_n > 0) global.mod_lr_queue = [];
