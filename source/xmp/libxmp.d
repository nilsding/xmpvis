/// C functions for libxmp
module xmp.libxmp;

const int XMP_NAME_SIZE = 64;              /** Size of module name and type */

const int XMP_KEY_OFF  = 0x81;             /** Note number for key off event */
const int XMP_KEY_CUT  = 0x82;             /** Note number for key cut event */
const int XMP_KEY_FADE = 0x83;             /** Note number for fade event */

/* mixer parameter macros */

/* sample format flags */
const int XMP_FORMAT_8BIT     = (1 << 0);  /** Mix to 8-bit instead of 16 */
const int XMP_FORMAT_UNSIGNED = (1 << 1);  /** Mix to unsigned samples */
const int XMP_FORMAT_MONO     = (1 << 2);  /** Mix to mono instead of stereo */

/* limits */
const int XMP_MAX_KEYS       = 121;     /** Number of valid keys */
const int XMP_MAX_ENV_POINTS = 32;      /** Max number of envelope points */
const int XMP_MAX_MOD_LENGTH = 256;     /** Max number of patterns in module */
const int XMP_MAX_CHANNELS   = 64;      /** Max number of channels in module */
const int XMP_MAX_SRATE      = 49170;   /** max sampling rate (Hz) */
const int XMP_MIN_SRATE      = 4000;    /** min sampling rate (Hz) */
const int XMP_MIN_BPM        = 20;      /** min BPM */
/* frame rate = (50 * bpm / 125) Hz */
/* frame size = (sampling rate * channels * size) / frame rate */
const int XMP_MAX_FRAMESIZE  = (5 * XMP_MAX_SRATE * 2 / XMP_MIN_BPM);

struct xmp_channel
{
  int pan;
  int vol;
  int flg;
};

struct xmp_pattern
{
  int rows;
  int[1] index;
};

struct xmp_event
{
  ubyte note;
  ubyte ins;
  ubyte vol;
  ubyte fxt;
  ubyte fxp;
  ubyte f2t;
  ubyte f2p;
  ubyte _flag;
};

struct xmp_track
{
  int rows;
  // xmp_event[1] event;
  xmp_event* event;
};

struct xmp_envelope
{
  int flg;
  int npt;
  int scl;
  int sus;
  int sue;
  int lps;
  int lpe;
  short[32 * 2] data;
};

struct xmp_instrument
{
  char[32] name;
  int vol;
  int nsm;
  int rls;
  xmp_envelope aei;
  xmp_envelope pei;
  xmp_envelope fei;

  private struct Map
  {
    ubyte ins;
    byte xpo;
  }
  Map[XMP_MAX_KEYS] map;

  private struct XmpSubinstrument
  {
    int vol;
    int gvl;
    int pan;
    int xpo;
    int fin;
    int vwf;
    int vde;
    int vra;
    int vsw;
    int rvv;
    int sid;
    int nna;
    int dct;
    int dca;
    int ifc;
    int ifr;
  };
  XmpSubinstrument* sub;

  void* extra;
};

struct xmp_sample
{
  char[32] name;
  int len;
  int lps;
  int lpe;
  int flg;
  ubyte* data;
};

struct xmp_sequence
{
  int entry_point;
  int duration;
};

struct xmp_module
{
  char[XMP_NAME_SIZE] name;
  char[XMP_NAME_SIZE] type;
  int pat;
  int trk;
  int chn;
  int ins;
  int smp;
  int spd;
  int bpm;
  int len;
  int rst;
  int gvl;

  xmp_pattern **xxp;
  xmp_track **xxt;
  xmp_instrument *xxi;
  xmp_sample *xxs;
  xmp_channel[XMP_MAX_CHANNELS] xxc;
  ubyte[XMP_MAX_MOD_LENGTH] xxo;
};

struct xmp_test_info
{
  char[XMP_NAME_SIZE] name;
  char[XMP_NAME_SIZE] type;
};

struct xmp_module_info
{
  ubyte[16] md5;
  int vol_base;
  xmp_module *mod;
  char *comment;
  int num_sequences;
  xmp_sequence *seq_data;
};

struct xmp_channel_info
{
  uint period;
  uint position;
  short pitchbend;
  ubyte note;
  ubyte instrument;
  ubyte sample;
  ubyte volume;
  ubyte pan;
  ubyte reserved;
  xmp_event event;
};


struct xmp_frame_info
{
  int pos;
  int pattern;
  int row;
  int num_rows;
  int frame;
  int speed;
  int bpm;
  int time;
  int total_time;
  int frame_time;
  void* buffer;
  int buffer_size;
  int total_size;
  int volume;
  int loop_count;
  int virt_channels;
  int virt_used;
  int sequence;

  xmp_channel_info[XMP_MAX_CHANNELS] channel_info;
};

alias xmp_context = char*;

extern (C) extern __gshared const char* xmp_version;
extern (C) extern __gshared const uint  xmp_vercode;

extern (C) xmp_context xmp_create_context  ();
extern (C) void        xmp_free_context    (xmp_context);
extern (C) int         xmp_test_module     (char*, xmp_test_info*);
extern (C) int         xmp_load_module     (xmp_context, char *);
extern (C) void        xmp_scan_module     (xmp_context);
extern (C) void        xmp_release_module  (xmp_context);
extern (C) int         xmp_start_player    (xmp_context, int, int);
extern (C) int         xmp_play_frame      (xmp_context);
extern (C) int         xmp_play_buffer     (xmp_context, void*, int, int);
extern (C) void        xmp_get_frame_info  (xmp_context, xmp_frame_info*);
extern (C) void        xmp_end_player      (xmp_context);
extern (C) void        xmp_inject_event    (xmp_context, int, xmp_event*);
extern (C) void        xmp_get_module_info (xmp_context, xmp_module_info*);
extern (C) char**      xmp_get_format_list ();
extern (C) int         xmp_next_position   (xmp_context);
extern (C) int         xmp_prev_position   (xmp_context);
extern (C) int         xmp_set_position    (xmp_context, int);
extern (C) void        xmp_stop_module     (xmp_context);
extern (C) void        xmp_restart_module  (xmp_context);
extern (C) int         xmp_seek_time       (xmp_context, int);
extern (C) int         xmp_channel_mute    (xmp_context, int, int);
extern (C) int         xmp_channel_vol     (xmp_context, int, int);
extern (C) int         xmp_set_player      (xmp_context, int, int);
extern (C) int         xmp_get_player      (xmp_context, int);
extern (C) int         xmp_set_instrument_path (xmp_context, char*);
extern (C) int         xmp_load_module_from_memory (xmp_context, void*, long);
extern (C) int         xmp_load_module_from_file (xmp_context, void*, long);

/* External sample mixer API */
extern (C) int         xmp_start_smix       (xmp_context, int, int);
extern (C) void        xmp_end_smix         (xmp_context);
extern (C) int         xmp_smix_play_instrument(xmp_context, int, int, int, int);
extern (C) int         xmp_smix_play_sample (xmp_context, int, int, int, int);
extern (C) int         xmp_smix_channel_pan (xmp_context, int, int);
extern (C) int         xmp_smix_load_sample (xmp_context, int, char*);
extern (C) int         xmp_smix_release_sample (xmp_context, int);
