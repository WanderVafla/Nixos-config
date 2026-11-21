//! The text the user is typing. It may be a password, so it is wiped from memory when dropped.

use crossterm::event::{KeyCode, KeyEvent, KeyEventKind, KeyModifiers};
use zeroize::Zeroizing;

pub enum Action {
    Submit,
    Changed,
    Nothing,
}

#[derive(Default)]
pub struct Input {
    text: Zeroizing<String>,
}

impl Input {
    pub fn handle(&mut self, key: KeyEvent) -> Action {
        if key.kind == KeyEventKind::Release {
            return Action::Nothing;
        }
        let ctrl = key.modifiers.contains(KeyModifiers::CONTROL);
        match key.code {
            KeyCode::Enter => Action::Submit,
            KeyCode::Backspace => {
                self.text.pop();
                Action::Changed
            }
            KeyCode::Esc => {
                self.clear();
                Action::Changed
            }
            KeyCode::Char('u') if ctrl => {
                self.clear();
                Action::Changed
            }
            // Other Ctrl shortcuts (Ctrl+C included) must neither type nor quit.
            KeyCode::Char(_) if ctrl => Action::Nothing,
            KeyCode::Char(c) => {
                self.text.push(c);
                Action::Changed
            }
            _ => Action::Nothing,
        }
    }

    /// Hands the text over and leaves the input empty.
    pub fn take(&mut self) -> String {
        std::mem::take(&mut *self.text)
    }

    pub fn clear(&mut self) {
        // Zeroizing wipes the old buffer when it is replaced.
        self.text = Zeroizing::default();
    }

    pub fn len(&self) -> usize {
        self.text.chars().count()
    }

    pub fn text(&self) -> &str {
        &self.text
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn key(code: KeyCode, modifiers: KeyModifiers) -> KeyEvent {
        KeyEvent::new(code, modifiers)
    }

    fn type_text(input: &mut Input, text: &str) {
        for c in text.chars() {
            input.handle(key(KeyCode::Char(c), KeyModifiers::NONE));
        }
    }

    #[test]
    fn typing_and_backspace() {
        let mut input = Input::default();
        type_text(&mut input, "abc");
        input.handle(key(KeyCode::Backspace, KeyModifiers::NONE));
        assert_eq!(input.text(), "ab");
        assert_eq!(input.len(), 2);
    }

    #[test]
    fn ctrl_u_and_esc_clear() {
        let mut input = Input::default();
        type_text(&mut input, "abc");
        input.handle(key(KeyCode::Char('u'), KeyModifiers::CONTROL));
        assert_eq!(input.len(), 0);
        type_text(&mut input, "abc");
        input.handle(key(KeyCode::Esc, KeyModifiers::NONE));
        assert_eq!(input.len(), 0);
    }

    #[test]
    fn ctrl_c_is_ignored() {
        let mut input = Input::default();
        let action = input.handle(key(KeyCode::Char('c'), KeyModifiers::CONTROL));
        assert!(matches!(action, Action::Nothing));
        assert_eq!(input.len(), 0);
    }

    #[test]
    fn take_empties_the_input() {
        let mut input = Input::default();
        type_text(&mut input, "pw");
        assert_eq!(input.take(), "pw");
        assert_eq!(input.len(), 0);
    }
}
