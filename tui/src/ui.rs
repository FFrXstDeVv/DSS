use ratatui::{
    Frame,
    layout::{Constraint, Direction, Layout},
    style::{Modifier, Style},
    widgets::{Block, Borders, Paragraph, Wrap},
};

use crate::{app::App, logo, theme};

pub fn draw(frame: &mut Frame, app: &App) {
    let area = frame.area();

    let root = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(4),
            Constraint::Min(8),
            Constraint::Length(1),
        ])
        .split(area);

    // header
    let mut logo_lines = logo::small_logo().lines();

    let header_text = format!(
        "{}  DSS\n{}",
        logo_lines.next().unwrap_or(""),
        logo_lines.next().unwrap_or(""),
    );

    let header = Paragraph::new(header_text)
        .style(
            Style::default()
                .fg(theme::ACCENT)
                .add_modifier(Modifier::BOLD),
        )
        .block(Block::default().borders(Borders::BOTTOM));

    frame.render_widget(header, root[0]);

    // main workspace
    let workspace = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(75), Constraint::Percentage(25)])
        .split(root[1]);

    // left column
    let left = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(5), Constraint::Min(3)])
        .split(workspace[0]);

    // expression
    let expression = Paragraph::new(app.input.as_str())
        .style(Style::default().fg(theme::FOREGROUND))
        .block(Block::default().title("Expression").borders(Borders::ALL));

    frame.render_widget(expression, left[0]);

    // result
    let result_text = format!("STATUS: {}\n{}", app.status, app.result);

    let result = Paragraph::new(result_text)
        .wrap(Wrap { trim: false })
        .block(Block::default().title("Result").borders(Borders::ALL));

    frame.render_widget(result, left[1]);

    // history
    let history_text = app
        .history
        .iter()
        .rev()
        .take(30)
        .map(|entry| {
            format!(
                "{} = {} [{}]",
                entry.expression,
                entry.result.replace('\n', " "),
                entry.status
            )
        })
        .collect::<Vec<_>>()
        .join("\n");

    let history = Paragraph::new(history_text)
        .wrap(Wrap { trim: true })
        .block(Block::default().title("History").borders(Borders::ALL));

    frame.render_widget(history, workspace[1]);

    // footer
    let footer =
        Paragraph::new("Enter: calculate    Esc: exit").style(Style::default().fg(theme::MUTED));

    frame.render_widget(footer, root[2]);
}
