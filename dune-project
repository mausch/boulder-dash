(lang dune 3.2)

(name boulder_dash)
(authors "Andreas Rossberg")
(source (github rossberg/boulder-dash))
(license CC-BY-NC-4.0)
(documentation https://github.com/rossberg/boulder-dash/blob/main/README.md)

(package
  (name boulder_dash)
  (synopsis "Boulder Dash")
  (description "A clone of the classic Boulder Dash game")
  (depends ocaml dune graphics)
)
