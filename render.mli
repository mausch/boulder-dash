(* Graphics and rendering backend *)

type grid_pos = int * int
(** Represents a position in the cave map,
   or the character matrix of the info area. *)

val init : unit -> unit
(** Initializes the graphics backend. *)

val deinit : unit -> unit
(** Terminates the graphics backend. *)

val clear : unit -> unit
(** Clears the graphics window. *)

val reset : grid_pos -> float -> unit
(** [reset (w, h) fpt] resets the window state to a new cave size and refresh
   rate [fpt], denoting how many animation frames fit into one game turn. *)

val scroll : grid_pos -> unit
(** If the given grid position is too close to the window borders, initiates
   scrolling to a position where it is centered. Can be reinvoked to update
   the current scrolling target. If the play field is smaller than the window,
   instead scroll such that the whole playfield is centered. *)


val flash : unit -> unit
(** Initiates a white screen flash animation. *)

val flicker : unit -> unit
(** Initiates a 5 second flickering animation for space tiles. *)


val prepare : unit -> unit
(** Starts a new animation frame. *)

val finalize : unit -> unit
(** Ends an animation frame. *)

val render : grid_pos -> Cave.tile option ->
  frame: int -> face: Cave.direction option -> won: bool -> force: bool -> unit
(** Draw a single sprite for the tile at the given cave grid position, using the
  suitable animation step for the current global [frame]. The actual screen
  position depends on the current scolling position. If the tile is [None], show
  a concealed tile instead. The tile is not redrawn if it is not animated, unless
  [force] is set to refresh. The [face] parameter denotes the direction that
  Rockford is facing this turn, if any, [won] whether Rockford has already
  exited the cave, since both can affect animations. *)


type color = White | Yellow
(** Represents allowable text colors. *)

val print : color -> grid_pos -> string-> unit
(** Prints text in the requested color at the given info grid position. *)
