//! Background thread that owns the greetd socket, so the screen never blocks on PAM.

use greetd_ipc::codec::SyncCodec;
use greetd_ipc::{Request, Response};
use std::os::unix::net::UnixStream;
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;
use std::time::Duration;
use zeroize::Zeroize;

const RECONNECT_PAUSE: Duration = Duration::from_secs(2);

pub enum Event {
    /// A fresh connection is ready: the conversation must start from the beginning.
    Connected,
    Response(Response),
    /// The connection broke; the worker reconnects on its own.
    Lost,
}

pub struct Worker {
    requests: Sender<Request>,
    pub events: Receiver<Event>,
}

impl Worker {
    pub fn spawn() -> Self {
        let (requests, request_rx) = mpsc::channel();
        let (event_tx, events) = mpsc::channel();
        thread::spawn(move || run(request_rx, event_tx));
        Self { requests, events }
    }

    pub fn send(&self, request: Request) {
        // The worker thread lives as long as the process, so the channel stays open.
        let _ = self.requests.send(request);
    }
}

fn run(requests: Receiver<Request>, events: Sender<Event>) {
    loop {
        if let Some(mut stream) = connect() {
            // Requests queued for a broken connection belong to a conversation that is gone.
            while requests.try_recv().is_ok() {}
            if events.send(Event::Connected).is_err() {
                return;
            }
            serve(&mut stream, &requests, &events);
        }
        if events.send(Event::Lost).is_err() {
            return;
        }
        thread::sleep(RECONNECT_PAUSE);
    }
}

fn connect() -> Option<UnixStream> {
    let path = std::env::var_os("GREETD_SOCK")?;
    UnixStream::connect(path).ok()
}

/// Forwards requests one by one until the connection breaks.
fn serve(stream: &mut UnixStream, requests: &Receiver<Request>, events: &Sender<Event>) {
    while let Ok(mut request) = requests.recv() {
        let sent = request.write_to(stream);
        wipe(&mut request);
        if sent.is_err() {
            return;
        }
        match Response::read_from(stream) {
            Ok(response) => {
                if events.send(Event::Response(response)).is_err() {
                    return;
                }
            }
            Err(_) => return,
        }
    }
}

/// Clears a password from memory once it has been sent.
fn wipe(request: &mut Request) {
    if let Request::PostAuthMessageResponse {
        response: Some(text),
    } = request
    {
        text.zeroize();
    }
}
