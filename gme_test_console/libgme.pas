unit libgme;

 // Many thanks to Gigatron
 // by Fred vS | fiens@hotmail.com | 2024

{$mode objfpc}{$H+}
{$PACKRECORDS C}

interface

uses
  dynlibs,
  CTypes;

const
  GME_VERSION = $000603; // 1 byte major, 1 byte minor, 1 byte patch-level
 
  {$IFDEF windows}
  librarygme = 'gme.dll';
  {$else}
  librarygme = 'libgme.so';
  {$ENDIF}

type
  PMusic_Emu = ^TMusic_Emu;
  TMusic_Emu = record
    // Opaque structure, contents not defined here
  end;

  gme_err_t = PAnsiChar;

  Pgme_info_t = ^Tgme_info_t;
  Tgme_info_t = record
    length: Integer;
    intro_length: Integer;
    loop_length: Integer;
    play_length: Integer;
    i4, i5, i6, i7, i8, i9, i10, i11, i12, i13, i14, i15: Integer;
    systeme: PAnsiChar;
    game: PAnsiChar;
    song: PAnsiChar;
    author: PAnsiChar;
    copyright: PAnsiChar;
    comment: PAnsiChar;
    dumper: PAnsiChar;
    s7, s8, s9, s10, s11, s12, s13, s14, s15: PAnsiChar;
  end;

  Tgme_equalizer_t = record
    treble: Double;
    bass: Double;
    d2, d3, d4, d5, d6, d7, d8, d9: Double;
  end;

  gme_type_t = Pointer;

  gme_reader_t = function(your_data: Pointer; out_: Pointer; count: Integer): gme_err_t; cdecl;
  gme_user_cleanup_t = procedure(user_data: Pointer); cdecl;

const
  gme_info_only = -1;

var
  gme_ay_type: gme_type_t; external;
  gme_gbs_type: gme_type_t; external;
  gme_gym_type: gme_type_t; external;
  gme_hes_type: gme_type_t; external;
  gme_kss_type: gme_type_t; external;
  gme_nsf_type: gme_type_t; external;
  gme_nsfe_type: gme_type_t; external;
  gme_sap_type: gme_type_t; external;
  gme_spc_type: gme_type_t; external;
  gme_vgm_type: gme_type_t; external;
  gme_vgz_type: gme_type_t; external;
  
  gme_open_file: function(path: PAnsiChar; out out_: PMusic_Emu; sample_rate: Integer): gme_err_t; cdecl;
  gme_start_track: function(emu: PMusic_Emu; index: Integer): gme_err_t; cdecl;
  gme_play: function(emu: PMusic_Emu; count: Integer; out_: PSmallInt): gme_err_t; cdecl;
  gme_track_info: function(const emu: PMusic_Emu; out out_: Pgme_info_t; track: Integer): gme_err_t; cdecl;
  gme_delete: procedure(emu: PMusic_Emu); cdecl;
  gme_track_ended: function(const emu: PMusic_Emu): Integer; cdecl; 
  
// Special function for dynamic loading of lib ...
  gme_Handle: TLibHandle = dynlibs.NilHandle; // this will hold our handle for the lib

  ReferenceCounter: integer = 0;  // Reference counter
 
  function gme_Load(const libfilename:string) :boolean;
  procedure gme_Unload();
  
implementation  
function gme_IsLoaded: Boolean;
begin
  Result := (gme_Handle <> dynlibs.NilHandle);
end;

function gme_Load(const libfilename: string): boolean; // load the lib
var
  thelib: string;
begin
  Result := False;
  if gme_Handle<>0 then 
begin
 Inc(ReferenceCounter);
 result:=true {is it already there ?}
end  else 
begin {go & load the library}
   if Length(libfilename) = 0 then thelib := librarygme else thelib := libfilename;
    gme_Handle:=DynLibs.LoadLibrary(thelib); // obtain the handle we want
  	if gme_Handle <> DynLibs.NilHandle then
   begin // now we tie the functions to the VARs from above

      Pointer(gme_open_file)       := DynLibs.GetProcedureAddress(gme_Handle, PChar('gme_open_file'));
      Pointer(gme_start_track) := DynLibs.GetProcedureAddress(gme_Handle, PChar('gme_start_track'));
      Pointer(gme_play)     := DynLibs.GetProcedureAddress(gme_Handle, PChar('gme_play'));
      Pointer(gme_track_info)    := DynLibs.GetProcedureAddress(gme_Handle, PChar('gme_track_info'));
      Pointer(gme_delete)      := DynLibs.GetProcedureAddress(gme_Handle, PChar('gme_delete'));
      Pointer(gme_track_ended)      := DynLibs.GetProcedureAddress(gme_Handle, PChar('gme_track_ended'));

      Result           := gme_IsLoaded;
      ReferenceCounter := 1;
    end;
  end;
end;

procedure gme_Unload();
begin
   if ReferenceCounter > 0 then
    Dec(ReferenceCounter);
  if ReferenceCounter < 0 then
    Exit;
  if gme_IsLoaded then
  begin
    DynLibs.UnloadLibrary(gme_Handle);
    gme_Handle := DynLibs.NilHandle;
  end;
end;

end.

{       TODO

//  gme_wrong_file_type: PAnsiChar;   libgme name 'gme_';

 //function gme_wrong_file_type: PAnsiChar; cdecl; external libgme name 'gme_wrong_file_type';
  gme_wrong_file_type: PAnsiChar; external libgme name 'gme_wrong_file_type';

// Basic operations
function gme_open_file(path: PAnsiChar; out out_: PMusic_Emu; sample_rate: Integer): gme_err_t; cdecl; external libgme name 'gme_open_file';
function gme_track_count(const emu: PMusic_Emu): Integer; cdecl; external libgme name 'gme_track_count';
function gme_start_track(emu: PMusic_Emu; index: Integer): gme_err_t; cdecl; external libgme name 'gme_start_track';
function gme_play(emu: PMusic_Emu; count: Integer; out_: PSmallInt): gme_err_t; cdecl; external libgme name 'gme_play';
procedure gme_delete(emu: PMusic_Emu); cdecl; external libgme name 'gme_delete';

// Track position/length
procedure gme_set_fade(emu: PMusic_Emu; start_msec: Integer); cdecl; external libgme name 'gme_set_fade';
procedure gme_set_autoload_playback_limit(emu: PMusic_Emu; do_autoload_limit: Integer); cdecl; external libgme name 'gme_set_autoload_playback_limit';
function gme_autoload_playback_limit(const emu: PMusic_Emu): Integer; cdecl; external libgme name 'gme_autoload_playback_limi';
function gme_track_ended(const emu: PMusic_Emu): Integer; cdecl; external libgme name 'gme_track_ended';
function gme_tell(const emu: PMusic_Emu): Integer; cdecl; external libgme name 'gme_tell';
function gme_tell_samples(const emu: PMusic_Emu): Integer; cdecl; external libgme name 'gme_tell_samples';
function gme_seek(emu: PMusic_Emu; msec: Integer): gme_err_t; cdecl; external libgme name 'gme_seek';
function gme_seek_samples(emu: PMusic_Emu; n: Integer): gme_err_t; cdecl; external libgme name 'gme_seek_samples';

// Informational
function gme_warning(emu: PMusic_Emu): PAnsiChar; cdecl; external libgme name 'gme_warning';
function gme_load_m3u(emu: PMusic_Emu; path: PAnsiChar): gme_err_t; cdecl; external libgme name 'gme_load_m3u';
procedure gme_clear_playlist(emu: PMusic_Emu); cdecl; external libgme name 'gme_clear_playlist';
function gme_track_info(const emu: PMusic_Emu; out out_: Pgme_info_t; track: Integer): gme_err_t; cdecl; external libgme name 'gme_track_info';
procedure gme_free_info(info: Pgme_info_t); cdecl; external libgme  name 'gme_free_info';

// Advanced playback
procedure gme_set_stereo_depth(emu: PMusic_Emu; depth: Double); cdecl; external libgme name 'gme_set_stereo_depth';
procedure gme_ignore_silence(emu: PMusic_Emu; ignore: Integer); cdecl; external libgme name 'gme_ignore_silence';
procedure gme_set_tempo(emu: PMusic_Emu; tempo: Double); cdecl; external libgme name 'gme_set_tempo';
function gme_voice_count(const emu: PMusic_Emu): Integer; cdecl; external libgme name 'gme_voice_count';
function gme_voice_name(const emu: PMusic_Emu; i: Integer): PAnsiChar; cdecl; external libgme name 'gme_voice_name';
procedure gme_mute_voice(emu: PMusic_Emu; index: Integer; mute: Integer); cdecl; external libgme name 'gme_mute_voice';
procedure gme_mute_voices(emu: PMusic_Emu; muting_mask: Integer); cdecl; external libgme name 'gme_mute_voices';
procedure gme_equalizer(const emu: PMusic_Emu; out out_: Tgme_equalizer_t); cdecl; external libgme name 'gme_equalizer';
procedure gme_set_equalizer(emu: PMusic_Emu; const eq: Tgme_equalizer_t); cdecl; external libgme name 'gme_set_equalizer';
procedure gme_enable_accuracy(emu: PMusic_Emu; enabled: Integer); cdecl; external libgme name 'gme_enable_accuracy';

// Game music types
function gme_type(const emu: PMusic_Emu): gme_type_t; cdecl; external libgme name 'gme_type';
function gme_type_list: gme_type_t; cdecl; external libgme name 'gme_type_list';
function gme_type_system(type_: gme_type_t): PAnsiChar; cdecl; external libgme name 'gme_type_system';
function gme_type_multitrack(type_: gme_type_t): Integer; cdecl; external libgme name 'gme_type_multitrack';
function gme_multi_channel(const emu: PMusic_Emu): Integer; cdecl; external libgme name 'gme_multi_channel';

// Advanced file loading
function gme_open_data(const data: Pointer; size: LongInt; out out_: PMusic_Emu; sample_rate: Integer): gme_err_t; cdecl; external libgme name 'gme_open_data';
function gme_identify_header(const header: Pointer): PAnsiChar; cdecl; external libgme name 'gme_identify_header';
function gme_identify_extension(path_or_extension: PAnsiChar): gme_type_t; cdecl; external libgme name 'gme_identify_extension';
function gme_type_extension(music_type: gme_type_t): PAnsiChar; cdecl; external libgme name 'gme_type_extension';
function gme_identify_file(path: PAnsiChar; out type_out: gme_type_t): gme_err_t; cdecl; external libgme name 'gme_identify_file';
function gme_new_emu(type_: gme_type_t; sample_rate: Integer): PMusic_Emu; cdecl; external libgme name 'gme_new_emu';
function gme_new_emu_multi_channel(type_: gme_type_t; sample_rate: Integer): PMusic_Emu; cdecl; external libgme name 'gme_new_emu_multi_channel';
function gme_load_file(emu: PMusic_Emu; path: PAnsiChar): gme_err_t; cdecl; external libgme name 'gme_load_data';
function gme_load_data(emu: PMusic_Emu; const data: Pointer; size: LongInt): gme_err_t; cdecl; external libgme name 'gme_load_data';
function gme_load_custom(emu: PMusic_Emu; reader: gme_reader_t; file_size: LongInt; your_data: Pointer): gme_err_t; cdecl; external libgme name 'gme_load_custom';
function gme_load_m3u_data(emu: PMusic_Emu; const data: Pointer; size: LongInt): gme_err_t; cdecl; external libgme name 'gme_load_m3u_data';

// User data
procedure gme_set_user_data(emu: PMusic_Emu; new_user_data: Pointer); cdecl; external libgme name 'gme_set_user_data';
function  gme_user_data(const emu: PMusic_Emu): Pointer; cdecl;external libgme name 'gme_user_data';
procedure gme_set_user_cleanup(emu: PMusic_Emu; func: gme_user_cleanup_t); cdecl; external libgme name 'gme_set_user_cleanup';
}

