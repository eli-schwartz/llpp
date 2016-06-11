open Utils;;

let debug = true

type cursor =
    | CURSOR_INHERIT
    | CURSOR_INFO
    | CURSOR_CYCLE
    | CURSOR_FLEUR
    | CURSOR_TEXT

type winstate =
    | MaxVert
    | MaxHorz
    | Fullscreen

type visiblestate =
  | Unobscured
  | PartiallyObscured
  | FullyObscured

class type t = object
  method display  : unit
  method map      : bool -> unit
  method expose   : unit
  method visible  : visiblestate -> unit
  method reshape  : int -> int -> unit
  method mouse    : int -> bool -> int -> int -> int -> unit
  method motion   : int -> int -> unit
  method pmotion  : int -> int -> unit
  method key      : int -> int -> unit
  method enter    : int -> int -> unit
  method leave    : unit
  method winstate : winstate list -> unit
  method quit     : unit
end

let onot = object
  method display         = ()
  method map _           = ()
  method expose          = ()
  method visible _       = ()
  method reshape _ _     = ()
  method mouse _ _ _ _ _ = ()
  method motion _ _      = ()
  method pmotion _ _     = ()
  method key _ _         = ()
  method enter _ _       = ()
  method leave           = ()
  method winstate _      = ()
  method quit            = exit 0
end

type state =
  {
    mutable t: t;
    mutable fd: Unix.file_descr;
  }

let state =
  {
    t = onot;
    fd = Unix.stdin;
  }

let readstr sock n = try readstr sock n with End_of_file -> state.t#quit; assert false

let setcursor _ = ()

external settitle: string -> unit = "ml_settitle"

external swapb: unit -> unit = "ml_swapb"

let reshape w h =
  vlog "reshape w %d h %d" w h
  (* stub_reshape w h *)

let key_down key mask =
  if debug then Printf.eprintf "key down: %d %x\n%!" key mask;
  state.t#key key mask

let key_up key mask =
  if debug then Printf.eprintf "key up: %d %x\n%!" key mask;
  state.t#key key mask

let mouse_down b x y mask =
  if debug then Printf.eprintf "mouse down: %d %d %x\n%!" x y mask;
  state.t#mouse b true x y mask

let mouse_up b x y mask =
  if debug then Printf.eprintf "mouse up: %d %d %x\n%!" x y mask;
  state.t#mouse b false x y mask

let mouse_moved x y =
  if debug then Printf.eprintf "mouse moved: %d %d\n%!" x y;
  state.t#pmotion x y

let quit () =
  if debug then Printf.eprintf "quit\n%!";
  state.t#quit

let reshaped w h =
  if debug then Printf.eprintf "reshape %d %d\n%!" w h;
  state.t#reshape w h

let entered w h =
  if debug then Printf.eprintf "enter %d %d\n%!" w h;
  state.t#enter w h

let left () =
  if debug then Printf.eprintf "leave\n%!";
  state.t#leave

let display () =
  if debug then Printf.eprintf "display\n%!";
  state.t#display

let () =
  Callback.register "llpp_key_down" key_down;
  Callback.register "llpp_key_up" key_up;
  Callback.register "llpp_mouse_down" mouse_down;
  Callback.register "llpp_mouse_up" mouse_up;
  Callback.register "llpp_mouse_moved" mouse_moved;
  Callback.register "llpp_quit" quit;
  Callback.register "llpp_reshaped" reshaped;
  Callback.register "llpp_entered" entered;
  Callback.register "llpp_left" left;
  Callback.register "llpp_display" display

(* 0 -> swapb *)

(* 0 -> map
   1 -> expose
   2 -> visible
   3 -> reshape
   4 -> mouse
   5 -> motion
   6 -> pmotion
   7 -> key
   8 -> enter
   9 -> leave
  10 -> winstate
  11 -> quit
  13 -> response *)

let readresp sock =
  prerr_endline "readresp";
  let resp = readstr sock 32 in
  prerr_endline "after readresp";
  let opcode = r8 resp 0 in
  match opcode with
  | 0 ->
    let mapped = r8 resp 16 <> 0 in
    vlog "map %B" mapped;
    state.t#map mapped
  | 1 ->
    vlog "expose";
    state.t#expose
  | 3 ->
    let w = r16 resp 16 in
    let h = r16 resp 18 in
    vlog "reshape width %d height %d" w h;
    state.t#reshape w h
  | 7 ->
    let key = r32 resp 16 in
    let mask = r32 resp 20 in
    vlog "keydown key %d mask %d" key mask;
    state.t#key key mask
  | 8 ->
    let x = r16 resp 16 in
    let y = r16 resp 18 in
    vlog "enter x %d y %d" x y;
    state.t#enter x y
  | 9 ->
    vlog "leave";
    state.t#leave
  | _ ->
    vlog "unknown server message %d" opcode

external completeinit: int -> int -> unit = "ml_completeinit"

external file_descr_of_int: int -> Unix.file_descr = "%identity"

let init t _ w h platform =
  let fd = int_of_string (Sys.getenv "LLPP_DISPLAY") in
  Printf.eprintf "LLPP_DISPLAY=%d\n%!" fd;
  let fd = file_descr_of_int fd in
  state.t <- t;
  state.fd <- fd;
  completeinit w h;
  fd, w, h

let fullscreen () =
  vlog "fullscreen"
  (* stub_fullscreen () *)

let activatewin () = ()

let mapwin () = ()

let metamask = 1 lsl 19

let altmask = 1 lsl 19

let shiftmask = 1 lsl 17

let ctrlmask = 1 lsl 18

let withalt mask = mask land metamask != 0

let withctrl mask = mask land ctrlmask != 0

let withshift mask = mask land shiftmask != 0

let withmeta mask = mask land metamask != 0

let withnone mask = mask land (altmask + ctrlmask + shiftmask + metamask) = 0

let keyname _ = ""

let namekey _ = 0

external setwinbgcol: int -> unit = "ml_setbgcol"
