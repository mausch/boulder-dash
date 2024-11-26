(* Input Handling *)

module Make (_ : Engine.S) :
sig
  (** Recognised user inputs. *)
  type input =
    | Move of Cave.direction option * bool
    | Command of char

  val poll : unit -> input option
  (** Poll for user input. *)
end
