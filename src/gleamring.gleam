import birl
import gleam/erlang/process
import gleam/function
import gleam/io

@external(erlang, "erlang", "halt")
pub fn terminate() -> Nil

pub type Message {
  SendMessage(Int)
}

pub fn main() {
  let num_m = 200_000
  let num_n = 30
  let start_time = birl.to_unix_milli(birl.now())

  start(num_m, num_n)
  let end_time = birl.to_unix_milli(birl.now())
  io.debug(end_time - start_time)
}

fn start(num_n, num_m) {
  let parent_subject = process.new_subject()
  let parent_target_sub = process.new_subject()

  let last_process = chain(parent_subject, parent_target_sub, num_m - 1)

  process.send(last_process, SendMessage(num_m * num_n - 1))
  loop(parent_target_sub, last_process)
}

fn chain(parent_subject, parent_target_sub, n) {
  case n {
    0 -> {
      parent_target_sub
    }
    _ -> {
      node_spawn(parent_subject, parent_target_sub)
      |> chain(parent_subject, _, n - 1)
    }
  }
}

fn node_spawn(parent_subj, target) {
  let process_init = fn() { initer(parent_subj, target) }
  process.start(running: process_init, linked: True)
  let assert Ok(child) = process.receive(parent_subj, 1000)
  child
}

fn initer(parent_sub, target) {
  let child_subject = process.new_subject()
  process.send(parent_sub, child_subject)
  loop(child_subject, target)
}

pub fn loop(my_subject, target_subject) {
  let selector =
    process.new_selector()
    |> process.selecting(for: my_subject, mapping: function.identity)

  let message = process.select_forever(selector)

  case message {
    SendMessage(num) -> {
      case num == 0 {
        True -> {
          Nil
        }
        False -> {
          process.send(target_subject, SendMessage(num - 1))
          loop(my_subject, target_subject)
        }
      }
    }
  }
}
