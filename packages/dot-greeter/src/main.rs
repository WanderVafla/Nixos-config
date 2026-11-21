//! dot-greeter: a greetd greeter that shows only dots on the console.

mod app;
mod args;
mod input;
mod screen;
mod session;
mod style;
mod worker;

use args::{Args, USAGE};
use session::Conversation;
use std::process::ExitCode;

fn main() -> ExitCode {
    let args = match Args::parse(std::env::args().skip(1)) {
        Ok(args) => args,
        Err(message) => {
            eprintln!("dot-greeter: {message}\n{USAGE}");
            return ExitCode::from(2);
        }
    };
    match app::run(Conversation::new(args.user, args.cmd, args.env), args.style) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("dot-greeter: {error}");
            ExitCode::FAILURE
        }
    }
}
