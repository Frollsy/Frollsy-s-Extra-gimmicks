// o_mod_lrgmk -- Create event.
//
// Part of "lr_extra_gimmicks": chart gimmicks that exist in the vanilla
// chart-specific gimmick libraries (obj_distortedfate_gimmick /
// obj_firstbreath_gimmick) but were never ported into the Custom Gimmicks mod.
//
// First and currently only gimmick: lr_slash / lr_slash_color.
//
// ---------------------------------------------------------------------------
// Why UnlimitedAddGlobalMod instead of addGlobalMod
// ---------------------------------------------------------------------------
// This mod is deliberately Custom Gimmicks only (project decision):
//   * it registers through Custom Gimmicks' UnlimitedAddGlobalMod (index 129+),
//     so it never consumes one of the 54 free slots in the vanilla 0..127 table;
//   * a chart must therefore use "!obj: obj_custom_gimmick" AND the Custom
//     Gimmicks mod must be installed;
//   * official (non-custom) charts never see these names.
//
// Registration has to happen during general gameplay, before the .vsm text
// chart is parsed: Custom Songs Mod's load_text_mods() sets
// "ms.ig = struct_exists(global.mods, name)" per line, and Custom Gimmicks'
// codepatches/updateMod.gml resolves ig == true through global.mods by name.
//
// The callbacks run inside the gimmick instance scope, so they may only touch
// global.* -- each one just pushes onto global.mod_lr_queue and the Step event
// of this object does the real work.
// ---------------------------------------------------------------------------

persistent = true;
depth = -999999;

global.mod_lr_queue = [];
global.mod_lr_color = 16777215;     // current slash colour, c_white by default
global.mod_lr_ready = false;
global.mod_lr_renderer = noone;
global.mod_lr_cc = noone;           // cc instance the state belongs to

/// Unconditional log line -- an author cannot enable "debuglog" for a chart
/// gimmick, so a chart that silently does nothing must still leave a trace.
///
/// Writes to the save directory (%LOCALAPPDATA%\vividstasis\), which is where
/// file_text_* write; the game directory only holds the file that is read.
function mod_lr_log(_msg)
{
    var _f = -1;
    try
    {
        _f = file_text_open_append("lr_extra_gimmicks.log");
    }
    catch (_ex)
    {
        return;
    }
    if (_f == -1) return;
    file_text_write_string(_f, string(current_time) + "  " + string(_msg));
    file_text_writeln(_f);
    file_text_close(_f);
}

/// Registers one chart gimmick name in the Custom Gimmicks registry.
///
/// Returns true when the name ended up in global.mods.
///
/// Do NOT probe the dependency with function_exists(): that function does not
/// exist in this build at all -- the compiler turns the call into an instance
/// variable read and the game dies with
/// "Variable o_mod_lrgmk.function_exists not set before reading it". The game
/// itself never uses it either (0 hits in all 4842 vanilla code entries).
///
/// The probe below is the loader's own handshake: every VML mod announces
/// itself into global.vml_mods from its mod_info.gml codepatch, and
/// Custom Gimmicks does it as
///     if (!variable_global_exists("vml_mods")) global.vml_mods = {};
///     global.vml_mods.custom_gimmicks_mod = { ... };
/// The same check is already used by custom_episodes and is verified in game;
/// every function in it is vanilla-used native GML. The actual call is still
/// wrapped in try/catch, so even a false positive only costs one log line.
function mod_lr_register_gimmick(_name, _callback)
{
    if (!variable_global_exists("mods") || !is_struct(global.mods))
    {
        mod_lr_log("cannot register " + string(_name) + ": global.mods is missing");
        return false;
    }
    if (struct_exists(global.mods, _name))
    {
        mod_lr_log("gimmick " + string(_name) + " is already registered, skipped");
        return true;
    }

    var _cg = false;
    try
    {
        _cg = (variable_global_exists("vml_mods") && is_struct(global.vml_mods)
            && variable_struct_exists(global.vml_mods, "custom_gimmicks_mod"));
    }
    catch (_ex)
    {
        _cg = false;
    }
    if (!_cg)
    {
        mod_lr_log("cannot register " + string(_name)
            + ": Custom Gimmicks not loaded (global.vml_mods.custom_gimmicks_mod is missing)");
        return false;
    }

    var _ok = false;
    try
    {
        UnlimitedAddGlobalMod(_name, 0, _callback, undefined);
        _ok = true;
    }
    catch (_ex)
    {
        _ok = false;
    }

    if (_ok) mod_lr_log("gimmick registered: " + string(_name));
    else     mod_lr_log("cannot register " + string(_name) + ": UnlimitedAddGlobalMod threw");
    return _ok;
}

// ---------------------------------------------------------------------------
// lr_slash      beat,0,linear,<count>,<colour>,lr_slash,-1
// lr_slash_color beat,0,linear,_,<colour>,lr_slash_color,-1
//
// count  : how many slashes to spawn at that beat ("_" -> 1)
// colour : packed GameMaker colour, i.e. what make_color_rgb(r, g, b) returns
//          and what the c_* constants are ("_" -> the current colour)
// ---------------------------------------------------------------------------
if (!variable_global_exists("mods") || !is_struct(global.mods)
    || !struct_exists(global.mods, "lr_slash"))
{
    var _cb_slash = function(_start, _duration, _v1, _v2)
    {
        array_push(global.mod_lr_queue,
            { kind: "slash", ms: _start, v1: _v1, v2: _v2 });
    };
    mod_lr_register_gimmick("lr_slash", _cb_slash);
}

if (!variable_global_exists("mods") || !is_struct(global.mods)
    || !struct_exists(global.mods, "lr_slash_color"))
{
    var _cb_color = function(_start, _duration, _v1, _v2)
    {
        array_push(global.mod_lr_queue,
            { kind: "color", ms: _start, v1: _v1, v2: _v2 });
    };
    mod_lr_register_gimmick("lr_slash_color", _cb_color);
}
