//! Command-line arguments; see USAGE.

use crate::style::{Hint, Style, parse_char};
use std::time::Duration;

pub const USAGE: &str = "\
usage: dot-greeter --user NAME [OPTIONS] -- CMD [ARGS]...
  --env KEY=VALUE        environment of the session (repeatable)
  --placeholder TEXT     hint shown while nothing is typed
  --dot CHAR             character for each typed letter
  --cursor CHAR          blinking cursor character
  --no-cursor            no cursor at all
  --color KEY=NAME       KEY: typed, cursor, placeholder, wrong, checking, hint, fingerprint
  --blink-ms N           half a blink period of the cursor
  --hint TEXT            placeholder after several wrong passwords
  --hint-after N         wrong passwords in a row before the hint, 0 turns it off
  --fingerprint TEXT     text next to the pulsing dot while the fingerprint reader waits";

#[derive(Debug, PartialEq, Eq)]
pub struct Args {
    pub user: String,
    pub env: Vec<String>,
    pub cmd: Vec<String>,
    pub style: Style,
}

impl Args {
    pub fn parse(mut args: impl Iterator<Item = String>) -> Result<Self, String> {
        let mut user = None;
        let mut env = Vec::new();
        let mut style = Style::default();
        let mut hint = style.hint.clone().unwrap_or(Hint {
            after: 0,
            text: String::new(),
        });
        while let Some(arg) = args.next() {
            if arg == "--" {
                break;
            }
            let mut value = || args.next().ok_or(format!("{arg} needs a value"));
            match arg.as_str() {
                "--user" => user = Some(value()?),
                "--env" => {
                    let pair = value()?;
                    if !pair.contains('=') {
                        return Err(format!("--env expects KEY=VALUE, got {pair}"));
                    }
                    env.push(pair);
                }
                "--placeholder" => style.placeholder = value()?,
                "--dot" => style.dot = parse_char(&value()?)?,
                "--cursor" => style.cursor = Some(parse_char(&value()?)?),
                "--no-cursor" => style.cursor = None,
                "--color" => style.set_color(&value()?)?,
                "--blink-ms" => {
                    style.blink = Duration::from_millis(number(&value()?)?.max(1).into())
                }
                "--hint" => hint.text = value()?,
                "--hint-after" => hint.after = number(&value()?)?,
                "--fingerprint" => style.fingerprint = value()?,
                other => return Err(format!("unknown argument {other}")),
            }
        }
        style.hint = (hint.after > 0).then_some(hint);
        let cmd: Vec<String> = args.collect();
        let user = user.ok_or("--user is required")?;
        if cmd.is_empty() {
            return Err("the session command after -- is missing".into());
        }
        Ok(Self {
            user,
            env,
            cmd,
            style,
        })
    }
}

fn number(text: &str) -> Result<u32, String> {
    text.parse()
        .map_err(|_| format!("expected a number, got {text}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crossterm::style::Color;

    fn parse(args: &[&str]) -> Result<Args, String> {
        Args::parse(args.iter().map(|s| s.to_string()))
    }

    #[test]
    fn full_command_line() {
        let args = parse(&[
            "--user", "me", "--env", "A=1", "--env", "B=2", "--", "hypr", "--flag",
        ])
        .unwrap();
        assert_eq!(args.user, "me");
        assert_eq!(args.env, ["A=1", "B=2"]);
        assert_eq!(args.cmd, ["hypr", "--flag"]);
        assert_eq!(args.style, Style::default());
    }

    #[test]
    fn style_options() {
        let args = parse(&[
            "--user",
            "me",
            "--placeholder",
            "pass phrase",
            "--dot",
            "*",
            "--cursor",
            "_",
            "--color",
            "wrong=yellow",
            "--blink-ms",
            "400",
            "--hint",
            "caps?",
            "--hint-after",
            "2",
            "--",
            "hypr",
        ])
        .unwrap();
        let style = args.style;
        assert_eq!(style.placeholder, "pass phrase");
        assert_eq!((style.dot, style.cursor), ('*', Some('_')));
        assert_eq!(style.wrong, Color::Yellow);
        assert_eq!(style.blink, Duration::from_millis(400));
        assert_eq!(
            style.hint,
            Some(Hint {
                after: 2,
                text: "caps?".into()
            })
        );
    }

    #[test]
    fn no_cursor_flag() {
        let args = parse(&["--user", "me", "--no-cursor", "--", "hypr"]).unwrap();
        assert_eq!(args.style.cursor, None);
    }

    #[test]
    fn zero_attempts_turns_the_hint_off() {
        let args = parse(&["--user", "me", "--hint-after", "0", "--", "hypr"]).unwrap();
        assert_eq!(args.style.hint, None);
    }

    #[test]
    fn invalid_command_lines() {
        assert!(parse(&["--", "hypr"]).is_err());
        assert!(parse(&["--user", "me"]).is_err());
        assert!(parse(&["--user", "me", "--env", "BAD", "--", "x"]).is_err());
        assert!(parse(&["--user", "me", "--dot", "ab", "--", "x"]).is_err());
        assert!(parse(&["--user", "me", "--blink-ms", "fast", "--", "x"]).is_err());
    }
}
