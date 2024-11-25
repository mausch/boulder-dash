(* Backend for TDSL Library *)

open Tsdl


(* Result monad *)

let ( let* ) = Result.bind
let ok = Result.ok
let get_ok = function
  | Ok x -> x
  | Error (`Msg s) -> failwith s


(* Output Window *)

type window = Sdl.window * Sdl.renderer

let open_window w h title = get_ok @@
  let* () = Sdl.init Sdl.Init.everything in
  let* win = Sdl.create_window ~w ~h title Sdl.Window.resizable in
  let* ren = Sdl.create_renderer win ~flags: Sdl.Renderer.presentvsync in
  Sdl.start_text_input ();
  ok (win, ren)

let close_window (win, ren) =
  Sdl.destroy_renderer ren;
  Sdl.destroy_window win;
  Sdl.quit ()


let width_window (win, _) = fst (Sdl.get_window_size win)
let height_window (win, _) = snd (Sdl.get_window_size win)


let clear_window (_, ren) (r, g, b) = get_ok @@
  let* () = Sdl.set_render_draw_color ren r g b 0 in
  let* () = Sdl.render_clear ren in
  let () = Sdl.render_present ren in
  ok ()

let fullscreen_window (win, _) = get_ok @@
  let flags = Sdl.get_window_flags win in
  let flags' = Sdl.Window.(
    if test flags fullscreen_desktop then windowed else fullscreen_desktop) in
  let* () = Sdl.set_window_fullscreen win flags' in
  ok ()


(* Animation Frames *)

let start_frame (_, _) = ()
let finish_frame (_, ren) = Sdl.render_present ren

let is_buffered_frame = true


(* Colors *)

type color = int * int * int

let create_color r g b = (r, g, b)

let draw_color (_, ren) (r, g, b) x y w h = get_ok @@
  let* () = Sdl.set_render_draw_color ren r g b 0 in
  let r = Sdl.Rect.create ~x ~y ~w ~h in
  let* () = Sdl.render_fill_rect ren (Some r) in
  ok ()


(* Images *)

type raw_image = Sdl.surface
type prepared_image = Sdl.texture

let load_image path = get_ok @@
  let* img = Sdl.load_bmp path in
  ok img

let extract_image img x y w h = get_ok @@
  let* img' = Sdl.create_rgb_surface ~w ~h ~depth: 32 0l 0l 0l 0l in
  let r = Sdl.Rect.create ~x ~y ~w ~h in
  let* () = Sdl.blit_surface ~src: img (Some r) ~dst: img' None in
  ok img'

let recolor_image img (r, g, b) (r', g', b') = get_ok @@
  let img' = Sdl.duplicate_surface img in
  assert (Sdl.get_surface_format_enum img' = Sdl.Pixel.format_rgb888);
  let* () = Sdl.lock_surface img' in
  let pixels = Sdl.get_surface_pixels img' Bigarray.Int8_unsigned in
  for i = 0 to Bigarray.Array1.dim pixels/4 - 1 do
    if pixels.{4*i} = b && pixels.{4*i + 1} = g && pixels.{4*i + 2} = r then
      (pixels.{4*i} <- b'; pixels.{4*i + 1} <- g'; pixels.{4*i + 2} <- r')
  done;
  let () = Sdl.unlock_surface img' in
  ok img'

let prepare_image (_, ren) _scale img = get_ok @@
  let* img' = Sdl.create_texture_from_surface ren img in
  ok img'

let draw_image (_, ren) img x y scale = get_ok @@
  let* _, _, (w, h) = Sdl.query_texture img in
  let dst = Sdl.Rect.create ~x ~y ~w: (w * scale) ~h: (h * scale) in
  let* () = Sdl.render_copy ren img ~dst in
  ok ()

let can_scale_image = true


(* Controls *)

type control = Sdl.joystick option

let open_control () = get_ok @@
  let* n = Sdl.num_joysticks () in
Printf.printf "[%d joysticks]\n%!" n;
  if n = 0 then
    ok None
  else
    let* joystick = Sdl.joystick_open 0 in
let* s = Sdl.joystick_name joystick in
let* na = Sdl.joystick_num_axes joystick in
let* nb = Sdl.joystick_num_buttons joystick in
Printf.printf "[`%s`: %d axes %d buttons]\n%!" s na nb;
    ok (Some joystick)

let close_control control =
  Option.iter Sdl.joystick_close control


let keys = let open Sdl.Scancode in  (* movement keys that don't remap *)
[
  (* Ordered such that horizontal movement takes precedence *)
  left, 'A'; right, 'D'; up, 'W'; down, 'S';
  a, 'A'; d, 'D'; w, 'W'; s, 'S'; x, 'X';
  space, ' '; return, '\r'; kp_enter, '\r';
  tab, '\t'; backspace, '\b'; escape, '\x1b';
  minus, '-'; equals, '+'; slash, '/';  (* minor convenience, no shift needed *)
]

let last_key = ref '\x00'

let get_key _control =
  let cooked = ref '\x00' in
  let event = Sdl.Event.create () in
  while Sdl.poll_event (Some event) do
    let typ = Sdl.Event.(get event typ) in
    if typ = Sdl.Event.quit then exit 0;
    if typ = Sdl.Event.text_input then
      let s = Sdl.Event.(get event text_input_text) in
      cooked := s.[String.length s - 1]  (* last cooked, ignore UTF-8 *)
  done;
  let state = Sdl.get_keyboard_state () in
  let shift = Sdl.Scancode.(state.{lshift} = 1 || state.{rshift} = 1) in
  let key =
    match List.find_opt (fun (code, _) -> state.{code} = 1) keys with
    | Some (_, char) -> char
    | None -> Char.uppercase_ascii !cooked  (* cooked input for meta controls *)
  in
  let rep = if key = !last_key then `Repeat else `Press in
  last_key := key;
  key, rep, shift


let get_axis joystick axis =
  let i = Sdl.joystick_get_axis joystick axis in
  if i < -8000 then -1 else if i > +8000 then +1 else 0

let get_joy = function
  | None -> 0, 0, false
  | Some joystick ->
    let dx = get_axis joystick 0 in
    let dy = get_axis joystick 1 in
    let button = Sdl.joystick_get_button joystick 0 = 1 in
Printf.printf "[joy %+d %+d %b]\n%!" dx dy button;
    dx, dy, button


(* Sound *)

(* Unfortunately, TSDL does not yet support SDL3, which has audio mixing built
 * in. Hence we hack a little by using multiple audio devices. *)

type sound = (char, Bigarray.int8_unsigned_elt) Sdl.bigarray
type voice =
{
  id : Sdl.audio_device_id;
  mutable sound : sound option;
  mutable start : float;
}
type audio = voice array

let audio_spec = Sdl.
  { as_freq = 44100;
    as_format = Audio.s16;
    as_channels = 1;
    as_silence = 0;
    as_samples = 0;
    as_size = 0l;
    as_callback = None;
  }

let open_audio () = get_ok @@
  let* () = Sdl.audio_init None in
  (* Try to get up to 8 voices (avoid implementing audio mixing ourselves) *)
  let rec loop i voices =
    if i = 0 then voices else
    match Sdl.open_audio_device None false audio_spec 0 with
    | Ok (id, _) -> loop (i - 1) ({id; sound = None; start = 0.0}::voices)
    | Error _ -> voices
  in
  ok (Array.of_list (loop 8 []))

let close_audio aud =
  Array.iter (fun voice -> Sdl.close_audio_device voice.id) aud;
  Sdl.audio_quit ()

let load_sound path = get_ok @@
  let* rw_ops = Sdl.rw_from_file path "r" in
  let* _spec, wav = Sdl.load_wav_rw rw_ops audio_spec Bigarray.Char in
  let* () = Sdl.rw_close rw_ops in
  ok wav

let has_sound sound voice =
  match voice.sound with
  | Some sound' -> sound == sound'
  | None -> false

let play_sound aud sound = get_ok @@
  let voice =
    match Array.find_opt (has_sound sound) aud with
    | Some voice -> voice
    | None ->  (* Not currently playing, find a free or the oldest voice *)
      let voice = ref aud.(0) in
      for i = 1 to Array.length aud - 1 do
        if Sdl.(get_audio_device_status aud.(i).id <> Audio.playing)
        || aud.(i).start < !voice.start then
          voice := aud.(i)
      done;
      !voice
  in
  voice.sound <- Some sound;
  voice.start <- Unix.gettimeofday ();
  Sdl.pause_audio_device voice.id true;
  Sdl.clear_queued_audio voice.id;
  let* () = Sdl.queue_audio voice.id sound in
  let () = Sdl.pause_audio_device voice.id false in
  ok ()

let stop_sound aud sound =
  match Array.find_opt (has_sound sound) aud with
  | None -> ()
  | Some voice ->
    Sdl.pause_audio_device voice.id true;
    Sdl.clear_queued_audio voice.id

let is_playing_sound aud sound =
  Array.exists (fun voice ->
    has_sound sound voice &&
    Sdl.(get_audio_device_status voice.id = Audio.playing)
  ) aud
