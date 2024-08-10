type data = { product_name : string; amount_votes : int; result : float }
type dataset = data list

let up_down { amount_votes; result; _ } =
  let voters = Float.of_int amount_votes in
  let up = result /. 100.0 *. voters in
  let down = voters -. up in
  (Float.to_int up, Float.to_int down)

let make ?(prefix = "Product ") product_name amount_votes result =
  let product_name = prefix ^ product_name in
  { product_name; amount_votes; result }

let make_ud ?prefix product_name up down =
  let amount_votes = up + down in
  let result = Float.of_int up /. Float.of_int amount_votes *. 100. in
  make ?prefix product_name amount_votes result

let pp_set ppf set =
  Format.fprintf ppf "\nName\t\tVoters\tResult\tUpvotes\tDownvotes\n\n%a"
    (Format.pp_print_list ~pp_sep:Format.pp_print_newline
       (fun ppf ({ product_name; amount_votes; result } as data) ->
         let up, down = up_down data in
         Format.fprintf ppf "%s\t% 5d\t%.01f\t% 5d\t% 5d" product_name
           amount_votes result up down))
    set

let result { result; _ } = result

let dataset =
  [
    make_ud "A" 32 68
  ; make_ud "B" 890 110
  ; make_ud "C" 2 0
  ; make_ud "D" 1530 1470
  ; make_ud "E" 524 235
  ; make_ud "F" 118 472
  ; make_ud "G" 25 75
  ]

let update ?(dataset = dataset) name ~up ~down =
  List.map
    (fun data ->
      if String.equal name data.product_name then
        make_ud ~prefix:"" name up down
      else data)
    dataset

let sort ?(dataset = dataset) compare = List.sort compare dataset
