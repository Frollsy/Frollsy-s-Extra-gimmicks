// Mounts the resident gimmick host as soon as the main menu button steps.
// A new gml_GlobalScript_ entry does not run its top level code on this VML
// build, so the only reliable moment is an object event that already exists.
// Anchored to the END of gml_Object_o_newmainbutton_Step_0 as an InsertAfter
// patch, so the whole vanilla event is never replaced.
// Single line on purpose: the loader prepends "\n" and appends "\n" itself.
if (!instance_exists(o_mod_lrgmk)) instance_create_depth(0, 0, -999999, o_mod_lrgmk);
