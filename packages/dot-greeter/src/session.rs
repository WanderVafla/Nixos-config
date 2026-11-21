//! The greetd conversation as a pure state machine, so it can be tested without a socket.

use greetd_ipc::{AuthMessageType, ErrorType, Request, Response};
use std::time::Duration;

/// How long red dots stay after a wrong password.
pub const WRONG_PAUSE: Duration = Duration::from_secs(1);
/// How long the error mark stays before the conversation starts over.
pub const FAILED_PAUSE: Duration = Duration::from_secs(2);

/// What the screen shows for the current step.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum View {
    /// Waiting for greetd.
    Waiting,
    /// pam_fprintd waits for a finger on the reader.
    Fingerprint,
    /// The last scan did not match; the reader is still waiting.
    FingerprintFailed,
    /// PAM asks for a secret: one dot per typed character.
    Secret,
    /// PAM asks a visible question: the question and the typed answer.
    Visible(String),
    /// An answer was sent and PAM is checking it: a light runs over the dots.
    Checking,
    /// The password was wrong.
    Wrong,
    /// Anything else went wrong.
    Failed,
}

/// What the greeter has to do after a response.
#[derive(Debug)]
pub enum Step {
    /// Send this request to greetd.
    Send(Request),
    /// Wait until the user submits an answer.
    AskUser,
    /// Cancel the session, keep the view for this long, then start over.
    Restart(Duration),
    /// Ignore this response.
    Ignore,
    /// The session is started: the greeter must exit.
    Done,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Phase {
    Authenticating,
    Starting,
    Cancelling,
}

pub struct Conversation {
    username: String,
    cmd: Vec<String>,
    env: Vec<String>,
    phase: Phase,
}

impl Conversation {
    pub fn new(username: String, cmd: Vec<String>, env: Vec<String>) -> Self {
        Self {
            username,
            cmd,
            env,
            phase: Phase::Authenticating,
        }
    }

    /// First request of a fresh login attempt.
    pub fn start(&mut self) -> Request {
        self.phase = Phase::Authenticating;
        Request::CreateSession {
            username: self.username.clone(),
        }
    }

    /// Request that carries the user's answer to the current prompt.
    pub fn answer(&self, text: String) -> Request {
        Request::PostAuthMessageResponse {
            response: Some(text),
        }
    }

    /// Request that drops the current session before starting over.
    pub fn cancel(&mut self) -> Request {
        self.phase = Phase::Cancelling;
        Request::CancelSession
    }

    /// Decides the next step from a greetd response. `None` keeps the current view.
    pub fn on_response(&mut self, response: Response) -> (Option<View>, Step) {
        if self.phase == Phase::Cancelling {
            // The reply to CancelSession does not matter: the restart is already scheduled.
            return (None, Step::Ignore);
        }
        match response {
            Response::AuthMessage {
                auth_message_type,
                auth_message,
            } => match auth_message_type {
                AuthMessageType::Secret => (Some(View::Secret), Step::AskUser),
                AuthMessageType::Visible => (Some(View::Visible(auth_message)), Step::AskUser),
                // Info ("place your finger") and PAM error notes need an empty reply to go on.
                kind @ (AuthMessageType::Info | AuthMessageType::Error) => (
                    Some(note_view(&kind, &auth_message)),
                    Step::Send(Request::PostAuthMessageResponse { response: None }),
                ),
            },
            Response::Success => match self.phase {
                Phase::Authenticating => {
                    self.phase = Phase::Starting;
                    let request = Request::StartSession {
                        cmd: self.cmd.clone(),
                        env: self.env.clone(),
                    };
                    // Keep the checking animation until the session takes over the screen.
                    (None, Step::Send(request))
                }
                Phase::Starting => (None, Step::Done),
                Phase::Cancelling => unreachable!("handled above"),
            },
            Response::Error {
                error_type: ErrorType::AuthError,
                ..
            } => (Some(View::Wrong), Step::Restart(WRONG_PAUSE)),
            Response::Error {
                error_type: ErrorType::Error,
                ..
            } => (Some(View::Failed), Step::Restart(FAILED_PAUSE)),
        }
    }
}

/// Words pam_fprintd uses: "Place your finger on…", "Swipe your finger again",
/// "Failed to match fingerprint".
fn is_fingerprint_note(text: &str) -> bool {
    let text = text.to_lowercase();
    ["finger", "swipe", "thumb"]
        .iter()
        .any(|word| text.contains(word))
}

/// View for an informational PAM message.
fn note_view(kind: &AuthMessageType, text: &str) -> View {
    let lower = text.to_lowercase();
    let failed = matches!(kind, AuthMessageType::Error)
        || ["failed", "again", "too fast", "not"]
            .iter()
            .any(|w| lower.contains(w));
    match (is_fingerprint_note(text), failed) {
        (true, true) => View::FingerprintFailed,
        (true, false) => View::Fingerprint,
        (false, _) => View::Waiting,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn conversation() -> Conversation {
        Conversation::new("me".into(), vec!["hypr".into()], vec!["A=1".into()])
    }

    fn auth(kind: AuthMessageType, text: &str) -> Response {
        Response::AuthMessage {
            auth_message_type: kind,
            auth_message: text.into(),
        }
    }

    #[test]
    fn start_creates_a_session_for_the_user() {
        let request = conversation().start();
        assert!(matches!(request, Request::CreateSession { username } if username == "me"));
    }

    #[test]
    fn secret_prompt_asks_the_user() {
        let mut c = conversation();
        c.start();
        let (view, step) = c.on_response(auth(AuthMessageType::Secret, "Password:"));
        assert_eq!(view, Some(View::Secret));
        assert!(matches!(step, Step::AskUser));
    }

    #[test]
    fn visible_prompt_shows_the_question() {
        let mut c = conversation();
        c.start();
        let (view, step) = c.on_response(auth(AuthMessageType::Visible, "7 + 2:"));
        assert_eq!(view, Some(View::Visible("7 + 2:".into())));
        assert!(matches!(step, Step::AskUser));
    }

    #[test]
    fn info_message_gets_an_empty_reply() {
        let mut c = conversation();
        c.start();
        let (view, step) = c.on_response(auth(AuthMessageType::Info, "Place your finger"));
        assert_eq!(view, Some(View::Fingerprint));
        assert!(matches!(
            step,
            Step::Send(Request::PostAuthMessageResponse { response: None })
        ));
    }

    #[test]
    fn fingerprint_notes_are_recognized() {
        let mut c = conversation();
        c.start();
        let place = auth(
            AuthMessageType::Info,
            "Place your right index finger on FPC Fingerprint Sensor",
        );
        assert_eq!(c.on_response(place).0, Some(View::Fingerprint));
        let failed = auth(AuthMessageType::Error, "Failed to match fingerprint");
        assert_eq!(c.on_response(failed).0, Some(View::FingerprintFailed));
        let swipe = auth(AuthMessageType::Info, "Swipe your finger again");
        assert_eq!(c.on_response(swipe).0, Some(View::FingerprintFailed));
        let other = auth(AuthMessageType::Info, "Last login: yesterday");
        assert_eq!(c.on_response(other).0, Some(View::Waiting));
    }

    #[test]
    fn success_starts_the_session_and_then_finishes() {
        let mut c = conversation();
        c.start();
        let (view, step) = c.on_response(Response::Success);
        assert_eq!(view, None);
        assert!(matches!(
            step,
            Step::Send(Request::StartSession { cmd, env }) if cmd == ["hypr"] && env == ["A=1"]
        ));
        let (_, step) = c.on_response(Response::Success);
        assert!(matches!(step, Step::Done));
    }

    #[test]
    fn wrong_password_restarts_after_a_pause() {
        let mut c = conversation();
        c.start();
        let error = Response::Error {
            error_type: ErrorType::AuthError,
            description: "nope".into(),
        };
        let (view, step) = c.on_response(error);
        assert_eq!(view, Some(View::Wrong));
        assert!(matches!(step, Step::Restart(WRONG_PAUSE)));
    }

    #[test]
    fn other_errors_restart_too() {
        let mut c = conversation();
        c.start();
        let error = Response::Error {
            error_type: ErrorType::Error,
            description: "boom".into(),
        };
        let (view, step) = c.on_response(error);
        assert_eq!(view, Some(View::Failed));
        assert!(matches!(step, Step::Restart(FAILED_PAUSE)));
    }

    #[test]
    fn reply_to_cancel_is_ignored() {
        let mut c = conversation();
        c.start();
        c.cancel();
        let (view, step) = c.on_response(Response::Success);
        assert_eq!(view, None);
        assert!(matches!(step, Step::Ignore));
        assert!(matches!(c.start(), Request::CreateSession { .. }));
    }
}
