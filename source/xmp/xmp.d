module xmp.xmp;

import derelict.sdl2.sdl;
import xmp.libxmp;
import std.conv;
import std.stdio;
import std.string;
import std.utf;

/// OO-equivalent of xmp_context
class Xmp
{
  this()
  {
    assert((_ctx = xmp_create_context()) != null);

    SDL_AudioSpec a;

    a.freq = 44_100;
    a.format = AUDIO_S16;
    a.channels = 2;
    a.samples = 2048;
    a.callback = &sdlCallback;
    a.userdata = cast(void*)this;

    SDL_OpenAudio(&a, null);
  }

  ~this()
  {
    xmp_free_context(_ctx);
  }

  @property static string xmpVersion() { return to!string(xmp_version); }

  @property static uint xmpVercode() { return xmp_vercode; }

  bool loadModule(string filename)
  {
    if (_playing)
    {
      stopModule();
    }
    immutable int ret = xmp_load_module(_ctx, filename.toUTFz!(char*));
    return ret == 0;
  }

  @property XmpFrameInfo frameInfo()
  {
    xmp_frame_info frame_info;
    xmp_get_frame_info(_ctx, &frame_info);
    return new XmpFrameInfo(frame_info);
  }

  @property XmpModuleInfo moduleInfo()
  {
    xmp_module_info mod_info;
    xmp_get_module_info(_ctx, &mod_info);
    return new XmpModuleInfo(mod_info);
  }

  void playModule()
  {
    xmp_start_player(_ctx, 44_100, 0);
    _playing = true;
    SDL_PauseAudio(0);
  }

  void pauseModule() nothrow @nogc
  {
    SDL_PauseAudio(_playing);
    _playing = !_playing;
  }

  void stopModule()
  {
    _playing = false;
    SDL_PauseAudio(1);
    xmp_end_player(_ctx);
  }

protected:

private:
  xmp_context _ctx;
  bool _playing;
}

extern(C) private void sdlCallback(void* userData, ubyte* stream, int len) nothrow
{
  auto xmp = cast(Xmp)userData;
  try
  {
    if (xmp_play_buffer(xmp._ctx, stream, len, 0) < 0)
      xmp._playing = false;
  }
  catch (Exception e)
  {
    xmp._playing = false;
  }
}

/// OO-equivalent of xmp_module_info
class XmpModuleInfo
{
  this(ref xmp_module_info mod_info)
  {
    _mod_info = mod_info;
  }

  @property XmpModule mod()
  {
    if (_mod is null)
    {
      return _mod = new XmpModule(*_mod_info.mod);
    }
    return _mod;
  }

private:
  xmp_module_info _mod_info;
  XmpModule _mod;  // struct for caching
}

/// OO-equivalent of xmp_module
class XmpModule
{
  this(ref xmp_module mod)
  {
    _mod = mod;
  }

  @property string name() { mixin(cStrToDStr!("_mod.name")); }
  @property string type() { return _mod.type.to!string; }
  @property int patternCount() { return _mod.pat; }
  @property int length() { return _mod.len; }
  @property int instrumentCount() { return _mod.ins; }
  @property int channels() { return _mod.chn; }
  @property xmp_pattern** patterns() { return _mod.xxp; }

private:
  xmp_module _mod;
}

/// OO-equivalent of xmp_frame_info
class XmpFrameInfo
{
  this(ref xmp_frame_info fi)
  {
    _fi = fi;
  }

  @property int pos() { return _fi.pos; }
  @property int pattern() { return _fi.pattern; }
  @property int row() { return _fi.row; }
  @property int numRows() { return _fi.num_rows; }
  @property int frame() { return _fi.frame; }
  @property int speed() { return _fi.speed; }
  @property int bpm() { return _fi.bpm; }
  @property int time() { return _fi.time; }
  @property int totalTime() { return _fi.total_time; }
  @property int frameTime() { return _fi.frame_time; }
  @property void* buffer() { return _fi.buffer; }
  @property int bufferSize() { return _fi.buffer_size; }
  @property int totalSize() { return _fi.total_size; }
  @property int volume() { return _fi.volume; }
  @property int loopCount() { return _fi.loop_count; }
  @property int virtChannels() { return _fi.virt_channels; }
  @property int virtUsed() { return _fi.virt_used; }
  @property int sequence() { return _fi.sequence; }
  @property xmp_channel_info[XMP_MAX_CHANNELS] channel_info() { return _fi.channel_info; }

private:
  xmp_frame_info _fi;
}

private template cStrToDStr(string s)
{
  const char[] cStrToDStr = "auto tmp = " ~ s ~ ".to!string; " ~
    "return tmp[0..tmp.indexOf(\"\\0\")];";
}
