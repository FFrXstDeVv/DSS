use std::{
    error::Error,
    io,
    time::{Duration, Instant},
};

use crossterm::event::{self, Event, KeyEventKind};

use ratatui::{
    Terminal,
    backend::CrosstermBackend,
    layout::{Alignment, Rect},
    style::Style,
    widgets::Paragraph,
};

use crate::theme;

const SPLASH_DURATION: Duration = Duration::from_millis(1800);

fn is_blank_line(line: &str) -> bool {
    line.chars()
        .all(|c| c == '\u{2800}' || c.is_ascii_whitespace())
}

pub fn show(terminal: &mut Terminal<CrosstermBackend<io::Stdout>>) -> Result<(), Box<dyn Error>> {
    let mut lines = include_str!("../assets/logo.txt")
        .lines()
        .collect::<Vec<_>>();

    while lines.first().is_some_and(|line| is_blank_line(line)) {
        lines.remove(0);
    }

    while lines.last().is_some_and(|line| is_blank_line(line)) {
        lines.pop();
    }

    if lines.is_empty() {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "Logo asset is empty").into());
    }

    let logo = lines.join("\n");

    let logo_height = u16::try_from(lines.len())?;
    let logo_width = lines
        .iter()
        .map(|line| line.chars().count())
        .max()
        .unwrap_or(0);

    let group_height = logo_height.saturating_add(3);
    let started = Instant::now();

    loop {
        let elapsed = started.elapsed();

        if elapsed >= SPLASH_DURATION {
            break;
        }

        terminal.draw(|frame| {
            let area = frame.area();

            let required_width = u16::try_from(logo_width)
                .unwrap_or(u16::MAX)
                .saturating_add(2);

            if area.width < required_width || area.height < group_height {
                let message =
                    Paragraph::new("DSS\nTerminal too small for logo\nResize or press any key")
                        .alignment(Alignment::Center)
                        .style(Style::default().fg(theme::MUTED));

                frame.render_widget(message, area);
                return;
            }

            let y = area.y + (area.height - group_height) / 2;

            let logo_area = Rect::new(area.x, y, area.width, logo_height);

            let logo_widget = Paragraph::new(logo.as_str())
                .alignment(Alignment::Center)
                .style(Style::default().fg(theme::ACCENT));

            frame.render_widget(logo_widget, logo_area);

            let tagline_area = Rect::new(area.x, y + logo_height + 1, area.width, 2);

            let tagline =
                Paragraph::new("DSS — Decisive Solution Seeker\nPress any key to continue")
                    .alignment(Alignment::Center)
                    .style(Style::default().fg(theme::MUTED));

            frame.render_widget(tagline, tagline_area);
        })?;

        let remaining = SPLASH_DURATION - elapsed;
        let wait = remaining.min(Duration::from_millis(40));

        if event::poll(wait)? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    break;
                }
            }
        }
    }

    Ok(())
}
