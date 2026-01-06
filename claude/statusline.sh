#!/bin/bash

# Single jq call extracts all values and formats output
jq -r '
  # Colors
  def magenta: "\u001b[35m";
  def green: "\u001b[32m";
  def yellow: "\u001b[33m";
  def red: "\u001b[31m";  # for high context usage
  def dim: "\u001b[2m";
  def reset: "\u001b[0m";

  # Extract values
  (.model.display_name // .model.id // "Claude") as $model |
  (.context_window.context_window_size // 200000) as $ctx_size |
  (.context_window.current_usage // null) as $usage |

  # Calculate context percentage
  (if $usage then
    (($usage.input_tokens // 0) + ($usage.cache_creation_input_tokens // 0) + ($usage.cache_read_input_tokens // 0)) * 100 / $ctx_size | floor
  else 0 end) as $pct |

  # Build parts
  [
    (magenta + $model + reset),
    (if $usage then
      (if $pct < 50 then green elif $pct < 80 then yellow else red end) + "\($pct)%" + reset
    else empty end)
  ] | join(" " + dim + "|" + reset + " ")
'
