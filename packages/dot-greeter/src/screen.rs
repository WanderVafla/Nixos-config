//! Draws a single centered line on the console and restores the terminal on exit or panic.

use crate::session::View;
use crate::style::Style;
use crossterm::cursor::{Hide, MoveTo, Show};
use crossterm::style::{Color, Print, ResetColor, SetForegroundColor};
use crossterm::terminal::{self, Clear, ClearType, EnterAlternateScreen, LeaveAlternateScreen};
use crossterm::{execute, queue};
use std::io::{self, Write};

const FAILED: char = '!';
const BLANK: (Color, char) = (Color::Reset, ' ');
/// Frames the running light spends past the last dot before it starts again.
const CHECKING_GAP: usize = 2;

/// What one frame shows.
pub struct Frame<'a> {
    pub view: &'a View,
    /// Number of dots: typed characters, or the length of the answer being checked.
    pub dots: usize,
    /// Typed answer to a visible question.
    pub echo: &'a str,
    /// Animation step, counted from when the answer was sent.
    pub tick: usize,
    /// Blink phase of the cursor.
    pub cursor: bool,
    /// Wrong passwords in a row, to switch the placeholder to the hint.
    pub failures: u32,
    /// A fingerprint scan just failed: the pulsing dot turns to the wrong color.
    pub scan_failed: bool,
}

pub struct Screen {
    out: io::Stdout,
    style: Style,
}

impl Screen {
    pub fn open(style: Style) -> io::Result<Self> {
        let previous_hook = std::panic::take_hook();
        std::panic::set_hook(Box::new(move |info| {
            restore();
            previous_hook(info);
        }));
        terminal::enable_raw_mode()?;
        let mut out = io::stdout();
        execute!(out, EnterAlternateScreen, Hide, Clear(ClearType::All))?;
        Ok(Self { out, style })
    }

    pub fn draw(&mut self, frame: &Frame) -> io::Result<()> {
        let (cols, rows) = terminal::size()?;
        let max = usize::from(cols.saturating_sub(2)).max(1);
        let cells: Vec<(Color, char)> = line(frame, &self.style).into_iter().take(max).collect();
        let width = u16::try_from(cells.len()).unwrap_or(cols);
        queue!(
            self.out,
            Clear(ClearType::All),
            MoveTo(cols.saturating_sub(width) / 2, rows / 2)
        )?;
        for (color, c) in cells {
            queue!(self.out, SetForegroundColor(color), Print(c))?;
        }
        queue!(self.out, ResetColor)?;
        self.out.flush()
    }
}

/// The characters of the line, each with its color.
///
/// With a cursor, dot lines always end with one extra cell (the cursor, or a space while it is
/// off or the answer is being checked), so the centered line never shifts. Without a cursor
/// there is no extra cell at all.
fn line(frame: &Frame, style: &Style) -> Vec<(Color, char)> {
    let dots = |n: usize, color: Color| vec![(color, style.dot); n];
    let tail = |visible: bool| {
        style.cursor.map(|c| {
            if visible && frame.cursor {
                (style.cursor_color, c)
            } else {
                BLANK
            }
        })
    };
    let cursor = tail(true);
    let then = |mut cells: Vec<(Color, char)>, last: Option<(Color, char)>| {
        cells.extend(last);
        cells
    };
    match frame.view {
        View::Waiting | View::Secret if frame.dots == 0 => {
            idle(cursor, style.idle_text(frame.failures, false))
        }
        View::Fingerprint | View::FingerprintFailed if frame.dots == 0 => {
            let pulse = if frame.scan_failed {
                style.wrong
            } else {
                // Dark, middle, bright, middle: a slow breath.
                let steps = [
                    style.placeholder_color,
                    style.cursor_color,
                    style.fingerprint_color,
                ];
                steps[[0, 1, 2, 1][frame.tick % 4]]
            };
            idle(
                Some((pulse, style.dot)),
                style.idle_text(frame.failures, true),
            )
        }
        View::Waiting | View::Secret | View::Fingerprint | View::FingerprintFailed => {
            then(dots(frame.dots, style.typed), cursor)
        }
        View::Visible(question) => {
            let text = format!("{question} {}", frame.echo);
            then(
                text.chars().map(|c| (style.placeholder_color, c)).collect(),
                cursor,
            )
        }
        View::Checking => {
            let n = frame.dots.max(1);
            let light = frame.tick % (n + CHECKING_GAP);
            let cells = (0..n)
                .map(|i| {
                    (
                        if i == light {
                            style.typed
                        } else {
                            style.checking
                        },
                        style.dot,
                    )
                })
                .collect();
            then(cells, tail(false))
        }
        View::Wrong => then(dots(frame.dots.max(1), style.wrong), tail(false)),
        View::Failed => vec![(style.placeholder_color, FAILED)],
    }
}

/// An optional leading mark (cursor or pulsing dot) with a space, then a dim text.
fn idle(mark: Option<(Color, char)>, (text, color): (&str, Color)) -> Vec<(Color, char)> {
    let mut cells: Vec<(Color, char)> = mark.into_iter().flat_map(|m| [m, BLANK]).collect();
    cells.extend(text.chars().map(|c| (color, c)));
    cells
}

impl Drop for Screen {
    fn drop(&mut self) {
        restore();
    }
}

fn restore() {
    let _ = execute!(
        io::stdout(),
        Clear(ClearType::All),
        Show,
        LeaveAlternateScreen
    );
    let _ = terminal::disable_raw_mode();
}

#[cfg(test)]
mod tests {
    use super::*;

    fn frame(view: &View, dots: usize, tick: usize, cursor: bool) -> Frame<'_> {
        Frame {
            view,
            dots,
            echo: "",
            tick,
            cursor,
            failures: 0,
            scan_failed: false,
        }
    }

    fn text(cells: &[(Color, char)]) -> String {
        cells.iter().map(|(_, c)| c).collect()
    }

    #[test]
    fn checking_light_runs_over_the_dots() {
        use Color::{DarkGrey as D, Reset as R, White as W};
        let style = Style::default();
        let colors = |tick| -> Vec<Color> {
            line(&frame(&View::Checking, 3, tick, true), &style)
                .into_iter()
                .map(|(c, _)| c)
                .collect()
        };
        assert_eq!(colors(0), [W, D, D, R]);
        assert_eq!(colors(2), [D, D, W, R]);
        // Past the last dot the light is off for CHECKING_GAP frames, then starts again.
        assert_eq!(colors(3), [D, D, D, R]);
        assert_eq!(colors(5), [W, D, D, R]);
    }

    #[test]
    fn empty_input_shows_cursor_and_placeholder() {
        let style = Style::default();
        let cells = line(&frame(&View::Secret, 0, 0, true), &style);
        assert_eq!(cells[0], (style.cursor_color, '│'));
        assert_eq!(text(&cells[2..]), style.placeholder);
    }

    #[test]
    fn hint_shows_after_enough_wrong_passwords() {
        let style = Style::default();
        let mut f = frame(&View::Secret, 0, 0, true);
        f.failures = 3;
        let cells = line(&f, &style);
        assert_eq!(text(&cells[2..]), "check caps lock");
        assert_eq!(cells[2].0, style.hint_color);
    }

    #[test]
    fn fingerprint_dot_pulses_and_turns_red_after_a_failed_scan() {
        let s = Style::default();
        let pulse = |tick, scan_failed| {
            let mut f = frame(&View::Fingerprint, 0, tick, true);
            f.scan_failed = scan_failed;
            line(&f, &s)[0]
        };
        assert_eq!(pulse(0, false), (s.placeholder_color, s.dot));
        assert_eq!(pulse(2, false), (s.fingerprint_color, s.dot));
        assert_eq!(pulse(3, false), (s.cursor_color, s.dot));
        assert_eq!(pulse(2, true), (s.wrong, s.dot));
        let cells = line(&frame(&View::Fingerprint, 0, 0, true), &s);
        assert_eq!(text(&cells[2..]), s.fingerprint);
    }

    #[test]
    fn typing_during_the_fingerprint_wait_shows_dots() {
        let s = Style::default();
        let cells = line(&frame(&View::Fingerprint, 2, 0, true), &s);
        assert_eq!(text(&cells), format!("{0}{0}│", s.dot));
    }

    #[test]
    fn typed_dots_end_with_the_blinking_cursor() {
        let s = Style::default();
        let (dot, cur) = ((s.typed, s.dot), (s.cursor_color, '│'));
        assert_eq!(line(&frame(&View::Secret, 2, 0, true), &s), [dot, dot, cur]);
        assert_eq!(
            line(&frame(&View::Secret, 2, 0, false), &s),
            [dot, dot, BLANK]
        );
    }

    #[test]
    fn custom_characters_are_used() {
        let style = Style {
            dot: '*',
            cursor: Some('_'),
            ..Style::default()
        };
        assert_eq!(
            text(&line(&frame(&View::Secret, 2, 0, true), &style)),
            "**_"
        );
    }

    #[test]
    fn without_cursor_there_is_no_extra_cell() {
        let s = Style {
            cursor: None,
            ..Style::default()
        };
        let idle = line(&frame(&View::Secret, 0, 0, true), &s);
        assert_eq!(text(&idle), s.placeholder);
        let typing = line(&frame(&View::Secret, 3, 0, true), &s);
        let checking = line(&frame(&View::Checking, 3, 0, true), &s);
        assert_eq!(text(&typing), s.dot.to_string().repeat(3));
        assert_eq!(typing.len(), checking.len());
    }

    #[test]
    fn sending_keeps_the_line_width() {
        let s = Style::default();
        let typing = line(&frame(&View::Secret, 4, 0, true), &s);
        let checking = line(&frame(&View::Checking, 4, 0, true), &s);
        let wrong = line(&frame(&View::Wrong, 4, 0, true), &s);
        assert_eq!(typing.len(), checking.len());
        assert_eq!(typing.len(), wrong.len());
    }
}
