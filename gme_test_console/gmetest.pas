program gmetest;

 // Many thanks to Gigatron
 // by Fred vS | fiens@hotmail.com | 2024

{$mode objfpc}{$H+}
{$PACKRECORDS C}

uses
 {$IFDEF UNIX}
  cthreads,
  alsa_min,
 {$ENDIF}
  Classes,
  CustApp,
  libgme,
 {$IFDEF windows} mmsystem,  windows,{$ENDIF}
  SysUtils;

type
  TgmeConsole = class(TCustomApplication)
  private
    procedure ConsolePlay;
  protected
    procedure doRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
  end;

const
  FileName      = 'lion.spc'; // opens this file (can be any music type)
  SampleRate    = 44100;
  Channels      = 2;
  BitsPerSample = 16;
  Track         = 0;     //     (0 = first)
  BufSize       = 16384; //   multiple of 2
  BufferCount   = 2;

{$IFDEF UNIX}
Type
  TalsaThread = class(TThread)
    private
      protected
      procedure Execute; override;
    public
      Constructor Create(CreateSuspended : boolean);
  end;
{$ENDIF}

var
  x: integer;
  {$IFDEF windows}  
  waveOut: HWAVEOUT;
  waveHeader: TWaveHdr;
  buffers: array[0..BufferCount-1] of array[0..BufSize-1] of SmallInt;
  waveHeaders: array[0..BufferCount-1] of TWaveHdr;
  currentBuffer: Integer;
  {$else}
  alsaThread: TalsaThread;
  pcm: PPsnd_pcm_t;
  {$ENDIF}
  Emu: PMusic_Emu;
  info: Pgme_info_t;
  ok_flag: Boolean = False;
  ordir: string;
  inct: integer = 0;

procedure HandleError(const Str: pansichar);
  begin
    if Str <> nil then
    begin
      WriteLn('Error: ', Str);
      ReadLn;
      Halt(1);
    end;
  end;

 {$IFDEF windows}
procedure FillBuffer(bufferIndex: Integer);
begin
  if ok_flag then
  begin
   gme_play(Emu, BufSize, @buffers[bufferIndex][0]);
   waveHeaders[bufferIndex].dwFlags := waveHeaders[bufferIndex].dwFlags and (not WHDR_DONE);
  end;
end;

function WaveOutCallback(hwo: HWAVEOUT; uMsg: UINT; dwInstance, dwParam1, dwParam2: DWORD_PTR): DWORD; stdcall;
begin
  if uMsg = WOM_DONE then
  begin
    FillBuffer(currentBuffer);
    waveOutWrite(hwo, @waveHeaders[currentBuffer], SizeOf(TWaveHdr));
    currentBuffer := (currentBuffer + 1) mod BufferCount;
  end;
  Result := 0;
end;

procedure InitAudio;
var
  wFormat: TWaveFormatEx;
  i: Integer;
begin

  SetThreadPriority(GetCurrentThread, THREAD_PRIORITY_LOWEST);

  with wFormat do
  begin
    wFormatTag := WAVE_FORMAT_PCM;
    nChannels := Channels;
    nSamplesPerSec := SampleRate;
    wBitsPerSample := BitsPerSample;
    nBlockAlign := (wBitsPerSample * nChannels) div 8;
    nAvgBytesPerSec := nSamplesPerSec * nBlockAlign;
    cbSize := 0;
  end;

  if waveOutOpen(@waveOut, WAVE_MAPPER, @wFormat, QWORD(@WaveOutCallback), 0, CALLBACK_FUNCTION) <> MMSYSERR_NOERROR then
    raise Exception.Create('Error audio');

  // buffers
  for i := 0 to BufferCount - 1 do
  begin
    ZeroMemory(@waveHeaders[i], SizeOf(TWaveHdr));
     with waveHeaders[i] do
    begin
      lpData := @buffers[i][0];
      dwBufferLength := BufSize * SizeOf(SmallInt);
      dwFlags := 0;
    end;
    waveOutPrepareHeader(waveOut, @waveHeaders[i], SizeOf(TWaveHdr));
  end;
  currentBuffer := 0;
end;

{$ELSE}// Unix

  procedure InitAudio;
  var
    buffer: array[0..BufSize - 1] of byte;
    frames: snd_pcm_sframes_t;
  begin
    as_Load();        // load libasound library
    gme_Load(ordir);  // load gme library
    ordir := IncludeTrailingBackslash(ExtractFilePath(ParamStr(0))) + FileName;

    HandleError(gme_open_file(pansichar(ordir), Emu, SampleRate));
    HandleError(gme_start_track(Emu, 0));
    HandleError(gme_track_info(emu, info, track));

    writeln('System : ' + (info^.systeme));
    writeln('Game : ' + (info^.game));
    writeln('Song : ' + (info^.song));
    writeln('Author : ' + (info^.author));
    writeln('Copyright : ' + (info^.copyright));
    writeln('Comment : ' + (info^.comment));
    writeln('Dumper : ' + (info^.dumper));
    writeln();

    if snd_pcm_open(@pcm, @device[1], SND_PCM_STREAM_PLAYBACK, 0) = 0 then
      if snd_pcm_set_params(pcm, SND_PCM_FORMAT_S16, SND_PCM_ACCESS_RW_INTERLEAVED,
        Channels,                        // number of channels
        SampleRate,                      // sample rate (Hz)
        1,                               // resampling on/off
        500000) = 0 then            // latency (us)
      begin
        ok_flag := True;
        sleep(100);
        while ok_flag do
        begin
          gme_play(Emu, BufSize div 2, @buffer[0]);
          frames   := snd_pcm_writei(pcm, @buffer[0], BufSize div 4);
          if frames < 0 then
            frames := snd_pcm_recover(pcm, frames, 0); // try to recover from any error
          if frames < 0 then
          begin
            break; // give up if failed to recover
            ok_flag := False;
          end;

        end;
          write(#13 + '... ' + IntToStr(inct) + ' seconds playing ...');
         end;   

        sleep(100);
        snd_pcm_drain(pcm);                      // drain any remaining samples
        snd_pcm_close(pcm);
        gme_Unload();
        as_Unload();
     
  end;

  constructor TalsaThread.Create(CreateSuspended: Boolean);
  begin
    inherited Create(CreateSuspended);
    FreeOnTerminate := True;
  end;

  procedure TalsaThread.Execute;
  begin
    InitAudio;
  end;

{$ENDIF}// End Unix

  constructor TgmeConsole.Create(TheOwner: TComponent);
  begin
    inherited Create(TheOwner);
    StopOnException := True;
  end;

  procedure TgmeConsole.ConsolePlay;
  begin
   {$IFDEF windows}
   ordir := IncludeTrailingBackslash(ExtractFilePath(ParamStr(0))) + 'gme.dll';

   if gme_Load(ordir) then writeln('OK load dir') else writeln('NOT OK load dir');
   
   ordir := IncludeTrailingBackslash(ExtractFilePath(ParamStr(0))) + FileName;

   InitAudio;
   HandleError(gme_open_file(PAnsiChar(ordir), Emu, SampleRate));
   HandleError(gme_start_track(Emu, 0));
   HandleError(gme_track_info(emu, info, track));
   ok_flag := true;
   
    writeln('System : ' + (info^.systeme));
    writeln('Game : ' + (info^.game));
    writeln('Song : ' + (info^.song));
    writeln('Author : ' + (info^.author));
    writeln('Copyright : ' + (info^.copyright));
    writeln('Comment : ' + (info^.comment));
    writeln('Dumper : ' + (info^.dumper));
    writeln();

  FillBuffer(0);
  FillBuffer(1);
  waveOutWrite(waveOut, @waveHeaders[0], SizeOf(TWaveHdr));
  waveOutWrite(waveOut, @waveHeaders[1], SizeOf(TWaveHdr));
  {$ENDIF}
  {$IFDEF unix}
  ordir := IncludeTrailingBackslash(ExtractFilePath(ParamStr(0))) + 'libgme.so';
  alsaThread := TalsaThread.Create(True);
  alsaThread.Start;
  {$ENDIF}
    writeln();
    writeln('Playing during 30 seconds...');
    writeln();
    sleep(1000);
    while inct < 30 do
    begin
      Inc(inct);
      write(#13 + '... ' + IntToStr(inct) + ' seconds playing ...');
      sleep(1000);
    end;
    writeln();
    writeln();
    writeln('Stop playing after 30 seconds...');
    writeln();
    writeln('Bye!');
  end;

  procedure TgmeConsole.doRun;
  var
    i: integer;
  begin
    ConsolePlay;
  {$IFDEF windows}
  for i := 0 to BufferCount - 1 do
   waveOutUnprepareHeader(waveOut, @waveHeaders[i], SizeOf(TWaveHdr));
   waveOutClose(waveOut);
  gme_delete(Emu);
  gme_Unload();
  {$else}
    ok_flag := False;
    alsaThread.terminate;
    alsaThread.free;
  {$ENDIF}
    Terminate;
  end;

var
  Application: TgmeConsole;

begin
  Application       := TgmeConsole.Create(nil);
  Application.Title := 'Console gme';
  Application.Run;
  Application.Free;
end.

