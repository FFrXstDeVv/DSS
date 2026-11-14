use crate::backend;

pub struct HistoryEntry {
    pub expression: String,
    pub result: String,
    pub status: String,
}

pub struct App {
    pub input: String,
    pub history: Vec<HistoryEntry>,
    pub should_quit: bool,
    pub status: String,
    pub result: String,
}

impl App {
    pub fn new() -> Self {
        Self {
            input: String::new(),
            history: Vec::new(),
            should_quit: false,
            status: String::from("READY"),
            result: String::from("Enter an expression"),
        }
    }

    pub fn submit(&mut self) {
        let expression = self.input.trim().to_string();

        if expression.is_empty() {
            return;
        }

        match backend::evaluate(&expression) {
            Ok(evaluation) => {
                self.status = evaluation.status;
                self.result = evaluation.result;
            }

            Err(error) => {
                self.status = String::from("ERR");
                self.result = error;
            }
        }

        self.history.push(HistoryEntry {
            expression,
            result: self.result.clone(),
            status: self.status.clone(),
        });

        self.input.clear();
    }

    pub fn quit(&mut self) {
        self.should_quit = true;
    }
}
