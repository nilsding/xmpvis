import derelict.sdl2.sdl;
import derelict.sdl2.ttf;
import std.algorithm.comparison : min;
import std.math : abs;
import std.path : baseName;
import std.stdio : writeln, stderr;
import std.string : format, toStringz;

import xmp.xmp;
import xmp.libxmp : xmp_channel_info;

enum MinNote = 0x01;
enum MaxNote = 0x80; // 0x80 -> note off
enum InstrumentColours = [
  0xfce94f, 0xfcaf3e, 0xe9b96e, 0x8ae234, 0x729fcf, 0xad7fa8, 0xef2929,
  0xedd400, 0xf57900, 0xc17d11, 0x73d216, 0x3465a4, 0x75507b, 0xcc0000,
  0xeeeeec, 0xd3d7cf
];

enum NoteName = [
  "C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"
];

int main(string[] args)
{
  if (args.length != 2)
  {
    stderr.writeln("Usage: %s FILE".format(args[0]));
    return 1;
  }

  init();

  auto filename = args[1];
  auto xmp = new Xmp();
  auto baseTitle = "xmpvis - " ~ filename.baseName;

  auto win = SDL_CreateWindow(baseTitle.toStringz,
                              SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                              800, 600,
                              SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE);

  if (win is null)
  {
    stderr.writeln("SDL_CreateWindow error: %s".format(SDL_GetError()));
    SDL_Quit();
    return 2;
  }

  auto renderer = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
  SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);

  // load font
  auto font = TTF_OpenFont("data/vga.ttf", 16);
  if (font is null)
  {
    stderr.writeln("TTF_OpenFont error: %s".format(SDL_GetError()));
    stderr.writeln("Text will not be displayed");
  }

  assert(xmp.loadModule(filename));
  writeln("Playing song...");
  xmp.playModule();

  mainLoop(win, renderer, font, xmp, baseTitle);

  if (font !is null)
  {
    TTF_CloseFont(font);
  }
  SDL_DestroyRenderer(renderer);
  SDL_DestroyWindow(win);
  SDL_Quit();
  return 0;
}

void init()
{
  writeln("Using libxmp version %s".format(Xmp.xmpVersion));

  DerelictSDL2.load();
  assert(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) >= 0);
  DerelictSDL2TTF.load();
  assert(TTF_Init() >= 0);
}

void mainLoop(
  ref SDL_Window* win,
  ref SDL_Renderer* renderer,
  ref TTF_Font* font,
  ref Xmp xmp,
  ref string baseTitle)
{
  SDL_Event e;
  bool running = true;
  auto songName = xmp.moduleInfo.mod.name;
  auto channels = xmp.moduleInfo.mod.channels;

  while (running)
  {
    while (SDL_PollEvent(&e))
    {
      if (e.type == SDL_QUIT)
      {
        running = false;
      }
    }

    auto fi = xmp.frameInfo();
    win.setTitle(
      baseTitle,
      ": %s [%dbpm, spd: %d, pat: %02X, row: %02X/%02X]".format(
        songName, fi.bpm, fi.speed, fi.pattern, fi.row, fi.numRows - 1));

    draw(fi, win, renderer, font, channels);
  }
}

void draw(
  ref XmpFrameInfo fi,
  ref SDL_Window* win,
  ref SDL_Renderer* renderer,
  ref TTF_Font* font,
  int channels)
{
  int winWidth = 0;
  int winHeight = 0;
  SDL_GetWindowSize(win, &winWidth, &winHeight);

  SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
  SDL_RenderClear(renderer);

  auto blkHeight = winHeight / channels;
  auto blkWidth = winWidth / (MaxNote - MinNote);
  for (auto i = 0; i < channels; i++)
  {
    drawChannel(renderer, font, fi, i, blkWidth, blkHeight);
  }
  SDL_RenderPresent(renderer);
}

void setTitle(SDL_Window* win, string baseTitle, string addition)
{
  SDL_SetWindowTitle(win, (baseTitle ~ addition).toStringz);
}

void drawChannel(
  ref SDL_Renderer *renderer,
  ref TTF_Font* font,
  ref XmpFrameInfo fi,
  int channel,
  int blkWidth,
  int blkHeight)
{
  auto ci = fi.channel_info[channel];
  auto col = InstrumentColours[ci.instrument % InstrumentColours.length];
  ubyte red   = (col & 0xff0000) >> 16;
  ubyte green = (col & 0x00ff00) >> 8;
  ubyte blue  = col & 0x0000ff;

  drawNoteDots(renderer, channel, blkWidth, blkHeight);

  SDL_Rect r;
  r.x = blkWidth * (ci.note + (ci.pitchbend / 100)); // 100 == one note
  r.y = blkHeight * channel;
  r.w = blkWidth;
  r.h = blkHeight;

  adjustRectForPanning(&r, ci.pan);

  SDL_SetRenderDrawColor(renderer, red, green, blue, cast(ubyte)(min(4 * ci.volume, 0xff)));
  SDL_RenderFillRect(renderer, &r);

  if (font !is null && ci.instrument != 0xff && ci.volume > 0)
  {
    drawChannelInfo(renderer, font, r, ci, channel, blkWidth, blkHeight, red, green, blue);
  }
}

void drawNoteDots(
  ref SDL_Renderer* renderer,
  int channel,
  int blkWidth,
  int blkHeight)
{
  SDL_Rect r;
  r.w = r.h = blkWidth / 3;
  r.y = blkHeight * channel + (blkHeight / 2) - (r.h / 2);
  SDL_SetRenderDrawColor(renderer, 0x10, 0x10, 0x10, 255);
  for (auto n = 0; n < MaxNote; n++)
  {
    r.x = blkWidth * n + r.w;
    SDL_RenderFillRect(renderer, &r);
  }
}

void adjustRectForPanning(
  SDL_Rect* r,
  ubyte pan)
{
  auto baseHeight = r.h;
  short panHalf = pan - 0x80;  // this way a panning of centre is 0, left is < 0 and right > 0
  if (panHalf == 0)
  {
    return;
  }

  auto steps = baseHeight / 255.0;
  auto diff = cast(int)(abs(panHalf) * steps);

  r.h -= diff;
  if (panHalf > 0)
  {
    r.y += diff;
  }
}

void drawChannelInfo(
  ref SDL_Renderer* renderer,
  ref TTF_Font* font,
  ref SDL_Rect r,
  ref xmp_channel_info ci,
  int channel,
  int blkWidth,
  int blkHeight,
  ubyte red,
  ubyte green,
  ubyte blue)
{
  SDL_Color colour = { red, green, blue, 255 };

  auto note = ci.note > 0x80 ? "===" : "---";
  if (ci.note > 0)
  {
    note = "%s%d".format(NoteName[ci.note % 12], ci.note / 12);
  }

  drawTextWithShadow(renderer, font, "%s %02X v%02X p%02X".format(note, ci.instrument, ci.volume, ci.pan), colour, r, (r) {
    r.x = 5;
    r.y = (blkHeight * channel) + (blkHeight / 2) - (r.h / 2);
  });
}

void drawTextWithShadow(
  SDL_Renderer* renderer,
  TTF_Font* font,
  string text,
  SDL_Color colour,
  SDL_Rect pos,
  void delegate(SDL_Rect *r) posModifier = null)
{
  colour.a = 0x4f;
  drawText(renderer, font, text, colour, pos, (r) {
    if (posModifier !is null)
    {
      posModifier(r);
    }
    r.x++;
    r.y++;
  });
  colour.a = 0xff;
  drawText(renderer, font, text, colour, pos, posModifier);
}

void drawText(
  SDL_Renderer* renderer,
  TTF_Font* font,
  string text,
  SDL_Color colour,
  SDL_Rect pos,
  void delegate(SDL_Rect *r) posModifier = null)
{
  auto textSurface = TTF_RenderText_Solid(font, text.toStringz, colour);
  auto textTexture = SDL_CreateTextureFromSurface(renderer, textSurface);
  SDL_FreeSurface(textSurface);
  SDL_QueryTexture(textTexture, null, null, &pos.w, &pos.h);
  if (posModifier)
  {
    posModifier(&pos);
  }
  SDL_SetTextureAlphaMod(textTexture, colour.a);
  SDL_RenderCopy(renderer, textTexture, null, &pos);
  SDL_DestroyTexture(textTexture);
}
