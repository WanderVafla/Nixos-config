//! Look of the greeter: characters, colors, texts and timings, with their defaults.

use crossterm::style::Color;
use std::time::Duration;

/// Text that replaces the placeholder after several wrong passwords in a row.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Hint {
    pub after: u32,
    pub text: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Style {
    pub placeholder: String,
    pub dot: char,
    /// Blinking cursor; `None` hides it.
    pub cursor: Option<char>,
    pub typed: Color,
    pub cursor_color: Color,
    pub placeholder_color: Color,
    pub wrong: Color,
    /// Dots that are not lit during the checking animation.
    pub checking: Color,
    pub hint_color: Color,
    /// Text next to the pulsing dot while the fingerprint reader waits.
    pub fingerprint: String,
    /// Brightest color of the pulsing dot.
    pub fingerprint_color: Color,
    pub blink: Duration,
    pub hint: Option<Hint>,
}

impl Default for Style {
    fn default() -> Self {
        Self {
            placeholder: "password".into(),
            dot: '•',
            cursor: Some('│'),
            typed: Color::White,
            cursor_color: Color::Grey,
            placeholder_color: Color::DarkGrey,
            wrong: Color::Red,
            checking: Color::DarkGrey,
            hint_color: Color::DarkRed,
            fingerprint: "touch the sensor".into(),
            fingerprint_color: Color::White,
            blink: Duration::from_millis(530),
            hint: Some(Hint {
                after: 3,
                text: "check caps lock".into(),
            }),
        }
    }
}

impl Style {
    /// Text and color shown while nothing is typed. After enough wrong passwords in a row the
    /// hint wins, also over the fingerprint text: every new attempt starts with the reader.
    pub fn idle_text(&self, failures: u32, fingerprint: bool) -> (&str, Color) {
        match &self.hint {
            Some(hint) if failures >= hint.after => (&hint.text, self.hint_color),
            _ if fingerprint => (&self.fingerprint, self.placeholder_color),
            _ => (&self.placeholder, self.placeholder_color),
        }
    }

    /// Sets one color from `KEY=NAME`, e.g. `typed=white`.
    pub fn set_color(&mut self, pair: &str) -> Result<(), String> {
        let (key, name) = pair
            .split_once('=')
            .ok_or(format!("--color expects KEY=NAME, got {pair}"))?;
        let color = parse_color(name)?;
        let slot = match key {
            "typed" => &mut self.typed,
            "cursor" => &mut self.cursor_color,
            "placeholder" => &mut self.placeholder_color,
            "wrong" => &mut self.wrong,
            "checking" => &mut self.checking,
            "hint" => &mut self.hint_color,
            "fingerprint" => &mut self.fingerprint_color,
            _ => return Err(format!("unknown color key {key}")),
        };
        *slot = color;
        Ok(())
    }
}

/// The 16 console colors by name.
pub fn parse_color(name: &str) -> Result<Color, String> {
    Ok(
        match name.to_ascii_lowercase().replace(['-', '_'], "").as_str() {
            "black" => Color::Black,
            "darkred" => Color::DarkRed,
            "darkgreen" => Color::DarkGreen,
            "darkyellow" => Color::DarkYellow,
            "darkblue" => Color::DarkBlue,
            "darkmagenta" => Color::DarkMagenta,
            "darkcyan" => Color::DarkCyan,
            "grey" | "gray" => Color::Grey,
            "darkgrey" | "darkgray" => Color::DarkGrey,
            "red" => Color::Red,
            "green" => Color::Green,
            "yellow" => Color::Yellow,
            "blue" => Color::Blue,
            "magenta" => Color::Magenta,
            "cyan" => Color::Cyan,
            "white" => Color::White,
            _ => return Err(format!("unknown color {name}")),
        },
    )
}

/// Exactly one character.
pub fn parse_char(text: &str) -> Result<char, String> {
    let mut chars = text.chars();
    match (chars.next(), chars.next()) {
        (Some(c), None) => Ok(c),
        _ => Err(format!("expected one character, got {text:?}")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hint_replaces_the_placeholder_after_enough_failures() {
        let style = Style::default();
        assert_eq!(style.idle_text(2, false), ("password", Color::DarkGrey));
        assert_eq!(
            style.idle_text(3, false),
            ("check caps lock", Color::DarkRed)
        );
        assert_eq!(
            style.idle_text(3, true),
            ("check caps lock", Color::DarkRed)
        );
    }

    #[test]
    fn no_hint_keeps_the_placeholder() {
        let style = Style {
            hint: None,
            ..Style::default()
        };
        assert_eq!(style.idle_text(10, false).0, "password");
        assert_eq!(style.idle_text(10, true).0, "touch the sensor");
    }

    #[test]
    fn colors_by_name_and_key() {
        let mut style = Style::default();
        style.set_color("typed=dark-cyan").unwrap();
        assert_eq!(style.typed, Color::DarkCyan);
        assert!(style.set_color("typed=pink").is_err());
        assert!(style.set_color("nope=red").is_err());
    }

    #[test]
    fn single_characters_only() {
        assert_eq!(parse_char("•"), Ok('•'));
        assert!(parse_char("").is_err());
        assert!(parse_char("ab").is_err());
    }
}
