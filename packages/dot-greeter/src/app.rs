//! Event loop: joins keys, greetd responses and the screen. It only returns once a session starts.

use crate::input::{Action, Input};
use crate::screen::{Frame, Screen};
use crate::session::{Conversation, Step, View};
use crate::style::Style;
use crate::worker::{Event as GreetdEvent, Worker};
use crossterm::event::{self, Event as TermEvent, KeyEvent};
use std::io;
use std::thread;
use std::time::{Duration, Instant};

const POLL: Duration = Duration::from_millis(50);
/// Speed of the light that runs over the dots while PAM checks the answer.
const CHECKING_FRAME: Duration = Duration::from_millis(110);
/// One step of the pulsing fingerprint dot (dark, middle, bright, middle).
const PULSE_FRAME: Duration = Duration::from_millis(300);
/// How long the fingerprint dot stays red after a scan that did not match.
const SCAN_FAILED: Duration = Duration::from_secs(1);

struct App {
    conversation: Conversation,
    worker: Worker,
    view: View,
    input: Input,
    /// PAM waits for the user's answer.
    asking: bool,
    /// Length of the last submitted answer, for the red dots.
    submitted_len: usize,
    connected: bool,
    restart_at: Option<Instant>,
    /// Start of the current animation (checking light or fingerprint pulse).
    anim_since: Instant,
    /// Enter was pressed while the fingerprint reader waited: the typed password is sent as
    /// soon as PAM asks for it.
    queued: bool,
    scan_failed_until: Option<Instant>,
    last_tick: usize,
    /// Restarted on every key press, so the cursor is visible while typing.
    blink_since: Instant,
    cursor_on: bool,
    /// Half a blink period of the cursor.
    blink: Duration,
    /// Wrong passwords in a row; the placeholder turns into the hint after a few.
    failures: u32,
    dirty: bool,
}

pub fn run(conversation: Conversation, style: Style) -> io::Result<()> {
    let blink = style.blink;
    let mut screen = Screen::open(style)?;
    let mut app = App {
        conversation,
        worker: Worker::spawn(),
        view: View::Waiting,
        input: Input::default(),
        asking: false,
        submitted_len: 0,
        connected: false,
        restart_at: None,
        anim_since: Instant::now(),
        queued: false,
        scan_failed_until: None,
        last_tick: 0,
        blink_since: Instant::now(),
        cursor_on: true,
        blink,
        failures: 0,
        dirty: true,
    };
    loop {
        while let Ok(event) = app.worker.events.try_recv() {
            if app.on_greetd(event) {
                return Ok(());
            }
        }
        app.tick();
        if app.dirty {
            let dots = match app.view {
                View::Checking | View::Wrong => app.submitted_len,
                _ => app.input.len(),
            };
            let frame = Frame {
                view: &app.view,
                dots,
                echo: app.input.text(),
                tick: app.last_tick,
                cursor: app.cursor_on,
                failures: app.failures,
                scan_failed: app
                    .scan_failed_until
                    .is_some_and(|until| Instant::now() < until),
            };
            // A failed draw is not fatal: the next change draws again.
            app.dirty = screen.draw(&frame).is_err();
        }
        // Terminal errors must not end the greeter: greetd would stop with it.
        match event::poll(POLL) {
            Ok(true) => match event::read() {
                Ok(TermEvent::Key(key)) => app.on_key(key),
                Ok(TermEvent::Resize(..)) => app.dirty = true,
                _ => {}
            },
            Ok(false) => {}
            Err(_) => thread::sleep(POLL),
        }
    }
}

impl App {
    /// Returns true once the session is started.
    fn on_greetd(&mut self, event: GreetdEvent) -> bool {
        self.dirty = true;
        match event {
            GreetdEvent::Connected => {
                self.connected = true;
                self.begin();
            }
            GreetdEvent::Lost => {
                self.connected = false;
                self.asking = false;
                self.restart_at = None;
                self.view = View::Failed;
            }
            GreetdEvent::Response(response) => {
                let (view, step) = self.conversation.on_response(response);
                if view == Some(View::Wrong) {
                    self.failures = self.failures.saturating_add(1);
                }
                let view = match view {
                    Some(View::FingerprintFailed) => {
                        self.scan_failed_until = Some(Instant::now() + SCAN_FAILED);
                        Some(View::Fingerprint)
                    }
                    other => other,
                };
                // A queued password keeps its checking animation while the reader still waits.
                if let Some(view) = view.filter(|v| !(self.queued && *v == View::Fingerprint)) {
                    if view != self.view {
                        self.anim_since = Instant::now();
                        self.last_tick = 0;
                    }
                    self.view = view;
                }
                match step {
                    Step::Send(request) => {
                        self.asking = false;
                        self.worker.send(request);
                    }
                    Step::AskUser => {
                        self.asking = true;
                        if self.queued && self.view == View::Secret {
                            self.submit();
                        }
                    }
                    Step::Restart(pause) => {
                        self.asking = false;
                        self.worker.send(self.conversation.cancel());
                        self.restart_at = Some(Instant::now() + pause);
                    }
                    Step::Ignore => {}
                    Step::Done => return true,
                }
            }
        }
        false
    }

    fn tick(&mut self) {
        let cursor_on =
            (self.blink_since.elapsed().as_millis() / self.blink.as_millis()).is_multiple_of(2);
        if cursor_on != self.cursor_on {
            self.cursor_on = cursor_on;
            self.dirty = true;
        }
        let frame = match self.view {
            View::Checking => Some(CHECKING_FRAME),
            View::Fingerprint => Some(PULSE_FRAME),
            _ => None,
        };
        if let Some(frame) = frame {
            let tick = (self.anim_since.elapsed().as_millis() / frame.as_millis()) as usize;
            if tick != self.last_tick {
                self.last_tick = tick;
                self.dirty = true;
            }
        }
        if self
            .scan_failed_until
            .is_some_and(|until| Instant::now() >= until)
        {
            self.scan_failed_until = None;
            self.dirty = true;
        }
        if self.connected && self.restart_at.is_some_and(|at| Instant::now() >= at) {
            self.begin();
            self.dirty = true;
        }
    }

    /// Starts a fresh login attempt.
    fn begin(&mut self) {
        self.restart_at = None;
        self.asking = false;
        self.queued = false;
        self.scan_failed_until = None;
        self.input.clear();
        self.view = View::Waiting;
        self.worker.send(self.conversation.start());
    }

    fn on_key(&mut self, key: KeyEvent) {
        if matches!(self.view, View::Wrong | View::Failed | View::Checking) {
            return;
        }
        match self.input.handle(key) {
            Action::Submit if self.asking => self.submit(),
            Action::Submit if self.input.len() > 0 => {
                // PAM is still busy with the fingerprint reader: send the password once it asks.
                self.queued = true;
                self.submitted_len = self.input.len();
                self.view = View::Checking;
                self.anim_since = Instant::now();
                self.last_tick = 0;
                self.dirty = true;
            }
            Action::Changed => {
                self.blink_since = Instant::now();
                self.cursor_on = true;
                self.dirty = true;
            }
            Action::Submit | Action::Nothing => {}
        }
    }

    /// Sends the typed answer to PAM and starts the checking animation.
    fn submit(&mut self) {
        self.asking = false;
        self.queued = false;
        self.submitted_len = self.input.len();
        let answer = self.input.take();
        self.worker.send(self.conversation.answer(answer));
        self.view = View::Checking;
        self.anim_since = Instant::now();
        self.last_tick = 0;
        self.dirty = true;
    }
}
